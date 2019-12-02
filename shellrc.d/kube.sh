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
    kubectl get secrets/${1:-'api-secrets'} -o yaml \
        | awk '/^data:$/,/^kind:/ {print }' \
        | sed -e '1d' -e '$d' \
        | awk -F: '{printf("\n%s:",$1);system("base64 -d <<<" $2)}'
}


encode_base64(){
  echo -n $@ | base64 -w 0
}
