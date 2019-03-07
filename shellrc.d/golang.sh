
# lets use gvm its seems nice like rvm ;)
# export GVM_ROOT=/home/thapakazi/.gvm
# . $GVM_ROOT/scripts/gvm-default
# export GOBIN="${GVM_OVERLAY_PREFIX}/bin"

# go get with verbose
alias gover='go get -v'

# set go version
eval $(gimme 1.12)
export GOPATH=~/go
export PATH=$PATH:$GOPATH/bin
