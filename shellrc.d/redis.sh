# funky alias
alias sentinel-cli='redis-cli -p 26379'

# handy
redis_keys(){
    redis-cli info keyspace
}
redis_replication(){
    redis-cli info replication
}

# destructive, maybe
redis_sleep_30(){
    time=${1:-30}
    redis-cli debug sleep $time
}
