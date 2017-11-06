#!/bin/bash
# My personal preference
# copied from rho with iptux
#+DATE: Sunday, Jan 17 2016

# My ways
# alias startx='startx &> ~/.xlog'

# Stupid stuffs
alias pm='pacman'
alias rc.d='systemctl'

# python
alias py3="python3"
alias pysrv="python3 -m http.server"
alias py2srv="/usr/bin/python2 -m SimpleHTTPServer"
alias py2="PYTHONSTARTUP="$HOME/.pythonrc" /usr/bin/python2.7"

function py {
    ##
    ### python wrapper for multiplexer
    if [[ $# -eq 0 ]]; then
        which bpython && bpython || python
        return
    fi
    python $@
}

# WINE is the standard env variable
export WIN="~/.wine/dosdevices/c:"
alias c:="cd $WIN"

#playing aoe quick; sometime though
alias aoe='cd ~/.wine/drive_c/games/aoe2/age2_x1/; wine age2_x1.exe'

function emacs {
    ##
    ### emacs wrapper for mulitplexing
    if [[ $# -eq 0 ]]; then
        /usr/bin/emacs # "emacs" is function, will cause recursion
        return
    fi

    args=($*)
    # TIP: add '-' arguement for opening new emacs session
    for ((i=0; i <= ${#args}; i++)); do
        local a=${args[i]}
        # NOTE: -c create frame; -nw: no-window
        if [[ ${a:0:1} == '-' && $a != '-c' ]]; then
            # TIPS: -nw will not work with setsid use '&'
            /usr/bin/emacs ${args[*]}
            return
        fi
    done

    setsid emacsclient -n -a /usr/bin/emacs ${args[*]}
}


function nemo {
    ##
    ### nemo (file browser) wrapper
    if [[ $# -eq 0 ]]; then
        setsid /usr/bin/nemo . # "nemo" is function, will cause recursion
    else
        setsid /usr/bin/nemo $@
    fi
}


function ssh {
    ##
    ### ssh wrapper for smart behaviour
    if [[ $# -eq 0 ]]; then
        /usr/bin/ssh # "ssh" is function, will cause recursion
        return
    fi

    /usr/bin/ssh $* #2> /tmp/ssh_key_error
    exitcode=$?
    if [[ $exitcode -eq 0 ]]; then
        return 0
    fi

    cat /tmp/ssh_key_error
    local v=$(sed -n 's/.*known_hosts:\([0-9]*\).*/\1/p' /tmp/ssh_key_error)
    if [[ $v == "" ]]; then
        return $exitcode
    fi

    echo -n "\nDo you wanna fix and continue? "
    read reply
    if [[ $reply == "y" || $reply == "Y" || $reply == "" || $reply == "yes" ]]; then
        local v=$(sed -n 's/.*known_hosts:\([0-9]*\).*/\1/p' /tmp/ssh_key_error)
        sed -i "${v}d" $HOME/.ssh/known_hosts
        /usr/bin/ssh $*
        return $?
    fi
}
