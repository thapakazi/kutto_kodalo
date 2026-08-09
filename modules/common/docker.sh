# @module docker
# @summary Container helpers: aligned image/container tables, log inspection,
#          compose shortcuts, network introspection, and throwaway services.

require docker || return 0

# ---------------------------------------------------------------- settings --

# Last container id remembered by docker_cache_last_container, consumed by
# docker_show_logs. Namespaced so it cannot collide with anything else.
SHELLRC_DOCKER_CACHE="${SHELLRC_DOCKER_CACHE:-}"

# Image used by docker_run_postgres.
SHELLRC_DOCKER_PG_IMAGE="${SHELLRC_DOCKER_PG_IMAGE:-postgres:16-alpine}"

# ------------------------------------------------------------ private bits --

# Align a whitespace-separated table into columns and bold the header row.
# Colour is decided per call, so piping into a file stays clean.
_docker_table() {
    local bold='' reset=''
    if [ -t 1 ] && [ -z "$NO_COLOR" ] && [ "$TERM" != "dumb" ]; then
        bold="$(printf '\033[1m')"
        reset="$(printf '\033[0m')"
    fi
    sed -E 's/ {2,}/;/g' \
        | column -s ';' -t \
        | awk -v b="$bold" -v r="$reset" 'NR == 1 { print b $0 r; next } { print }'
}

# Shorten docker ps output: drop the generated NAMES column, abbreviate
# durations, and tidy port mappings. ERE throughout, so BSD sed is happy.
_docker_compact() {
    sed -E '
        1s/ *NAMES$//
        s/ *[a-z]+_[a-z]+$//
        s/"(.*)"/\1/g
        s/ seconds/s/g
        s/ minutes/m/g
        s/ hours/h/g
        s/About a minute/1m/g
        s/About an hour/1h/g
        s/Exited \(([0-9]+)\) (.*)ago/exit(\1)~\2/
        s/->/→/g
    '
}

# Print a hex secret of $1 bytes. Bounded input, so no SIGPIPE noise.
_docker_random_secret() {
    LC_ALL=C od -An -tx1 -N "${1:-24}" /dev/urandom | tr -dc 'a-f0-9'
}

# ------------------------------------------------------------------ images --

# @describe List local images in an aligned table with a bold header.
# @usage    docker_list_images [docker-images-arg]...
# @example  docker_list_images
# @example  docker_list_images --filter dangling=true
# @requires docker column
# @os       any
# @see      docker_list_images_by_size
docker_list_images() {
    docker images "$@" | _docker_table
}

# @describe List images sorted by size, smallest first.
# @usage    docker_list_images_by_size
# @example  docker_list_images_by_size | tail -20
# @requires docker
# @os       any
docker_list_images_by_size() {
    docker images --format '{{.ID}}   {{.Size}}   {{.Repository}}:{{.Tag}}' | sort -n -k 2
}

