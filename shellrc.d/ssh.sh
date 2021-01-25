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
     
    cat ~/.ssh/config.d/*.config >> ~/.ssh/config
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

EASYSSH_BIN=`which easyssh`
SSH_CONFIG_DIR="$HOME/.ssh/config.d"
hostgen(){
    account=${1:-"dibya"}
    region=${2:-"us-east-1"}
    port=${3:-"22"}
    ssh_user=${4:-"ubuntu"}
    echo "generating list"
    source ~/.aws-$account
    aws sts get-caller-identity
    export AWS_REGION=$region
    SSH_CONFIG=$SSH_CONFIG_DIR/$account-$region.config
    echo "" >> $SSH_CONFIG
    ${EASYSSH_BIN} -port $port -username $ssh_user | tee  $SSH_CONFIG
    echo "" >> $SSH_CONFIG
    echo "...pulling server list from there"
    ssh_config_refresh
}
