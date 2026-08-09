# @module kubernetes
# @summary kubectl, kind, krew, and k9s helpers: secret inspection, debug pods,
#          throwaway kind clusters, and evicted-pod triage.

require kubectl || return 0

# ---------------------------------------------------------------- settings --

# Where generated state lives. shellrc exports this; default it so the module is
# also sourceable on its own.
SHELLRC_CACHE="${SHELLRC_CACHE:-$HOME/.cache/shellrc}"

# ahmetb/kubectl-aliases. The repo used to be called "kubectl-alias"; that URL
# only still resolves because GitHub redirects renamed repositories.
SHELLRC_KUBECTL_ALIASES_URL="${SHELLRC_KUBECTL_ALIASES_URL:-https://raw.githubusercontent.com/ahmetb/kubectl-aliases/master/.kubectl_aliases}"
SHELLRC_KUBECTL_ALIASES="${SHELLRC_KUBECTL_ALIASES:-$SHELLRC_CACHE/kubectl_aliases}"

# Name of the kind cluster created most recently, for k8s_delete_last_cluster.
SHELLRC_KIND_STATE="${SHELLRC_KIND_STATE:-$SHELLRC_CACHE/last-kind-cluster}"

# Upstream example script fetched by k8s_create_cluster_with_registry.
SHELLRC_KIND_REGISTRY_URL="${SHELLRC_KIND_REGISTRY_URL:-https://kind.sigs.k8s.io/examples/kind-with-registry.sh}"

# k9s configuration root (no trailing slash).
SHELLRC_K9S_CONFIG_DIR="${SHELLRC_K9S_CONFIG_DIR:-$HOME/.config/k9s}"

# krew's own documented variable; krew reads it at runtime.
KREW_ROOT="${KREW_ROOT:-$HOME/.krew}"

if [ -d "$KREW_ROOT/bin" ]; then
    case ":$PATH:" in
        *":$KREW_ROOT/bin:"*) : ;;
        *) PATH="$KREW_ROOT/bin:$PATH"; export PATH ;;
    esac
fi

# ------------------------------------------------------------ private bits --

# Print a lowercase hex id of $1 characters. Bounded read, so no SIGPIPE noise.
_k8s_random_id() {
    local n="${1:-6}"
    LC_ALL=C od -An -tx1 -N 32 /dev/urandom | tr -dc 'a-f0-9' | cut -c "1-$n"
}

# Print the SHA-256 of a file using whichever tool this OS ships.
_k8s_sha256() {
    if   has sha256sum; then sha256sum "$1" | awk '{print $1}'
    elif has shasum;    then shasum -a 256 "$1" | awk '{print $1}'
    else echo "(no sha256 tool available)"
    fi
}

# Guard for the kind-based helpers.
_k8s_need_kind() {
    has kind && return 0
    log_error "kind is not installed (see https://kind.sigs.k8s.io)"
    return 1
}

# ----------------------------------------------------------- kubectl setup --

# @describe Download ahmetb/kubectl-aliases into the shellrc cache. Explicitly
#           user-invoked: nothing is ever fetched while your shell starts. The
#           cached file is sourced automatically on the next shell if non-empty.
# @usage    k8s_fetch_kubectl_aliases
# @example  k8s_fetch_kubectl_aliases && k8s_load_kubectl_aliases
# @requires curl
# @os       any
# @see      k8s_load_kubectl_aliases
k8s_fetch_kubectl_aliases() {
    require curl || return 1
    local dest="$SHELLRC_KUBECTL_ALIASES" tmp
    mkdir -p "$(dirname "$dest")" || return 1
    tmp="$(tmp_file kubectl-aliases)" || return 1
    log_info "Fetching $SHELLRC_KUBECTL_ALIASES_URL"
    if ! curl -fsSL "$SHELLRC_KUBECTL_ALIASES_URL" -o "$tmp"; then
        rm -f "$tmp"
        log_error "k8s_fetch_kubectl_aliases: download failed, cache left untouched"
        return 1
    fi
    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        log_error "k8s_fetch_kubectl_aliases: downloaded file was empty"
        return 1
    fi
    mv -f "$tmp" "$dest" || { rm -f "$tmp"; return 1; }
    log_ok "Saved $dest ($(path_size "$dest"))"
    log_info "Run k8s_load_kubectl_aliases to use them in this shell."
}

