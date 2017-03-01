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
public_key(){xclip -sel c < ~/.ssh/id_rsa.pub}

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
buffer(){xclip -sel c}
buffercopy(){buffer < $1}

alias curl.json='curl -i -H "Accept: application/json"'

# not sure how much relavent is it ?
alias startx='ssh-add startx'

#random password of desired length
randpassd(){ < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-16};echo;}
randpass(){randpassd ${1:-16}|xclip -sel c}

#mimicing .split(",") #quick_hack
split_string(){echo $1|sed 's/ /","/g'|awk '{print "[\"" $0 "\"]"}'}

# # FIXME: check and warn for too not found
# deps: imdbtool, jq
imdb(){ IFS=" " imdbtool -t "$1" -r JSON |jq }

# ls and which
lsich() { ls -la `which -a $1`}

#grep environment variable
envgrep(){env|grep -i "$1"}

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
public_ip(){curl -sS https://jsonip.com| jq .ip}
