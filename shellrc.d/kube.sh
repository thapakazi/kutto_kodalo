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


# debug pod
haribahadur_launch_debug_pod(){
    kubectl run -i --tty --rm debug --image=${1:-'ubuntu'} -n=${2:-'default'} --restart=Never -- sh
}

# krew from https://krew.sigs.k8s.io/docs/user-guide/setup/install/#bash
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# k get nodes 
k_get_nodes(){
    kubectl get nodes -o=json | jq -r '.items[] | {name: .metadata.name, ami_id: .metadata.labels."karpenter.k8s.aws/instance-ami-id", instance_type: .metadata.labels."beta.kubernetes.io/instance-type"} | select(.ami_id and .instance_type) | "\(.name) \(.ami_id) \(.instance_type)'
}
