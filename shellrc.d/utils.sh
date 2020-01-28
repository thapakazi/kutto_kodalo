#desperate time desperate measures :)
# demo: https://showterm.io/89006be66e19b6e70bc4b#
free_up_space(){

    echo "WARNING:: this is destructive command, don't blame me afterwards"
    echo "----------------------------------------------------------------"
    echo "You will gain the following space back: "
    pacman_pkgs=/var/cache/pacman/pkg
    go_mod_cache=/home/`whoami`/go/pkg/mod
    yarn_shit=/home/`whoami`/.cache/yarn
    yay_shit=/home/`whoami`/.cache/yay/
    junks=( \
            $pacman_pkgs \
            $go_mod_cache \
            /var/log/journal/4834be0b8d3c43df9a86e9c410227275 \
            $yarn_shit \
            $yay_shit \
    )
    du -sh ${junks[@]}
    while true; do
        echo
        read YN\?"Let's clean your shits [Y/n]? "
        echo
        case $YN in
            [Nn]* ) echo "no harm done"; break;;
            [Yy]* ):
                   echo "Nothing fancy, just saving your ass"
                   sudo rm -rf $pacman_pkgs/* $yarn_shit $yay_shit  # toldya, its kinda bad
                   sudo journalctl --vacuum-time=1d                 # run your vacuum cleaner
                   go clean --modcache                              # if you do have go mod caches
                   go clean --cache                                 # clean ~/.cache/go-build
                   npm cache clean --force                          # clean up ~/.npm/_cache
                   break;;
            * ) echo "Damn it, खुरुक्क y/n type गर्त";;
        esac
    done
}

mkcd(){
    # mkdir "$1"; cd "$1"
    mkdir -p "$@" && cd "$_";
}

envof() {
    sed 's/\x0/\n/g' /proc/${1}/environ;
}

# Create a git.io short URL
function gitio() {
    GIT_IO_URL='https://git.io'
    if [ -z "${1}" ]; then
        echo "Usage: \`gitio url\`";
        return 1;
    fi;
    echo $GIT_IO_URL/`curl -SsL $GIT_IO_URL/create -F "url=${1}"`|xclip -sel c
}

#sick of ssh keys pull
public_keys_of () {
   echo "$(curl -SsL https://github.com/${1:-thapakazi}.keys) $1" | xclip -sel c
}
# public key self
public_key(){
    xclip -sel c < ~/.ssh/id_rsa.pub
}

whois_(){
    user="$@"
    xdg-open https://github.com/$user
}

#python json validator
alias jcat='cat $1 |python -m json.tool'

# human friendly sort by size
alias duh='du -sh *|sort -h'

# some temporary buffering in hdd
alias youtube.dl='youtube-dl -t --console-title'
alias youtube.dlf='youtube-dl -t --console-title -f'
alias youtube.dlF='youtube-dl -F'
youtube.dlmp3(){
    youtube-dl --extract-audio --audio-format mp3 "$@"
}

# some crawling stuffs
alias wget.grab.all='wget --recursive --no-clobber --page-requisites --html-extension --convert-links --restrict-file-names=windows --no-parent'


eval "$(fasd --init auto)"

# buffer hacks
buffer(){
    xclip -sel c
}
buffercopy(){
    buffer < $1
}

# yell and copy in buffer
buffer_with_cow(){ echo "$@" | buffer && xcowsay "$@"}

alias curl.json='curl -i -H "Accept: application/json"'

# not sure how much relavent is it ?
alias startx='ssh-add startx'

#random password of desired length
randpassd(){
    < /dev/urandom tr -dc '_A-Z-a-z-0-9+-~!@#$%^&*()_+=-'| head -c${1:-16};echo;
    # openssl rand -base64 |head -c${1:-16};echo;
}
randpass(){
    randpassd ${1:-16}|xclip -sel c
}

#mimicing .split(",") #quick_hack
split_string_like_js(){
    echo $1|sed 's/ /","/g'|awk '{print "[\"" $0 "\"]"}'
}

#spliting comma ',' seperated values into new multiple line values
# one day in future: split_strings_to_new_line aaa,bbbb,ccc,ddd,eee |xargs -I line echo -q line|xargs
split_strings_to_new_line(){
    echo $@|tr ',' '\n'
}
# # FIXME: check and warn for too not found
# deps: imdbtool, jq
imdb(){ IFS=" " imdbtool -t "$1" -r JSON |jq }

# ls and which
lsich() { ls -la `which -a $1`}

#grep environment variable
envgrep(){
    env|grep -i "$1"
}

# tranfer files with ease:
# kudos: https://github.com/dutchcoders/transfer.sh/
transferX() {
    # write to output to tmpfile because of progress bar
    tmpfile=$( mktemp -t transferXXX )
    curl --progress-bar --upload-file $1 https://transfer.sh/$(basename $1) >> $tmpfile;
    cat $tmpfile;
    rm -f $tmpfile;
}

# http://www.picpaste.com/ :Put your pictures online, easy and quick
# Storage time: 30mins(1) to unlimited(9)
# Supported formats: Only JP(E)G, PNG, GIF, BMP
# Size limit =< 7 megabyte 
picpaste () {
    opts=( -F storetime={9:-$2} -F addprivacy=1 -F rules=yes )
    link=http://www.picpaste.com/upload.php
    curl -sA firefksjkdjfkjaskdjfkjsdfox "${opts[@]}" -F upload=@"$1" "$link" \
        | sed -n '/Picture URL/{n;s/.*">//;s/<.*//p}'
}

