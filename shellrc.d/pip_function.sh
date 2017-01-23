# dirty env vars
export PYTHONUSERBASE=$HOME/.pip
mkdir -p $PYTHONUSERBASE

# pip install to default userbase
pip() {
    _ifinstalling=$1
    if [ "$_ifinstalling" = "install" ]; then
        if [ -z "${PYTHONUSERBASE+x}" ]; then
            echo "PYTHONUSERBASE is not set "
            pip "$@"
        else
            echo "PYTHONUSERBASE is set to ${PYTHONUSERBASE}"
            pip "$@" --user
        fi
    fi
}

# pip autocomplete
shellrcd_gendir=$HOME/.shellrc.d/generated && mkdir -p "${shellrcd_gendir}"
autocomplete_file=${shellrcd_gendir}/pip_autocomplete.sh
[ ! -s "$autocomplete_file" ] \
    || [ ! -f "$autocomplete_file" ]  \
    && /usr/bin/pip completion --"$(echo ${SHELL##*/})"  > $autocomplete_file

