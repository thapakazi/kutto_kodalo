#mplayer in action
function m_mplayer(){
    mplayer -vo "${@}"
}

alias mplayer_ascii="m_mplayer aa -monitorpixelaspect 0.5 ${@}"
alias mplayer_caca="m_mplayer caca ${@}"
alias mplayer_matrix="m_mplayer matrixview  ${@}"

#mplayer plays from youtube
# y_mplayer(){
#     mplayer -cookies -cookies-file /tmp/c $(youtube-dl -g -f 18 --cookies /tmp/c "$1")
# }
y_mplayer(){
    youtube-dl -q -o- "$*" |mplayer -af scaletempo -softvol -softvol-max 400 cache 8192 -
}

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

# handy remainder
# Usage:   remind in <time> <action i want to do>
# Example: remind in 30m i need to start studying
# Default: remind in 5m lets go eat :)
remind(){
    time=${2:-5m}
    rest=${${@:3}:-"lets go eat :)"}
    echo "ok, will remind you in $time about ${rest:0:12}..."
    {
        sleep $time && \
            xcowsay  --cow-size=med -t 15  \
                     --image=$HOME/Pictures/xcowsay/alarm-clock.png \
                     --think "${rest}"
    }& 
}


##  inspired from tweet: https://twitter.com/kathyra_/status/1160810013113237504/photo/1
alias damn_it='sudo $(fc -ln -1)'

# credits: https://twitter.com/nixcraft/status/1201354335747051520
old_tv(){
    P=(' ' █ ░ ▒ ▓);
    while :;do
        printf "\e[$[RANDOM%LINES+1];$[RANDOM%COLUMNS+1]f${P[$RANDOM%5]}";
    done
} 