# @describe Source the cached kubectl aliases into the current shell. A no-op
#           when the cache is missing or empty.
# @usage    k8s_load_kubectl_aliases
# @example  k8s_load_kubectl_aliases
# @requires kubectl
# @os       any
# @see      k8s_fetch_kubectl_aliases
k8s_load_kubectl_aliases() {
    if [ ! -s "$SHELLRC_KUBECTL_ALIASES" ]; then
        log_warn "No kubectl aliases cached. Run k8s_fetch_kubectl_aliases first."
        return 1
    fi
    # shellcheck disable=SC1090
    . "$SHELLRC_KUBECTL_ALIASES"
}

# ----------------------------------------------------------------- secrets --

# @describe Print every key of a secret with its value base64-decoded.
# @usage    k8s_print_secrets [secret-name] [namespace]
# @example  k8s_print_secrets
# @example  k8s_print_secrets api-secrets production
# @requires kubectl jq
# @os       any
k8s_print_secrets() {
    require jq || return 1
    local name="${1:-api-secrets}" ns="${2:-default}"
    kubectl get "secret/$name" -n "$ns" -o json \
        | jq -r '.data // {} | to_entries[] | "\(.key) \(.value)"' \
        | while IFS=' ' read -r key value; do
              [ -n "$key" ] || continue
              printf '%s: ' "$key"
              printf '%s' "$value" | b64_decode
              printf '\n'
          done
}

# @describe Base64-encode a value for pasting into a Secret manifest. Emits one
#           unwrapped line on macOS and Linux alike.
# @usage    k8s_encode_secret <value>...
# @example  k8s_encode_secret hunter2
# @requires base64
# @os       any
k8s_encode_secret() {
    printf '%s' "$*" | b64_encode
    printf '\n'
}

# ------------------------------------------------------------------- pods ---

# @describe Print the names of the pods matching a label selector, space
#           separated on one line.
# @usage    k8s_list_pods <label-selector> [namespace]
# @example  k8s_list_pods app=web production
# @requires kubectl
# @os       any
k8s_list_pods() {
    local selector="${1:-}" ns="${2:-default}"
    if [ -z "$selector" ]; then
        log_error "usage: k8s_list_pods <label-selector> [namespace]"
        return 1
    fi
    kubectl get pod -l "$selector" -n "$ns" --no-headers=true | awk '{print $1}' | xargs
}

# @describe Launch a throwaway interactive pod and drop into a shell. The pod is
#           deleted as soon as you exit.
# @usage    k8s_run_debug_pod [image] [namespace] [pod-name]
# @example  k8s_run_debug_pod
# @example  k8s_run_debug_pod nicolaka/netshoot production netdebug
# @requires kubectl
# @os       any
k8s_run_debug_pod() {
    local image="${1:-ubuntu}" ns="${2:-default}" name="${3:-debug}"
    kubectl run -i --tty --rm "$name" --image="$image" -n "$ns" --restart=Never -- sh
}

# @describe Run netstat in every pod matching $LABEL in $NAMESPACE, optionally
#           filtered, and report the per-pod line count. Full output is kept in
#           a private temp directory whose path is printed at the end.
# @usage    k8s_print_connections [grep-pattern]...
# @example  NAMESPACE=production LABEL=app=web k8s_print_connections ESTABLISHED
# @requires kubectl
# @os       any
k8s_print_connections() {
    local dir ns label
    ns="${NAMESPACE:-production}"
    label="${LABEL:-service=xyz}"
    dir="$(tmp_dir k8s-conn)" || return 1

    k8s_list_pods "$label" "$ns" | tr ' ' '\n' | while IFS= read -r pod; do
        [ -n "$pod" ] || continue
        echo "----------------------"
        if [ "$#" -gt 0 ]; then
            kubectl -n "$ns" exec "pod/$pod" -- netstat | grep -- "$@" | tee "$dir/$pod"
        else
            kubectl -n "$ns" exec "pod/$pod" -- netstat | tee "$dir/$pod"
        fi
        printf '%s %s\n' "$pod" "$(wc -l < "$dir/$pod" | tr -d ' ')"
    done

    log_info "full output kept in $dir"
}

