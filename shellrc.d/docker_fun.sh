quick_pg(){

    [ ! -f /tmp/secrets ] && cat > /tmp/secrets <<EOF
POSTGRES_DB=mydb
POSTGRES_USER=my_user
POSTGRES_PASSWORD=uGbwtA76uXD2
EOF
    docker run --rm -it --env-file /tmp/secrets -p5432:5432 postgres:11-alpine
}

# thanks to @xhagrg, your gift saved me realtime
# I literally mount the ssd partation for /var/lib/docker 
#sandisk mount point
docker_hack(){
    DISK_UUID=8a741529-d1f6-4c90-9f90-9dc96cddf9fc
    sudo mount UUID=${DISK_UUID} /mnt/sandisk
    sudo systemctl restart docker
    sudo iptables-restore < ~/.docker/iptables.config
}

docker_hack_cleanup(){
    #TODO: cleanups
}