# watch_prog
watch_prog (){
    watch -n 0.02 -d "$@"
}

# get mongo hacker
get_mongo_hacker(){
    OPT_HOME=/opt/`\whoami`
    OPTDIR=${OPT_HOME}/mongodb/mongo-hacker && sudo mkdir -p $OPTDIR && sudo chown -Rv `whoami` $OPTDIR
    git clone --depth=1 https://github.com/TylerBrock/mongo-hacker.git ${OPTDIR} || echo "everything is in place"
    (cd ${OPTDIR} && pwd && make && make install)
}


# # FIXME: i think this doesn't work
# get youtube urls; bad style
get_youtube_urls(){
    sed  's#.*\(https*://.*v=[a-zA-Z0-9_-]*\).*#\1#g' "$@"
}

# # FIXME: too lazy for now
# find raspberrypi in network
find_pi(){
    get_range_first=${1:-`ip a  show wlan0|awk '/inet/{print$2}'|head -1`}
    sudo nmap -sP "${get_range_first}" | awk '/^Nmap/{ip=$NF}/B8:27:EB/{print ip}'
}

# nmap in hacker look
alias nmap_hachers_way='nmap -oS - -sP'

# public_ip
public_ip(){
    curl -sS https://jsonip.com| jq .ip
}

# package sharing, entrie installation
tarball_pkg(){
    TMPDIR=$(mktemp -d)
    TMP=/tmp
    PKG_NAME=${1:-openssl}
    for i in $(pacman -Ql $PKG_NAME|awk '{print $2}'|xargs); do
        [ -d $i ] && mkdir -p $TMPDIR/$i || cp -pr $i $TMPDIR/$i;
    done
    tar -cf $TMP/$PKG_NAME.tar.gz $TMPDIR &&  rm -rf $TMPDIR
    echo $Green tarball ready: $TMP/$PKG_NAME.tar.gz $Color_Off
}


# get your ISP
get_my_isp_name(){
    echo "$Green work in progress $Color_Off"
    curl -sA $FIREFOX_A http://whatismyipaddress.com/ | awk -F'>' '/ISP:/{print$5}'
}

# tcpdump verbose output
# help_url: https://serverfault.com/a/246877/206277
dump_tcp_headers(){
    sudo tcpdump -n -S -s 0 -A 'tcp dst port 80'
}

# decode base64
base64_d(){
    echo -e "$@"|base64 -d
}
    
# reviselater, only work with bash
# https://superuser.com/a/229038/361714
whereis_func(){
    shopt -s extdebug
    declare -F "$@"
    shopt -u extdebug
}

QRCODE=/tmp/qrcode
txt_2_qrcode_gen(){

    txt_2_encode="$@"
    qrencode "$txt_2_encode" -o $QRCODE &&  xcowsay -d  $QRCODE
}

txt_2_qrcode(){
    txt_2_qrcode_gen "$@" && rm $QRCODE
}

# directory with date name
mkdir_with_date(){
    export DUMP_DATE=$(date +%Y%m%d-%H_%M_%S)
    mkdir -pv $1_$DUMP_DATE
}

get_binary(){
    #loop in input : https://stackoverflow.com/a/29906163
    while read char; do
	a=$(LC_CTYPE=C printf '%d' "'$char"); echo "$char: $(echo "obase=2;$a" | bc)"
    done < <(fold -w1 <<<"$@")
}

get_binary_one_line(){
    # sth like echo -n hello | xxd -b
    echo "$(get_binary $@ | awk 'BEGIN{ORS=" "};{print $2}') $@"
}

#get back webacm
turn_on_cam(){
    sudo modprobe uvcvideo
}
test_webcam(){
    mplayer tv:// -tv driver=v4l2:device=/dev/video0:width=1280:height=720:fps=30:outfmt=yuy2
}