# @describe Find evicted pods in every namespace, print the eviction reason for
#           each, then offer to delete them.
# @usage    k8s_print_evicted_pods
# @example  k8s_print_evicted_pods
# @requires kubectl
# @os       any
# @danger   Deletes the evicted pods it finds. Prompts before deleting.
k8s_print_evicted_pods() {
    local dir count ns pod
    dir="$(tmp_dir k8s-evicted)" || return 1

    log_info "searching for evicted pods..."
    kubectl get pods -A | awk '/Evicted/ { print $1, $2 }' > "$dir/evicted"
    if [ ! -s "$dir/evicted" ]; then
        log_ok "No evicted pods."
        rm -rf "$dir"
        return 0
    fi
    cat "$dir/evicted"

    log_info "--------- reasons for eviction ---------"
    while IFS=' ' read -r ns pod; do
        [ -n "$pod" ] || continue
        printf '%s/%s: ' "$ns" "$pod"
        kubectl describe -n "$ns" "po/$pod" | grep -i 'message:' || echo "(no message)"
    done < "$dir/evicted"

    count="$(wc -l < "$dir/evicted" | tr -d ' ')"
    if confirm "Delete $count evicted pod(s)?"; then
        while IFS=' ' read -r ns pod; do
            [ -n "$pod" ] || continue
            kubectl delete -n "$ns" "po/$pod"
        done < "$dir/evicted"
    else
        log_info "Nothing deleted. List kept at $dir/evicted"
        return 0
    fi
    rm -rf "$dir"
}

# ------------------------------------------------------------------ nodes ---

# @describe List nodes with their Karpenter AMI id and instance type. Nodes
#           missing either label are skipped.
# @usage    k8s_list_nodes
# @example  k8s_list_nodes | sort -k3
# @requires kubectl jq
# @os       any
k8s_list_nodes() {
    require jq || return 1
    kubectl get nodes -o json | jq -r '
        .items[]
        | {
            name:          .metadata.name,
            ami_id:        .metadata.labels["karpenter.k8s.aws/instance-ami-id"],
            instance_type: .metadata.labels["beta.kubernetes.io/instance-type"]
          }
        | select(.ami_id and .instance_type)
        | "\(.name) \(.ami_id) \(.instance_type)"
    '
}

# ------------------------------------------------------------------- krew ---

# @describe Download the latest krew release for this OS and architecture, show
#           you its checksum and contents, and install it only after you agree.
#           Nothing is piped into a shell.
# @usage    k8s_install_krew
# @example  k8s_install_krew
# @requires curl tar
# @os       any
k8s_install_krew() {
    require curl tar || return 1
    local os arch krew url dir rc=0
    os="$(uname | tr '[:upper:]' '[:lower:]')"
    arch="$(os_arch)"
    krew="krew-${os}_${arch}"
    url="https://github.com/kubernetes-sigs/krew/releases/latest/download/${krew}.tar.gz"

    dir="$(tmp_dir krew)" || return 1
    log_info "Downloading $url"
    if ! curl -fsSL "$url" -o "$dir/$krew.tar.gz"; then
        rm -rf "$dir"
        log_error "k8s_install_krew: download failed"
        return 1
    fi
    if ! tar -xzf "$dir/$krew.tar.gz" -C "$dir"; then
        rm -rf "$dir"
        log_error "k8s_install_krew: archive did not extract"
        return 1
    fi

    log_info "Archive : $dir/$krew.tar.gz"
    log_info "SHA-256 : $(_k8s_sha256 "$dir/$krew.tar.gz")"
    log_info "Contents:"
    tar -tzf "$dir/$krew.tar.gz" >&2
    log_warn "Upstream publishes no pinned checksum here. Compare the SHA-256"
    log_warn "above with https://github.com/kubernetes-sigs/krew/releases"

    if ! confirm "Run $dir/$krew install krew?"; then
        log_info "Not executed. Files kept in $dir for inspection."
        return 0
    fi
    ( cd "$dir" && "./$krew" install krew ) || rc=$?
    rm -rf "$dir"
    if [ "$rc" -eq 0 ]; then
        log_ok "krew installed. Open a new shell to pick up $KREW_ROOT/bin on PATH."
    fi
    return "$rc"
}

# ------------------------------------------------------------------- kind ---

