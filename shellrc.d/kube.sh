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

# krew: https://krew.sigs.k8s.io/docs/user-guide/setup/install/
test -d ~/.krew/bin && export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
install_krew (){
    set -x; cd "$(mktemp -d)" &&
        OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
        ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
        KREW="krew-${OS}_${ARCH}" &&
        curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
        tar zxvf "${KREW}.tar.gz" &&
        ./"${KREW}" install krew
}

# k get nodes
k_get_nodes(){
    kubectl get nodes -o=json | jq -r '.items[] | {name: .metadata.name, ami_id: .metadata.labels."karpenter.k8s.aws/instance-ami-id", instance_type: .metadata.labels."beta.kubernetes.io/instance-type"} | select(.ami_id and .instance_type) | "\(.name) \(.ami_id) \(.instance_type)'
}


quick_k8s_spin(){
    kind create cluster --name=${1:-'test-cluster'}
}

quick_k8s_destroy(){
    kind delete cluster --name=${1:-'test-cluster'}
}

give_me_cluster(){
    LC_ALL=C
    local _rand_id=$(tr -dc 'a-z0-9' < /dev/urandom | head -c${1:-6})
    local _cluster_name="kind-$_rand_id"
    echo  _cluster_name > /tmp/.last_cluster
    echo "building cluster: $_cluster_name"
    quick_k8s_spin $_cluster_name
}

give_me_cluster_with_registry(){
    curl -s https://kind.sigs.k8s.io/examples/kind-with-registry.sh| bash
}

take_down_cluster(){
    quick_k8s_destroy `cat /tmp/.last_cluster`
}
