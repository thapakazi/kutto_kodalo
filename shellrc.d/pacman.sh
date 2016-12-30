### Archlinux

# orphans poor souls
pacman_list_orpahns(){
    pacman -Qtdq
}

# lets them rest in peace
pacman_remove_orpahns(){
    echo "listing orphans..."
    pacman_list_orpahns
    echo
    echo "removing themall..."
    sudo pacman -Rns $(pacman_list_orpahns)
}

# desc: how much time spent by a process
# url: https://bbs.archlinux.org/viewtopic.php?pid=431774#p431774
ptimer(){
    STARTTIME=$(date "+%s.%N")
    $*
    PROCESSTIME=$(echo "$(date +%s.%N)-$STARTTIME" | bc)
    echo "Process took $PROCESSTIME seconds."
}

# desc: try x times until it succeds
# url: https://bbs.archlinux.org/viewtopic.php?pid=431568#p431568
try(){
    COUNT=-1
    if [[ $1 =~ ^[0-9]+$ ]]; then
        COUNT=$1
        shift    
    fi

    STATUS=0

    while [ "$COUNT" -ne 0 ]; do
        let COUNT-=1
        $*
        STATUS=$?
        if [ $STATUS -eq 0 ]; then
            exit $STATUS
        fi
    done
    exit $STATUS
}