# @describe Create a kind cluster and record its name so k8s_delete_last_cluster
#           can find it later.
# @usage    k8s_create_kind_cluster [name]
# @example  k8s_create_kind_cluster
# @example  k8s_create_kind_cluster scratch
# @requires kind
# @os       any
# @see      k8s_delete_kind_cluster
k8s_create_kind_cluster() {
    _k8s_need_kind || return 1
    local name="${1:-test-cluster}"
    kind create cluster --name="$name" || return 1
    mkdir -p "$(dirname "$SHELLRC_KIND_STATE")" \
        && printf '%s\n' "$name" > "$SHELLRC_KIND_STATE"
    log_ok "cluster '$name' created (remembered in $SHELLRC_KIND_STATE)"
}

# @describe Create a kind cluster with a randomly generated name.
# @usage    k8s_create_random_cluster [id-length]
# @example  k8s_create_random_cluster
# @example  k8s_create_random_cluster 10
# @requires kind
# @os       any
k8s_create_random_cluster() {
    _k8s_need_kind || return 1
    local rand name
    rand="$(_k8s_random_id "${1:-6}")"
    if [ -z "$rand" ]; then
        log_error "k8s_create_random_cluster: could not generate an id"
        return 1
    fi
    name="kind-$rand"
    log_info "building cluster: $name"
    k8s_create_kind_cluster "$name"
}

# @describe Create a kind cluster wired to a local image registry, using the
#           upstream example script. The script is downloaded to a temp file,
#           diffed against the copy you approved last time, and executed only
#           after you confirm.
# @usage    k8s_create_cluster_with_registry
# @example  k8s_create_cluster_with_registry
# @requires curl kind
# @os       any
# @danger   Runs a script downloaded from the internet. Shows it and prompts first.
k8s_create_cluster_with_registry() {
    require curl || return 1
    _k8s_need_kind || return 1
    local approved="$SHELLRC_CACHE/kind-with-registry.sh" tmp rc=0

    tmp="$(tmp_file kind-with-registry)" || return 1
    if ! curl -fsSL "$SHELLRC_KIND_REGISTRY_URL" -o "$tmp"; then
        rm -f "$tmp"
        log_error "k8s_create_cluster_with_registry: download failed"
        return 1
    fi
    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        log_error "k8s_create_cluster_with_registry: downloaded script was empty"
        return 1
    fi

    log_info "Source  : $SHELLRC_KIND_REGISTRY_URL"
    log_info "Saved   : $tmp"
    log_info "SHA-256 : $(_k8s_sha256 "$tmp")"
    if [ -f "$approved" ]; then
        log_info "Diff against the copy you approved last time ($approved):"
        if diff -u "$approved" "$tmp" >&2; then
            log_ok "identical to the version you approved before"
        fi
    else
        log_info "No previously approved copy. Full script follows — read it:"
        cat "$tmp" >&2
    fi

    if ! confirm "Execute this script with bash?"; then
        log_info "Not executed. Script kept at $tmp"
        return 0
    fi
    mkdir -p "$SHELLRC_CACHE" && cp "$tmp" "$approved"
    bash "$tmp"
    rc=$?
    rm -f "$tmp"
    return "$rc"
}

# @describe Delete a kind cluster by name.
# @usage    k8s_delete_kind_cluster [name]
# @example  k8s_delete_kind_cluster
# @example  k8s_delete_kind_cluster scratch
# @requires kind
# @os       any
# @danger   Destroys the cluster and everything in it. Prompts first.
k8s_delete_kind_cluster() {
    _k8s_need_kind || return 1
    local name="${1:-test-cluster}"
    confirm "Delete kind cluster '$name'?" || return 0
    kind delete cluster --name="$name" || return 1
    if [ -f "$SHELLRC_KIND_STATE" ] && [ "$(cat "$SHELLRC_KIND_STATE")" = "$name" ]; then
        rm -f "$SHELLRC_KIND_STATE"
    fi
}

# @describe Delete the kind cluster created most recently by this shellrc.
# @usage    k8s_delete_last_cluster
# @example  k8s_delete_last_cluster
# @requires kind
# @os       any
# @danger   Destroys the cluster and everything in it. Prompts first.
# @see      k8s_create_random_cluster
k8s_delete_last_cluster() {
    local name
    if [ ! -s "$SHELLRC_KIND_STATE" ]; then
        log_error "No cluster recorded in $SHELLRC_KIND_STATE"
        return 1
    fi
    name="$(cat "$SHELLRC_KIND_STATE")"
    if [ -z "$name" ]; then
        log_error "$SHELLRC_KIND_STATE is empty"
        return 1
    fi
    k8s_delete_kind_cluster "$name"
}

