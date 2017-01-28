# dirty env vars
export PYTHONUSERBASE=$HOME/.pip
mkdir -p $PYTHONUSERBASE

# pip install to default userbase
mypip() {
    _task_is_to_install=$1
    if [ "$_task_is_to_install" = "install" ]; then
        echo "$BGreen Installing to $PYTHONUSERBASE"
        \pip $@ --user -v
    fi
}

# commenting, it breaks autocompletion on TAB TAB :(
# alias pip=mypip

# pip autocomplete
autocomplete_file=${SHELLRCD_GENDIR}/pip_autocomplete.sh
[ ! -s "$autocomplete_file" ] \
    || [ ! -f "$autocomplete_file" ]  \
    && /usr/bin/pip completion --"$(echo ${SHELL##*/})"  > $autocomplete_file

