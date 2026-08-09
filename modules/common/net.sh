# @module net
# @summary Network chores: public IP and ISP lookup, GitHub keys, URL scraping,
#          media downloads, site mirroring, packet capture, and TLS issuance.
#
# Functions are grouped behind `require` blocks so a missing tool removes only
# the functions that need it, never the whole module. Definitions inside those
# blocks stay unindented on purpose — the doc generator reads column-0 blocks.

# Browser user agent used when scraping pages that dislike curl. `env_vars.sh`
# exports FIREFOX_A; fall back to a sane default so this module stands alone.
SHELLRC_UA="${FIREFOX_A:-Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0}"

# ---------------------------------------------------------------- curl bits --

if require curl; then

# @describe Print this machine's public IPv4 address.
# @usage    net_get_public_ip
# @example  net_get_public_ip
# @requires curl
# @os       any
net_get_public_ip() {
    local ip
    ip=$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null) \
        || ip=$(curl -fsS --max-time 5 https://ifconfig.me 2>/dev/null) \
        || { log_error "net_get_public_ip: could not reach any IP echo service"; return 1; }
    printf '%s\n' "$ip"
}

# @describe Print the organisation (ISP) that owns this machine's public IP.
# @usage    net_get_isp
# @example  net_get_isp
# @requires curl
# @os       any
# @see      net_get_public_ip
net_get_isp() {
    local json
    json=$(curl -fsS --max-time 5 https://ipinfo.io/json 2>/dev/null) \
        || { log_error "net_get_isp: could not reach ipinfo.io"; return 1; }
    if has jq; then
        printf '%s\n' "$json" | jq -r '.org // "unknown"'
    else
        printf '%s\n' "$json" | tr ',' '\n' | grep '"org"' | cut -d'"' -f4
    fi
}

# @describe Fetch a URL asking for JSON, following redirects.
# @usage    net_fetch_json <url> [curl-option]...
# @example  net_fetch_json https://api.github.com/repos/cli/cli
# @requires curl
# @os       any
net_fetch_json() {
    [ $# -gt 0 ] || { log_error "usage: net_fetch_json <url> [curl-option]..."; return 1; }
    curl -sSL -H "Accept: application/json" "$@"
}

# @describe Copy someone's public SSH keys from GitHub to the clipboard, one key
#           per line with their username appended as the comment.
# @usage    net_copy_github_keys [github-user]
# @example  net_copy_github_keys torvalds
# @requires curl
# @os       any
net_copy_github_keys() {
    local user="${1:-${GITHUB_USER:-thapakazi}}" keys
    keys=$(curl -fsSL --max-time 10 "https://github.com/${user}.keys" 2>/dev/null) \
        || { log_error "net_copy_github_keys: could not fetch keys for $user"; return 1; }
    [ -n "$keys" ] || { log_error "net_copy_github_keys: $user has no public keys"; return 1; }
    keys=$(printf '%s\n' "$keys" | awk -v u="$user" 'NF {print $0 " " u}')
    printf '%s\n' "$keys"
    printf '%s\n' "$keys" | clip_copy && log_ok "Copied $(printf '%s\n' "$keys" | wc -l | tr -d ' ') key(s) for $user"
}

# @describe Print every absolute http(s) URL found on a page. Reads the URL from
#           the clipboard when none is given.
# @usage    net_extract_urls [url]
# @example  net_extract_urls https://news.ycombinator.com
# @requires curl
# @os       any
net_extract_urls() {
    local url="$1"
    [ -n "$url" ] || url=$(clip_paste 2>/dev/null)
    [ -n "$url" ] || { log_error "usage: net_extract_urls <url>   (or put one on the clipboard)"; return 1; }
    curl -fsSL --max-time 20 --user-agent "$SHELLRC_UA" -- "$url" \
        | tr '"' '\n' \
        | tr "'" '\n' \
        | grep -E '^(https?:)?//' \
        | sort -u
}

fi   # require curl

# ---------------------------------------------------- no external tool needed -

# @describe Turn a mangled IP such as AWS's `ip-10-0-3-17` or `10_0_3_17` back
#           into a real dotted-quad, print it, and put it on the clipboard.
# @usage    net_normalize_ip <mangled-ip>
# @example  net_normalize_ip ip-10-0-3-17
# @example  net_normalize_ip 192_168_1_10
# @os       any
net_normalize_ip() {
    local ip="$1"
    [ -n "$ip" ] || { log_error "usage: net_normalize_ip <mangled-ip>"; return 1; }
    ip="${ip#ip-}"
    ip="${ip#ip_}"
    ip=$(printf '%s' "$ip" | tr '_-' '..')
    printf '%s\n' "$ip"
    printf '%s' "$ip" | clip_copy
}

# @describe Copy your own SSH public key to the clipboard. Prefers ed25519 and
#           falls back to RSA; pass a path to pick a specific key.
# @usage    net_copy_ssh_pubkey [path-to-pubkey]
# @example  net_copy_ssh_pubkey
# @example  net_copy_ssh_pubkey ~/.ssh/work_ed25519.pub
# @os       any
net_copy_ssh_pubkey() {
    local key="$1" candidate
    if [ -z "$key" ]; then
        for candidate in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_ecdsa.pub" "$HOME/.ssh/id_rsa.pub"; do
            [ -f "$candidate" ] && { key="$candidate"; break; }
        done
    fi
    [ -n "$key" ] || { log_error "net_copy_ssh_pubkey: no public key found under ~/.ssh"; return 1; }
    clip_copy_file "$key" && log_ok "Copied $key to the clipboard"
}

# @describe Open a GitHub user's profile in the browser.
# @usage    net_open_github_user <username>
# @example  net_open_github_user thapakazi
# @os       any
net_open_github_user() {
    local user="$1"
    [ -n "$user" ] || { log_error "usage: net_open_github_user <username>"; return 1; }
    os_open "https://github.com/$user"
}

# @describe Print every YouTube watch URL found in the given files (or stdin).
# @usage    net_extract_youtube_urls [file]...
# @example  net_extract_youtube_urls playlist.html
# @example  pbpaste | net_extract_youtube_urls
# @os       any
net_extract_youtube_urls() {
    grep -Eoh 'https?://[^[:space:]]*[?&]v=[A-Za-z0-9_-]+' "$@" 2>/dev/null | sort -u
}

# ------------------------------------------------------------------ yt-dlp ----

if require yt-dlp; then

# @describe Download a video with yt-dlp's defaults.
# @usage    net_download_media <url>...
# @example  net_download_media 'https://youtu.be/dQw4w9WgXcQ'
# @requires yt-dlp
# @os       any
net_download_media() {
    [ $# -gt 0 ] || { log_error "usage: net_download_media <url>..."; return 1; }
    yt-dlp "$@"
}

# @describe Download audio only and transcode it to mp3.
# @usage    net_download_audio <url>...
# @example  net_download_audio 'https://youtu.be/dQw4w9WgXcQ'
# @requires yt-dlp ffmpeg
# @os       any
net_download_audio() {
    [ $# -gt 0 ] || { log_error "usage: net_download_audio <url>..."; return 1; }
    yt-dlp --extract-audio --audio-format mp3 "$@"
}

# @describe Download the best video and audio streams and merge them into mp4.
# @usage    net_download_video <url>...
# @example  net_download_video 'https://youtu.be/dQw4w9WgXcQ'
# @requires yt-dlp ffmpeg
# @os       any
net_download_video() {
    [ $# -gt 0 ] || { log_error "usage: net_download_video <url>..."; return 1; }
    yt-dlp -f 'bv*+ba/b' --merge-output-format mp4 "$@"
}

# @describe List every downloadable format for a URL, so you can pick an id.
# @usage    net_list_formats <url>
# @example  net_list_formats 'https://youtu.be/dQw4w9WgXcQ'
# @requires yt-dlp
# @os       any
# @see      net_download_format
net_list_formats() {
    [ $# -gt 0 ] || { log_error "usage: net_list_formats <url>"; return 1; }
    yt-dlp -F "$@"
}

# @describe Download a specific format id, as listed by net_list_formats.
# @usage    net_download_format <format-id> <url>
# @example  net_download_format 137+140 'https://youtu.be/dQw4w9WgXcQ'
# @requires yt-dlp
# @os       any
# @see      net_list_formats
net_download_format() {
    [ $# -ge 2 ] || { log_error "usage: net_download_format <format-id> <url>"; return 1; }
    yt-dlp --console-title -f "$@"
}

fi   # require yt-dlp

# -------------------------------------------------------------------- wget ----

if require wget; then

# @describe Mirror a website for offline reading: recursive, page requisites,
#           rewritten links, no walking above the starting path.
# @usage    net_mirror_site <url>
# @example  net_mirror_site https://example.com/docs/
# @requires wget
# @os       any
net_mirror_site() {
    [ -n "$1" ] || { log_error "usage: net_mirror_site <url>"; return 1; }
    wget --recursive --no-clobber --page-requisites --html-extension \
         --convert-links --restrict-file-names=windows --no-parent "$@"
}

fi   # require wget

# -------------------------------------------------------------------- nmap ----

if require nmap; then

# @describe Ping-sweep a network range and list the hosts that answer.
# @usage    net_scan_hosts <cidr-or-range>
# @example  net_scan_hosts 192.168.1.0/24
# @requires nmap sudo
# @os       any
net_scan_hosts() {
    [ -n "$1" ] || { log_error "usage: net_scan_hosts <cidr-or-range>"; return 1; }
    sudo nmap -sn "$@"
}

fi   # require nmap

# ----------------------------------------------------------------- tcpdump ----

if require tcpdump; then

# @describe Dump readable ASCII payloads of TCP traffic heading to a port.
#           Defaults to port 80. Needs root, so it will prompt for sudo.
# @usage    net_dump_tcp_headers [port]
# @example  net_dump_tcp_headers
# @example  net_dump_tcp_headers 8080
# @requires tcpdump sudo
# @os       any
net_dump_tcp_headers() {
    local port="${1:-80}"
    case "$port" in
        '' | *[!0-9]*) log_error "net_dump_tcp_headers: port must be numeric: $port"; return 1 ;;
    esac
    sudo tcpdump -n -S -s 0 -A "tcp dst port $port"
}

fi   # require tcpdump

# ----------------------------------------------------------------- certbot ----

if require certbot; then

# @describe Issue a Let's Encrypt certificate using the manual DNS-01 challenge,
#           in a throwaway working directory so nothing lands in /etc.
# @usage    net_issue_letsencrypt_cert <domain> [email]
# @example  net_issue_letsencrypt_cert example.com admin@example.com
# @requires certbot
# @os       any
net_issue_letsencrypt_cert() {
    local domain="$1" email="$2" workdir
    [ -n "$domain" ] || { log_error "usage: net_issue_letsencrypt_cert <domain> [email]"; return 1; }
    email="${email:-bot@$domain}"
    workdir=$(tmp_dir letsencrypt) || return 1
    log_info "Working in $workdir — certificates land under $workdir/live/$domain"
    (
        cd -- "$workdir" || exit 1
        mkdir -p logs
        certbot --manual --config-dir=. --work-dir=. --logs-dir ./logs \
                certonly --preferred-challenges dns --agree-tos \
                -m "$email" -d "$domain"
    )
}

fi   # require certbot

# ---------------------------------------------------------------- imdbtool ----

if require imdbtool; then

# @describe Look up a film or series on IMDb and print the JSON record.
# @usage    net_get_movie_info <title>
# @example  net_get_movie_info "The Big Lebowski"
# @requires imdbtool
# @os       any
net_get_movie_info() {
    [ $# -gt 0 ] || { log_error "usage: net_get_movie_info <title>"; return 1; }
    if has jq; then
        imdbtool -t "$*" -r JSON | jq .
    else
        imdbtool -t "$*" -r JSON
    fi
}

fi   # require imdbtool

# ------------------------------------------------------------ back-compat ----
# Old names kept as aliases. Dots are legal in alias names, so the muscle-memory
# `youtube.dlmp3` still works even though the function behind it is renamed.

alias public_ip='net_get_public_ip'
alias get_my_isp_name='net_get_isp'
alias curl.json='net_fetch_json'
alias public_keys_of='net_copy_github_keys'
alias public_key='net_copy_ssh_pubkey'
alias whois_='net_open_github_user'
alias extract_urls='net_extract_urls'
alias get_youtube_urls='net_extract_youtube_urls'
alias tr_ip='net_normalize_ip'
alias youtube.dl='net_download_media'
alias youtube.dlmp3='net_download_audio'
alias youtube.dlmp4='net_download_video'
alias youtube.dlF='net_list_formats'
alias youtube.dlf='net_download_format'
alias wget.grab.all='net_mirror_site'
alias nmap_hachers_way='net_scan_hosts'
alias dump_tcp_headers='net_dump_tcp_headers'
alias letsencrypt_gen='net_issue_letsencrypt_cert'
alias imdb='net_get_movie_info'
