# list 5 memory suckers
top5_mem_killers(){
  PS_FORMAT=%mem,pid,ppid,etime,comm,cmd:20 ps -e|sort -r|head -6
}

# get threads info
threads_spawned(){
    for i in $@; do 
        echo "$i $(cat /proc/$i/status|grep -i thread)"
    done
}
passenger-thread-status(){
    threads_spawned `passenger-status |awk '/PID:/{print $3}'|xargs`
}