# -------------------------------------------------------------------- k9s ---

# @describe Install the k9s skin collection into the k9s config directory. On
#           macOS also links the config dir into ~/Library/Application Support/,
#           which is where k9s looks.
# @usage    k9s_install_themes
# @example  k9s_install_themes && k9s_set_theme solarized_dark
# @requires git
# @os       any
# @danger   Replaces any existing skins directory. Prompts when one is present.
# @see      k9s_set_theme
k9s_install_themes() {
    require git || return 1
    local dir="$SHELLRC_K9S_CONFIG_DIR" support tmp
    mkdir -p "$dir" || return 1

    if is_macos; then
        support="$HOME/Library/Application Support"
        mkdir -p "$support" || return 1
        if [ ! -e "$support/k9s" ]; then
            ln -s "$dir" "$support/k9s" && log_ok "linked $support/k9s -> $dir"
        fi
    fi

    if [ -d "$dir/skins" ]; then
        confirm "Replace the existing skins in $dir/skins?" || return 0
    fi

    tmp="$(tmp_dir k9s)" || return 1
    if ! git clone --depth=1 https://github.com/derailed/k9s.git "$tmp/k9s"; then
        rm -rf "$tmp"
        log_error "k9s_install_themes: clone failed"
        return 1
    fi
    if [ ! -d "$tmp/k9s/skins" ]; then
        rm -rf "$tmp"
        log_error "k9s_install_themes: upstream has no skins/ directory any more"
        return 1
    fi
    rm -rf "$dir/skins"
    mv "$tmp/k9s/skins" "$dir/skins"
    rm -rf "$tmp"
    log_ok "installed skins into $dir/skins"
}

# @describe Point k9s at one of the installed skins.
# @usage    k9s_set_theme [skin-name]
# @example  k9s_set_theme
# @example  k9s_set_theme dracula
# @requires k9s
# @os       any
# @see      k9s_install_themes
k9s_set_theme() {
    local dir="$SHELLRC_K9S_CONFIG_DIR" name="${1:-solarized_dark}" src=""
    if [ -f "$dir/skins/$name.yml" ]; then
        src="$dir/skins/$name.yml"
    elif [ -f "$dir/skins/$name.yaml" ]; then
        src="$dir/skins/$name.yaml"
    else
        log_error "k9s_set_theme: no skin named '$name' in $dir/skins"
        [ -d "$dir/skins" ] && ls -1 "$dir/skins" >&2 || log_info "Run k9s_install_themes first."
        return 1
    fi
    ln -sfn "$src" "$dir/skin.yml"
    log_ok "k9s skin set to $name"
}

# ------------------------------------------------ cached kubectl aliases ----
# Sourced only when the cache exists and is non-empty; never downloaded here.

if [ -s "$SHELLRC_KUBECTL_ALIASES" ]; then
    # shellcheck disable=SC1090
    . "$SHELLRC_KUBECTL_ALIASES" || log_warn "could not source $SHELLRC_KUBECTL_ALIASES"
fi

# ------------------------------------------------------ back-compat aliases --
# The long names above are the API. Everything that used to work still works.

alias get_kubectl-alias='k8s_fetch_kubectl_aliases'
alias kubectl_print_secrets='k8s_print_secrets'
alias encode_base64='k8s_encode_secret'
alias haribahadur_launch_debug_pod='k8s_run_debug_pod'
alias install_krew='k8s_install_krew'
alias k_get_nodes='k8s_list_nodes'
alias k8s_get_pods='k8s_list_pods'
alias k8s_print_eviced_pod_summary='k8s_print_evicted_pods'
alias quick_k8s_spin='k8s_create_kind_cluster'
alias quick_k8s_destroy='k8s_delete_kind_cluster'
alias give_me_cluster='k8s_create_random_cluster'
alias give_me_cluster_with_registry='k8s_create_cluster_with_registry'
alias take_down_cluster='k8s_delete_last_cluster'
alias k9s_themes_init='k9s_install_themes'
alias k9s_change_theme='k9s_set_theme'
