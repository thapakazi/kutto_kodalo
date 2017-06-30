# my way of maintaining ssh stuffs
ssh_config_refresh() {
    mkdir -p ~/.ssh/config.d/
    [ -e ~/.ssh/config ] && mv ~/.ssh/config ~/.ssh/config.last
    echo "# ssh config generated with $0 `date`" > ~/.ssh/config
    echo "
    # ssh_config_refresh () {
    #   mkdir -p ~/.ssh/config.d/
    #   [ -e ~/.ssh/config ] && mv ~/.ssh/config ~/.ssh/config.last
    #     echo "..."  >> ~/.ssh/config
    # cat ~/.ssh/config.d/* >> ~/.ssh/config
    # }" >> ~/.ssh/config
    echo "Host *
      ControlMaster auto
      ControlPersist 600    
      ForwardAgent true" > ~/.ssh/config
     
    cat ~/.ssh/config.d/* >> ~/.ssh/config
}

ssh_config_refresh

# incomplete

# x2x fun
ssh_with_x2x(){
    HOST=${1:-192.168.2.55}
    USER=${2:-nikesh}
    DIRECTION=${3:-east}
    DISPLAY=${4:-:0.0}
    echo "ssh ${HOST} -l${USER} -Y x2x -${DIRECTION} -to ${DISPLAY}"
    ssh ${HOST} -l${USER} -Y x2x -${DIRECTION} -to ${DISPLAY}
}


get_hosts(){
    awk '/prod-worker/||/prod-app/||/production-app/||/production-worker/{print$2}' ~/.ssh/config
}

get_hosts_grp(){
    get_hosts | grep -i ${1:-client}
}

ssh_keys_generator(){
    APPLICATION_NAME=$1
    KEYS_TO_GENERATE_AT=/tmp/ssh_keys_list && mkdir -p $KEYS_TO_GENERATE_AT
    ssh-keygen -t rsa -b 4096 -C "${APPLICATION_NAME}" -f $KEYS_TO_GENERATE_AT/$APPNAME -N ""
}

# application
ssh_keygen_all(){
    # later: check if $APPLICATION_LIST exists
    for APPNAME in $APPLICATION_LIST; do
        ssh_keys_generator $APPNAME
    done
}