# @describe List every tag published for a Docker Hub image. Walks the registry
#           API page by page and stops at the last one.
# @usage    docker_list_tags [image] [max-pages]
# @example  docker_list_tags golang
# @example  docker_list_tags bitnami/postgresql 3
# @requires curl jq
# @os       any
docker_list_tags() {
    require curl jq || return 1
    local image="${1:-golang}" max="${2:-10}" repo page=1 body names
    case "$image" in
        */*) repo="$image" ;;
        *)   repo="library/$image" ;;
    esac
    while [ "$page" -le "$max" ]; do
        body="$(curl -fsSL "https://registry.hub.docker.com/v2/repositories/$repo/tags/?page=$page&page_size=100")" || {
            log_error "docker_list_tags: registry request failed for $repo (page $page)"
            return 1
        }
        names="$(printf '%s' "$body" | jq -r '.results[]?.name')"
        [ -n "$names" ] || break
        printf '%s\n' "$names"
        printf '%s' "$body" | jq -e '.next != null' >/dev/null 2>&1 || break
        page=$((page + 1))
    done
}

# -------------------------------------------------------------- containers --

# @describe Run any docker subcommand and reformat its table output compactly.
# @usage    docker_format_output <docker-subcommand> [arg]...
# @example  docker_format_output ps -a
# @example  docker_format_output ps -l
# @requires docker column
# @os       any
docker_format_output() {
    docker "$@" | _docker_compact | _docker_table
}

# @describe Print the id of the most recently created container.
# @usage    docker_get_last_id
# @example  docker logs "$(docker_get_last_id)"
# @requires docker
# @os       any
docker_get_last_id() {
    docker ps -lq
}

# @describe Show the last container and remember its id in SHELLRC_DOCKER_CACHE
#           so docker_show_logs can pick it up with no arguments.
# @usage    docker_cache_last_container
# @example  docker_cache_last_container && docker_show_logs
# @requires docker
# @os       any
# @see      docker_show_logs
docker_cache_last_container() {
    docker ps -l >&2
    SHELLRC_DOCKER_CACHE="$(docker ps -lq)"
    export SHELLRC_DOCKER_CACHE
}

# @describe Show container logs. Uses the arguments if given, else ids piped on
#           stdin, else the id cached by docker_cache_last_container, else the
#           most recent container.
# @usage    docker_show_logs [container-or-flag]...
# @example  docker_show_logs
# @example  docker_show_logs -f --tail 50 web
# @example  docker ps -q | docker_show_logs
# @requires docker
# @os       any
# @see      docker_cache_last_container
docker_show_logs() {
    if [ "$#" -gt 0 ]; then
        docker logs "$@"
        return
    fi

    local ids=""
    [ -t 0 ] || ids="$(cat)"
    [ -n "$ids" ] || ids="${SHELLRC_DOCKER_CACHE:-$(docker ps -lq)}"
    if [ -z "$ids" ]; then
        log_error "docker_show_logs: no container given, cached, or running"
        return 1
    fi

    printf '%s\n' "$ids" | while IFS= read -r id; do
        [ -n "$id" ] || continue
        docker logs "$id"
    done
}

# @describe Open an interactive shell inside a container, preferring bash and
#           falling back to sh. Defaults to the most recent container.
# @usage    docker_open_shell [container] [shell]
# @example  docker_open_shell
# @example  docker_open_shell web /bin/zsh
# @requires docker
# @os       any
docker_open_shell() {
    local id="${1:-}" shell_bin="${2:-}"
    [ -n "$id" ] || id="$(docker ps -lq)"
    if [ -z "$id" ]; then
        log_error "docker_open_shell: no container given and none running"
        return 1
    fi
    if [ -n "$shell_bin" ]; then
        docker exec -it "$id" "$shell_bin"
    else
        docker exec -it "$id" sh -c 'command -v bash >/dev/null 2>&1 && exec bash || exec sh'
    fi
}

# @describe Open a shell in the most recently created container.
# @usage    docker_open_shell_last
# @example  docker_open_shell_last
# @requires docker
# @os       any
docker_open_shell_last() {
    docker_open_shell "$(docker ps -lq)"
}

# @describe Remove every container in the exited state, after showing them.
# @usage    docker_remove_exited_containers
# @example  docker_remove_exited_containers
# @requires docker
# @os       any
# @danger   Removes containers permanently. Prompts first.
docker_remove_exited_containers() {
    local ids
    ids="$(docker ps -aqf status=exited)"
    if [ -z "$ids" ]; then
        log_info "No exited containers."
        return 0
    fi
    docker ps -af status=exited --format '{{.ID}}  {{.Image}}  {{.Names}}  {{.Status}}' >&2
    confirm "Remove the exited containers listed above?" || return 0
    printf '%s\n' "$ids" | while IFS= read -r id; do
        [ -n "$id" ] || continue
        docker rm "$id"
    done
}

# ---------------------------------------------------------------- networks --

# @describe Print the IP address, hostname, and name of every running container.
# @usage    docker_list_ips
# @example  docker_list_ips
# @requires docker
# @os       any
docker_list_ips() {
    local ids
    ids="$(docker ps -q)"
    [ -n "$ids" ] || { log_info "No running containers."; return 0; }
    printf '%s\n' "$ids" \
        | xargs -n 1 docker inspect \
            --format '{{ .NetworkSettings.IPAddress }} {{ .Config.Hostname }} {{ .Name }}' \
        | sed 's| /| |'
}

# @describe Print each docker network alongside its IPAM (subnet) configuration.
# @usage    docker_show_networks
# @example  docker_show_networks | jq -s .
# @requires docker
# @os       any
docker_show_networks() {
    local ids
    ids="$(docker network ls -q)"
    [ -n "$ids" ] || return 0
    printf '%s\n' "$ids" \
        | xargs docker network inspect --format '{{json .Name}} {{json .IPAM}}'
}

# ----------------------------------------------------------------- compose --

# @describe Run docker compose in the current project.
# @usage    docker_run_compose <compose-subcommand> [arg]...
# @example  docker_run_compose up -d
# @requires docker
# @os       any
docker_run_compose() {
    docker compose "$@"
}

# @describe Run a command inside a compose service.
# @usage    docker_exec_service <service> [command]...
# @example  docker_exec_service app bash
# @requires docker
# @os       any
docker_exec_service() {
    docker_run_compose exec "$@"
}

# @describe Follow the logs of one or all compose services.
# @usage    docker_follow_logs [service]...
# @example  docker_follow_logs app
# @requires docker
# @os       any
docker_follow_logs() {
    docker_run_compose logs -f "$@"
}

# @describe Restart one or all compose services.
# @usage    docker_restart_service [service]...
# @example  docker_restart_service app
# @requires docker
# @os       any
docker_restart_service() {
    docker_run_compose restart "$@"
}

# @describe List the containers of the current compose project.
# @usage    docker_list_services [arg]...
# @example  docker_list_services
# @requires docker
# @os       any
docker_list_services() {
    docker_run_compose ps "$@"
}

# @describe Run bundler inside a compose service (defaults to the "app" service).
# @usage    docker_run_bundle [service]
# @example  docker_run_bundle
# @example  docker_run_bundle worker
# @requires docker
# @os       any
docker_run_bundle() {
    docker_exec_service "${1:-app}" bundle
}

# --------------------------------------------------------- throwaway stack --

# @describe Start a disposable PostgreSQL container. Generates a fresh random
#           password for every invocation, passes it through a private temp
#           env-file, and deletes that file on exit via a trap.
# @usage    docker_run_postgres [host-port] [database] [user]
# @example  docker_run_postgres
# @example  docker_run_postgres 55432 appdb appuser
# @requires docker
# @os       any
docker_run_postgres() {
    local port="${1:-5432}" db="${2:-mydb}" user="${3:-my_user}"
    local image="$SHELLRC_DOCKER_PG_IMAGE" envfile password

    envfile="$(tmp_file pgenv)" || return 1
    chmod 600 "$envfile" 2>/dev/null
    password="$(_docker_random_secret 24)"
    if [ -z "$password" ]; then
        rm -f "$envfile"
        log_error "docker_run_postgres: could not generate a password"
        return 1
    fi

    printf 'POSTGRES_DB=%s\nPOSTGRES_USER=%s\nPOSTGRES_PASSWORD=%s\n' \
        "$db" "$user" "$password" > "$envfile"

    log_info "postgres $image on localhost:$port"
    log_info "  database : $db"
    log_info "  user     : $user"
    log_info "  password : $password   (generated for this run only)"
    log_info "  url      : postgres://$user:$password@127.0.0.1:$port/$db"

    # Subshell so the EXIT trap fires when the container stops, in bash and zsh
    # alike, and the credentials never outlive the command.
    (
        trap 'rm -f "$envfile"' EXIT INT TERM
        docker run --rm -it --env-file "$envfile" -p "$port:5432" "$image"
    )
}

# ---------------------------------------------------------- play-with-docker --

# @describe Create a Play With Docker node and point the local docker client at
#           it. Pass the session URL shown by labs.play-with-docker.com.
# @usage    docker_play_create_node <session-url>
# @example  docker_play_create_node http://host3.labs.play-with-docker.com/p/35ef3b7d
# @requires docker docker-machine
# @os       any
docker_play_create_node() {
    if ! has docker-machine; then
        log_error "docker_play_create_node: docker-machine is not installed"
        return 1
    fi
    if [ -z "$1" ]; then
        log_error "usage: docker_play_create_node <session-url>"
        return 1
    fi
    local node
    export PWD_URL="$1"
    node="node$(awk 'BEGIN { srand(); print int(rand() * 100) + 1 }')"
    docker-machine create -d pwd "$node" || return 1
    eval "$(docker-machine env "$node")"
    docker ps
}

# @describe Delete every local docker-machine definition under ~/.docker/machine.
# @usage    docker_play_remove_machines
# @example  docker_play_remove_machines
# @requires docker-machine
# @os       any
# @danger   Deletes ~/.docker/machine entirely. Prompts first.
docker_play_remove_machines() {
    local dir="$HOME/.docker/machine"
    if [ ! -d "$dir" ]; then
        log_info "Nothing to clean: $dir does not exist."
        return 0
    fi
    log_info "About to delete $dir ($(path_size "$dir")):"
    ls -1 "$dir/machines" 2>/dev/null >&2
    confirm "Delete $dir and every machine definition in it?" || {
        log_ok "Nothing changed."
        return 0
    }
    rm -rf "$dir"
    log_ok "Removed $dir"
}

# ------------------------------------------------------ back-compat aliases --
# The long names above are the API. These short ones exist because they are
# genuinely faster to type at a prompt; every one of them still works.

alias dimg='docker_list_images'
alias docker_fit='docker_format_output'
alias dlc='docker_cache_last_container'
alias dlo='docker_show_logs'
alias dl='docker_get_last_id'
alias dll='docker_format_output ps -l'
alias dps='docker_format_output ps -a'
alias docker_attach='docker_open_shell'
alias docker_attachl='docker_open_shell_last'
alias docker-clean-exited-containers='docker_remove_exited_containers'
alias docker_ips='docker_list_ips'
alias docker_network_info='docker_show_networks'
alias docker_img_sort_size='docker_list_images_by_size'
alias dk='docker_run_compose'
alias dke='docker_exec_service'
alias dkl='docker_follow_logs'
alias dkr='docker_restart_service'
alias dkps='docker_list_services'
alias dkb='docker_run_bundle'
alias dk-tags='docker_list_tags'
alias quick_pg='docker_run_postgres'
alias play_with_docker='docker_play_create_node'
alias play_with_docker_cleanup='docker_play_remove_machines'
