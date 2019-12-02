init(){
    export domain="${DOMAIN:-ok.thisthing.works}"
    export zone="${MY_ZONE:-thisthingworks}"
    export ttl="${TTL:-30}"
    export type="${TYPE:-A}"
    export ip="${IP}"
}

add_domain(){
    init
    gcloud dns record-sets transaction start --zone=$zone
    gcloud dns record-sets transaction add ${ip} \
           --name=$domain \
           --ttl=${ttl} \
           --type=${type} \
           --zone=${zone}
    gcloud dns record-sets transaction execute --zone=$zone
}

remove_domain(){
    init
    gcloud dns record-sets transaction start --zone=$zone
    gcloud dns record-sets transaction remove --name=$doamin \
           --ttl="$ttl" \
           --type="$type"
    gcloud dns record-sets transaction execute --zone=$zone
}
