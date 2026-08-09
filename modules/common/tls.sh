# @module tls
# @summary OpenSSL helpers: inspect a certificate file, inspect a live endpoint,
#          and generate self-signed certificates for local testing.

require openssl || return 0

# @describe Print a certificate file in full human-readable form: subject, issuer,
#           validity window, SANs, key usage, signature algorithm.
# @usage    tls_show_cert <certificate-file>
# @example  tls_show_cert /etc/ssl/certs/mycert.crt
# @requires openssl
# @os       any
tls_show_cert() {
    local file="$1"

    if [ -z "$file" ]; then
        log_error "usage: tls_show_cert <certificate-file>"
        return 1
    fi
    if [ ! -r "$file" ]; then
        log_error "tls_show_cert: cannot read: $file"
        return 1
    fi

    openssl x509 -text -noout -in "$file"
}

# @describe Print the notBefore/notAfter dates of the certificate a TLS server is
#           currently presenting. SNI name and connect host are separate so you
#           can test a specific backend behind a load balancer.
# @usage    tls_get_remote_info [sni-name] [host] [port]
# @example  tls_get_remote_info example.com
# @example  tls_get_remote_info www.example.com 203.0.113.10 8443
# @requires openssl
# @os       any
tls_get_remote_info() {
    local sni="${1:-thapakazi.github.io}"
    local host="${2:-$sni}"
    local port="${3:-443}"

    echo | openssl s_client -servername "$sni" -connect "$host:$port" 2>/dev/null |
        openssl x509 -noout -subject -issuer -dates
}

# @describe Generate a self-signed certificate, its key, and a concatenated PEM
#           bundle (the form mongod and some proxies want) into a directory. With
#           no output directory it creates a fresh private temp dir and prints the
#           path. Never changes your working directory.
# @usage    tls_gen_self_signed [common-name] [days] [output-dir]
# @example  tls_gen_self_signed
# @example  tls_gen_self_signed mongo.local 825 ~/certs
# @requires openssl
# @os       any
tls_gen_self_signed() {
    local common_name="${1:-localhost}"
    local days="${2:-825}"
    local out_dir="$3"
    local name="${common_name%%.*}"

    case "$days" in
        '' | *[!0-9]*) log_error "tls_gen_self_signed: days must be a whole number"; return 1 ;;
    esac

    if [ -z "$out_dir" ]; then
        out_dir="$(tmp_dir certs)" || return 1
    elif [ ! -d "$out_dir" ]; then
        mkdir -p "$out_dir" || return 1
    fi

    # No `cd`: everything is written by absolute path, so this cannot strand the
    # caller in another directory the way the original did.
    if ! openssl req -newkey rsa:2048 -new -x509 -nodes \
        -days "$days" \
        -subj "/CN=$common_name" \
        -keyout "$out_dir/$name.key" \
        -out "$out_dir/$name.crt" 2>/dev/null
    then
        log_error "tls_gen_self_signed: openssl req failed"
        return 1
    fi

    cat "$out_dir/$name.key" "$out_dir/$name.crt" > "$out_dir/$name.pem" || return 1
    chmod 600 "$out_dir/$name.key" "$out_dir/$name.pem" 2>/dev/null

    log_ok "Self-signed cert for CN=$common_name, valid $days days:"
    printf '%s\n' "$out_dir/$name.crt" "$out_dir/$name.key" "$out_dir/$name.pem"
}

# ------------------------------------------------------------ back-compat ----
# Old names from shellrc.d/openssl.sh.

alias openssl_details_on='tls_show_cert'
alias get_ssl_info='tls_get_remote_info'
alias gen_ssl_certs='tls_gen_self_signed'
