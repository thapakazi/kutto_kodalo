# #check if var is set
# if [ -z ${var+x} ]; then echo "var is unset"; else echo "var is set to '$var'"; fi

# Tue Apr 11 07:10:11 +0545 2017
# get the path to the script dir
# Eg: http://stackoverflow.com/a/246128
get_script_info(){
    _SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
    _SCRIPT_DIR="$(dirname "$_SCRIPT_PATH")"
}
