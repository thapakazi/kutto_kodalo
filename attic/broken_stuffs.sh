# FIXME: almosting everythings here are broken or mightnot work
#host gist html and get url
rawgist_to_html(){
    ORGINAL=gist.githubusercontent.com
    CHANGE_TO=rawgit.com
    echo "$@" | sed "s/$ORGINAL/$CHANGE_TO/" | xclip -sel c
    #$(gist -Pp -f "$1" -d "${2:-auto_generated_title_string_from_rawgit_to_html}")
}

# FIXME: broken
# gist always confusing with -p and -P
gistbuf(){
    if [ -z "${1}" -o -z "${2}"]; then
        # FIXME:
        echo "Usage: \`gistbuf filename.extension description\`";
        return 1;
    fi
    gist -P -f ${1} -d ${2}
}

DIR_ALIAS=$HOME/.shellrc.d/dir.alias
listda(){
    # cut -d= -f1 $HOME/.shellrc.d/dir.alias
    cat $DIR_ALIAS
}

add_dir.(){
    current_path=`basename $PWD`
    echo "`tr '[:lower:]' '[:upper:]' <<< $current_path`=${2-$PWD}" >> $DIR_ALIAS
    source $DIR_ALIAS
    listda
}

add_dir(){
    current_path=`basename $PWD`
    echo "`tr '[:lower:]' '[:upper:]' <<< $1`=${2-$PWD}" >> $DIR_ALIAS
    source $DIR_ALIAS
    list_dir_alias
}



# FIXME: if you find a time
#missing alias:
# textify(){
#     william.hoza.us.sh "$@"
# }

# # custom_alias
# free_sms(){
#     free-sms.py
# }
