# touble with sound and mic
# visit: https://wiki.archlinux.org/index.php/Advanced_Linux_Sound_Architecture/Troubleshooting#Microphone

# record mic 
record_mic(){
    export TMP_RECORD=$(mktemp)
    RECORD_DURATION=${1:-10}
    arecord -d $RECORD_DURATION -f dat $TMP_RECORD
    echo -e "To play it, use: \n\t$Green aplay $TMP_RECORD $Color_Off"
}

# record and play tmp
test_mic_quick(){
    record_mic || {echo "something wrong while recording" && exit}
    aplay $TMP_RECORD
    rm $TMP_RECORD
}
