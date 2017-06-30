function dimg {
    docker images $@ |
        sed "s/  \+/;/g" |
        column -s\; -t |
        sed "1s/.*/\x1B[1m&\x1B[m/"
}

function docker_fit {
    # docker fit output
    docker $@ |
    sed '
        1s/ *NAMES$//g;
        s/ *[a-z]\+_[a-z]\+$//g;
        s/"\(.*\)"/\1/g;
        s/ seconds/s/g;
        s/ minutes/m/g;
        s/ hours/h/g;
        s/About a minute/1m/g;
        s/About an hour/1h/g;
        s/Exited (\([0-9]\+\)) \(.*\)ago/exit(\1)~\2/;
        s/->/→/g
        ' |
    sed "s/  \+/;/g" |
    column -s\; -t |
    sed "1s/.*/\x1B[1m&\x1B[m/"
}

function dlc {
    # cache docker last container id DOCKER_CACHE
    1>&2 docker ps -l
    export DOCKER_CACHE=$(docker ps -lq)
}

function dlo {
    if [[ -t 1 ]]; then
        while read data; do
            args+="$data"
        done
        docker logs $args
        return
    fi
    if [[ $DOCKER_CACHE != "" ]]; then
        docker logs $DOCKER_CACHE
        return
    fi
    docker logs $@
}

alias dl='docker ps -lq'

docker_attach(){
    docker exec -it $1 /bin/bash
}
docker_attachl(){
    docker_attach `dl`
}

alias dll='docker_fit ps -l'
alias dps='docker_fit ps -a'
alias docker-clean-exited-containers='docker ps -aqf status=exited | xargs -n1 docker rm'


# list all host and ips
# https://gist.github.com/ipedrazas/2c93f6e74737d1f8a791
function docker_ips(){
    docker ps -q | xargs -n 1 docker inspect --format '{{ .NetworkSettings.IPAddress }} {{ .Name }}' | sed 's/ \// /'
}
docker_network_info(){
    docker network ls -q| \
        xargs  docker network inspect --format "{{json .Name}} {{json .IPAM}}"
}

function docker_img_sort_size(){
    docker images --format '{{.ID}}   {{.Size}}   {{.Repository}}:{{.Tag}}' |sort -n -k 2
}
