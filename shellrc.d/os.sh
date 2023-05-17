get_os(){
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "mac"
    elif [[ "$OSTYPE" == "linux"* ]]; then
        echo "linux"
    else
        echo "what, you an alien ??"
    fi
}

if_mac(){
    [[ "$(get_os)" == "mac" ]] && true
}

if_linux(){
    [[ "$(get_os)" == "linux" ]] && true
}

if_alien(){
    [[ "$(get_os)" == *"alien"* ]] && true
}
