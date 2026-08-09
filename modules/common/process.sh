# @module process
# @summary Process inspection and control: what is holding a port, what is
#          eating memory, and watching a command repeat.
#
# Anything that reads /proc lives in modules/linux/procfs.sh instead — this file
# must work unchanged on macOS.

# @describe List the processes with the highest resident memory share.
# @usage    proc_top_memory [count]
# @example  proc_top_memory
# @example  proc_top_memory 15
# @os       any
proc_top_memory() {
    local count="${1:-5}"
    case "$count" in
        '' | *[!0-9]*) log_error "usage: proc_top_memory [count]"; return 1 ;;
    esac
    # `PS_FORMAT=... ps -e` is a procps-only trick; -o keywords work on BSD ps
    # too, so this is the same output on macOS and Linux.
    ps -A -o %mem,pid,ppid,etime,comm 2>/dev/null |
        {
            IFS= read -r header
            printf '%s\n' "$header"
            sort -rn -k1 | head -n "$count"
        }
}

# @describe Show which processes are listening on a TCP port, then kill them
#           after an explicit confirmation.
# @usage    proc_kill_port <port>
# @example  proc_kill_port 3001
# @requires lsof
# @os       any
# @danger   Sends SIGKILL. Always names the processes and confirms first; the old
#           killp defaulted to port 3001 and killed without asking.
proc_kill_port() {
    local port="$1" pids pid pidlist
    [ -n "$port" ] || { log_error "usage: proc_kill_port <port>"; return 1; }
    case "$port" in
        *[!0-9]*) log_error "proc_kill_port: port must be numeric: $port"; return 1 ;;
    esac
    has lsof || { log_error "proc_kill_port: lsof not found"; return 1; }

    pids=$(lsof -t -i:"$port" 2>/dev/null)
    [ -n "$pids" ] || { log_warn "Nothing is listening on port $port"; return 1; }

    pidlist=$(printf '%s' "$pids" | tr '\n' ',' | sed 's/,$//')
    log_warn "Processes on port $port:"
    ps -o pid,ppid,user,comm -p "$pidlist" 2>/dev/null

    confirm "kill -9 the process(es) above?" || { log_info "Left alone."; return 0; }

    printf '%s\n' "$pids" | while IFS= read -r pid; do
        [ -n "$pid" ] || continue
        kill -9 "$pid" 2>/dev/null && log_ok "killed $pid"
    done
}

# @describe Re-run a command on an interval with changes highlighted. Override
#           the interval with PROC_WATCH_INTERVAL (default 0.5s; the old
#           watch_prog used 0.02s, which just pegged a core).
# @usage    proc_watch_command <command> [argument]...
# @example  proc_watch_command kubectl get pods
# @example  PROC_WATCH_INTERVAL=2 proc_watch_command df -h
# @requires watch
# @os       any
proc_watch_command() {
    [ $# -gt 0 ] || { log_error "usage: proc_watch_command <command> [argument]..."; return 1; }
    has watch || { log_error "proc_watch_command: watch not found (brew install watch)"; return 1; }
    watch -n "${PROC_WATCH_INTERVAL:-0.5}" -d "$@"
}

# ------------------------------------------------------------ back-compat ----

alias top5_mem_killers='proc_top_memory'
alias killp='proc_kill_port'
alias watch_prog='proc_watch_command'
