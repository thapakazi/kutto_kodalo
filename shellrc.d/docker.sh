# please play with docker
# Eg: play_with_docker http://host3.labs.play-with-docker.com/p/35ef3b7d-c45a-4df9-aadd-f282f328c804
play_with_docker(){
    export PWD_URL="$1"
    rand_num="$(seq 1 100|shuf -n 1)"
    nodeX="node$rand_num"
    docker-machine create -d pwd $nodeX
    eval $(docker-machine env $nodeX)
    docker ps
}

play_with_docker_cleanup(){
    #quick_help: https://stackoverflow.com/a/27875395
    echo -n "$Red You sure we are cleaning everything in ~/.docker/machine (y/n)? $Color_Off"
    read answer
    if echo "$answer" | grep -iq "^y" ;then
	rm -vrf ~/.docker/machine
    else
	echo -n "we were about to clean these: \n$(tree ~/.docker/machine/machines/ -L 1)"
	echo "$Green Nothing's changed !!$Color_Off"
    fi
}


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
    docker ps -q | xargs -n 1 docker inspect --format '{{ .NetworkSettings.Networks.invoice_default.IPAddress }} {{ .Config.Hostname }} {{ .Name }}' | sed 's/ \// /'
}
docker_network_info(){
    docker network ls -q| \
        xargs  docker network inspect --format "{{json .Name}} {{json .IPAM}}"
}

function docker_img_sort_size(){
    docker images --format '{{.ID}}   {{.Size}}   {{.Repository}}:{{.Tag}}' |sort -n -k 2
}


function dk(){docker-compose "$@" }
function dke(){dk exec "$@" }
function dkl(){dk logs -f "$@" }
function dkr(){dk restart "$@" }
function dkps(){dk ps "$@" }

function dkb(){dke ${1:-app} bundle }
# function dkbe(){dkb exec 
