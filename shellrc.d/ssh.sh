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
