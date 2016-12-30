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
