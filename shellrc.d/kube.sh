# https://github.com/ahmetb/kubectl-aliases
get_kubectl-alias(){
    curl -sL https://raw.githubusercontent.com/ahmetb/kubectl-alias/master/.kubectl_aliases -o ~/.kubectl_aliases 
}
! [ -f ~/.kubectl_aliases ] && get_kubectl-alias
source ~/.kubectl_aliases

# function kubectl() {
#     echo " >> kubectl $@"; command kubectl $@;
# }


# print secrets
kubectl_print_secrets(){
    kubectl get secrets/${1:-'api-secrets'} -n ${2:-'default'} -o yaml \
        | awk '/^data:$/,/^kind:/ {print }' \
        | sed -e '1d' -e '$d' \
        | awk -F: '{printf("\n%s:",$1);system("base64 -d <<<" $2)}'
}


encode_base64(){
  echo -n $@ | base64 -w 0
}


# kube ps: https://github.com/jonmosco/kube-ps1
# grab it from AUR and then
#  looks like little bit too much, but I need it so common these days
source '/opt/kube-ps1/kube-ps1.sh'
PROMPT='$(kube_ps1)'$PROMPT


# debug pod
haribahadur_launch_debug_pod(){
    kubectl run -i --tty --rm debug --image=${1:-'ubuntu'} -n=${2:-'default'} --restart=Never -- sh
}
