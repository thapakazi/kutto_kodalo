# this is why god invented CAPS LOCKS
# setxkbmap -option ctrl:nocaps

# emacs is the editor
export EDITOR='emacs';

#allday-allnight emacs; emacs; emacs
alias eamcs='emacs'
alias emasc='emacs'
alias emcas='emacs'
alias emcsa='emacs'
alias meacs='emacs'

# Prefer US English and use UTF-8.
export LANG='en_US.UTF-8';
export LC_ALL='en_US.UTF-8';

# Highlight section titles in manual pages.
export LESS_TERMCAP_md="${yellow}";

# Don’t clear the screen after quitting a manual page.
export MANPAGER='less -X';

# Always enable colored `grep` output.
# export GREP_OPTIONS='--color=auto';
