#openssl, getting hands dirty
openssl_details_on(){
    file_to_details_on="$1"
    openssl x509 -text -noout -in ${file_to_details_on}
}


# generate test ssl certifictes for mongodb
gen_ssl_certs(){
    TMP_DIR=/tmp/mongocerts/ mkdir -p $TMP_DIR && cd $TMP_DIR
    DAYS=1825

    openssl req -newkey rsa:2048 -new -x509 -days $DAYS  -nodes -out mongodb-cert.crt -keyout mongodb-cert.key
    cat mongodb-cert.key mongodb-cert.crt > mongodb.pem
}


# get ssl info on urls
get_ssl_info(){
    SERVER_NAME=${1:-thapakazi.github.io}
    HOST_NAME=${2:-$SERVER_NAME}
    SSL_PORT=${3:-443}
    
    echo | openssl s_client \
                   -servername $SERVER_NAME \
                   -connect $HOST_NAME:$SSL_PORT 2>/dev/null \
        | openssl x509 -noout -dates
}
