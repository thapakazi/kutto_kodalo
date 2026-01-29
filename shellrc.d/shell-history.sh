# ---  Unified Unlimited History ---
setup_unlimited_history() {
    # 1. Shell Detection
    if [ -n "$ZSH_VERSION" ]; then
        # Zsh-specific: Use a large integer (Zsh does not support -1)
        export HISTSIZE=1000000000
        export SAVEHIST=1000000000
        export HISTFILE="$HOME/.zsh_history"

        # Zsh Options: Append immediately and share across windows
        setopt INC_APPEND_HISTORY
        setopt SHARE_HISTORY
        setopt EXTENDED_HISTORY      # Save timestamps
        setopt HIST_IGNORE_ALL_DUPS  # Clear duplicates

    elif [ -n "$BASH_VERSION" ]; then
        # Bash-specific: -1 is supported in 4.3+ for true unlimited
        export HISTSIZE=-1
        export HISTFILESIZE=-1
        export HISTFILE="$HOME/.bash_history"

        # Bash Options: Append and sync
        shopt -s histappend
        export HISTCONTROL=ignoreboth
        export HISTTIMEFORMAT="%F %T "
        # Sync history across multiple open bash sessions immediately
        export PROMPT_COMMAND="history -a; history -n; $PROMPT_COMMAND"
    fi
}

# Run the function on shell startup
setup_unlimited_history
