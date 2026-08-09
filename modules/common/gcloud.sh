# @module gcloud
# @summary Google Cloud DNS record helpers built on `gcloud dns record-sets
#          transaction`.
#
# Record fields default from the environment so the common case is a bare call:
#   DOMAIN   fully qualified record name   (default ok.thisthing.works)
#   MY_ZONE  Cloud DNS managed zone name   (default thisthingworks)
#   TTL      record TTL in seconds         (default 30)
#   TYPE     record type                   (default A)
#   IP       rrdata — no default, required

require gcloud || return 0

# ---------------------------------------------------------------- internals --

# Populate domain/zone/ttl/record_type/ip in the CALLER's scope. Both bash and
# zsh use dynamic scoping, so the caller declares them `local` and this writes
# into those. Replaces the old global `init()`, which shadowed /sbin/init and
# every other `init` in the shell.
#
# Positional arguments (all optional) override the environment without
# clobbering it: <ip> <domain> <zone>.
_gcloud_dns_defaults() {
    ip="${1:-${IP:-}}"
    domain="${2:-${DOMAIN:-ok.thisthing.works}}"
    zone="${3:-${MY_ZONE:-thisthingworks}}"
    ttl="${TTL:-30}"
    record_type="${TYPE:-A}"

    if [ -z "$ip" ]; then
        log_error "gcloud: no record data — set IP (or pass it as the first argument)"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------- dns ---------

# @describe Add a DNS record to a Cloud DNS managed zone, wrapped in a single
#           transaction.
# @usage    gcloud_dns_add_record [ip] [domain] [zone]
# @example  IP=1.2.3.4 gcloud_dns_add_record
# @example  gcloud_dns_add_record 1.2.3.4 api.example.com my-zone
# @requires gcloud
# @danger   Mutates live DNS for the whole zone.
# @see      gcloud_dns_remove_record
# @os       any
gcloud_dns_add_record() {
    local domain zone ttl record_type ip
    _gcloud_dns_defaults "$@" || return 1

    gcloud dns record-sets transaction start --zone="$zone" || return 1
    gcloud dns record-sets transaction add "$ip" \
        --name="$domain" \
        --ttl="$ttl" \
        --type="$record_type" \
        --zone="$zone" || {
        gcloud dns record-sets transaction abort --zone="$zone" >/dev/null 2>&1
        return 1
    }
    gcloud dns record-sets transaction execute --zone="$zone"
}

# @describe Remove a DNS record from a Cloud DNS managed zone, wrapped in a
#           single transaction.
# @usage    gcloud_dns_remove_record [ip] [domain] [zone]
# @example  IP=1.2.3.4 gcloud_dns_remove_record
# @example  gcloud_dns_remove_record 1.2.3.4 api.example.com my-zone
# @requires gcloud
# @danger   Deletes a live DNS record. Confirms first.
# @see      gcloud_dns_add_record
# @os       any
gcloud_dns_remove_record() {
    local domain zone ttl record_type ip
    _gcloud_dns_defaults "$@" || return 1

    confirm "Remove $record_type record $domain -> $ip from zone $zone?" || return 0

    gcloud dns record-sets transaction start --zone="$zone" || return 1
    gcloud dns record-sets transaction remove "$ip" \
        --name="$domain" \
        --ttl="$ttl" \
        --type="$record_type" \
        --zone="$zone" || {
        gcloud dns record-sets transaction abort --zone="$zone" >/dev/null 2>&1
        return 1
    }
    gcloud dns record-sets transaction execute --zone="$zone"
}

# ------------------------------------------------------- back-compat aliases -
# The long names above are the API. `init` is deliberately NOT re-exported —
# it shadowed a real binary and is gone for good.

alias add_domain='gcloud_dns_add_record'
alias remove_domain='gcloud_dns_remove_record'
