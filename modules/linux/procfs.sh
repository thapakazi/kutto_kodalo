# @module procfs
# @summary Process inspection that reads /proc directly: environment of a live
#          process, OOM killer scores, and thread counts.
#
# Linux only. macOS has no procfs and its `ps` refuses to print another
# process's environment at all, so there is no portable equivalent for
# procfs_show_env — see modules/common/process.sh for what does port.

# Cheapest possible guard first: a stat that fails instantly off Linux, so we
# never pay for the fork inside is_linux on a Mac.
[ -r /proc/self/status ] || return 0
is_linux || return 0

# @describe Print the environment of a running process, one variable per line.
# @usage    procfs_show_env [pid]
# @example  procfs_show_env 1
# @example  procfs_show_env            # this shell
# @os       linux
procfs_show_env() {
    local pid="${1:-$$}"
    case "$pid" in
        '' | *[!0-9]*) log_error "usage: procfs_show_env [pid]"; return 1 ;;
    esac
    [ -d "/proc/$pid" ] || { log_error "procfs_show_env: no such process: $pid"; return 1; }
    [ -r "/proc/$pid/environ" ] || { log_error "procfs_show_env: not permitted to read the environment of $pid (try sudo)"; return 1; }
    tr '\0' '\n' < "/proc/$pid/environ"
}

# @describe List the processes most likely to be killed first when memory runs
#           out, highest OOM score first, with their names.
# @usage    procfs_top_oom_scores [count]
# @example  procfs_top_oom_scores
# @example  procfs_top_oom_scores 20
# @os       linux
procfs_top_oom_scores() {
    local count="${1:-10}" f pid score comm
    case "$count" in
        '' | *[!0-9]*) log_error "usage: procfs_top_oom_scores [count]"; return 1 ;;
    esac
    {
        for f in /proc/[0-9]*/oom_score; do
            [ -r "$f" ] || continue
            pid="${f#/proc/}"
            pid="${pid%/oom_score}"
            score=$(cat "$f" 2>/dev/null) || continue
            comm=$(cat "/proc/$pid/comm" 2>/dev/null) || comm='?'
            printf '%s\t%s\t%s\n' "$score" "$pid" "$comm"
        done
    } | sort -rn -k1 | head -n "$count"
}

# @describe Print the thread count of one or more processes. The old
#           threads_spawned grepped /proc/PID/status and printed the raw lines.
# @usage    procfs_show_threads <pid>...
# @example  procfs_show_threads 1 $$
# @os       linux
procfs_show_threads() {
    local pid threads comm
    [ $# -gt 0 ] || { log_error "usage: procfs_show_threads <pid>..."; return 1; }
    for pid in "$@"; do
        if [ ! -r "/proc/$pid/status" ]; then
            log_warn "procfs_show_threads: no such process: $pid"
            continue
        fi
        threads=$(awk '/^Threads:/ {print $2}' "/proc/$pid/status")
        comm=$(cat "/proc/$pid/comm" 2>/dev/null)
        printf '%s\t%s threads\t%s\n' "$pid" "${threads:-?}" "${comm:-?}"
    done
}

# @describe Print the thread count of every Phusion Passenger worker process.
# @usage    procfs_show_passenger_threads
# @example  procfs_show_passenger_threads
# @requires passenger-status
# @os       linux
# @see      procfs_show_threads
procfs_show_passenger_threads() {
    local pids
    has passenger-status || { log_error "procfs_show_passenger_threads: passenger-status not found"; return 1; }
    pids=$(passenger-status 2>/dev/null | awk '/PID:/ {print $3}')
    [ -n "$pids" ] || { log_warn "No Passenger worker processes found"; return 1; }
    # shellcheck disable=SC2086  # intentional word splitting: one argument per pid
    procfs_show_threads $pids
}

# ------------------------------------------------------------ back-compat ----

alias envof='procfs_show_env'
alias ps_top_oom_scores='procfs_top_oom_scores'
alias threads_spawned='procfs_show_threads'
alias passenger-thread-status='procfs_show_passenger_threads'
