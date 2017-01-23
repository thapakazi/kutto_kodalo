tr_ip(){
    a=$(echo $1 | tr '_' '.')
    echo $a
    echo $a | xclip -sel c
    
}
