#mplayer in action
function m_mplayer(){
    mplayer -vo "${@}"
}

alias mplayer_ascii="m_mplayer aa -monitorpixelaspect 0.5 ${@}"
alias mplayer_caca="m_mplayer caca ${@}"
alias mplayer_matrix="m_mplayer matrixview  ${@}"

# messing up with uptime 
uptime(){
 echo "lol, YOU BEEN UP ALL NIGHT HIGH all season"
}

# custom, I don't care if you don't have it
# but if you are stuborrn: github.com/haude/upisdown
UPDOWN_BIN=${UPDOWN_BIN:-'/home/thapakazi/github/haude/upisdown'}
flip_it(){
    $UPDOWN_BIN/main.sh "$@" | xclip -sel c
}
just_flip(){
    $UPDOWN_BIN/main.sh "$@" 
}

# quick output mic to speakers
# https://askubuntu.com/a/887658
mic_to_speaker(){
    arecord -f cd - | aplay -
    # wanna save it too
    # arecord -f cd - | tee output.wav | aplay -
}

can_u(){

    ~/.go/bin/pamcan;sleep 1s; clear
}
