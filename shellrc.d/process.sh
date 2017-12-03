
# oom score, greater the value, greater the chance os will slap hard
ps_top_oom_scores(){
    echo "$Blue printing process id not implemented yet $Color_Off"
    ls /proc/*/oom_score|xargs -I file sh -c "echo -n file ' ' && cat file 2> /dev/null"|sort -nk 2|tail
}
