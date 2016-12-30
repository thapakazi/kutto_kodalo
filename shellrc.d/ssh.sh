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
