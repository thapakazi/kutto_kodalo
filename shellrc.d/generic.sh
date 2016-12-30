# this is why god invented CAPS LOCKS
setxkbmap -option ctrl:nocaps

# emacs is the editor
export EDITOR='emacs';

#allday-allnight emacs; emacs; emacs
alias eamcs='emacs'
alias emasc='emacs'
alias emcas='emacs'
alias emcsa='emacs'
alias meacs='emacs'

## little bit of robery helps :D
## thanks: https://github.com/karan/dotfiles/blob/master/.bashrc
##
# Increase history size. Allow 32³ entries; the default is 500.
export HISTSIZE='32768';
export HISTFILESIZE="${HISTSIZE}";
# Omit duplicates and commands that begin with a space from history.
export HISTCONTROL='ignoreboth';

# Prefer US English and use UTF-8.
export LANG='en_US.UTF-8';
export LC_ALL='en_US.UTF-8';

# Highlight section titles in manual pages.
export LESS_TERMCAP_md="${yellow}";

# Don’t clear the screen after quitting a manual page.
export MANPAGER='less -X';

# Always enable colored `grep` output.
# export GREP_OPTIONS='--color=auto';
