# useless stuffs

#desc:
#  params:
#    first: reveal version to download like:
#           3.3.0 which is default for this day 26 Aug 2016
#  result: it will download reveal version to /tmp
#    
function check_for_reveal.js_updates(){
    REVEAL_VERSION=${1:-3.3.0}
    REVEALJS_DOWNLOAD_URL="https://github.com/hakimel/reveal.js/archive/$REVEAL_VERSION.tar.gz"
    DOWNLOAD_DIR="/tmp"
    wget -qO- ${REVEALJS_DOWNLOAD_URL} \
        | tar --transform 's/^reveal.js[-0-9.]*/reveal.js/' -xvz -C $DOWNLOAD_DIR
}
