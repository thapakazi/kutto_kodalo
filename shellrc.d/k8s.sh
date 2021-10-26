k8s_get_pods(){
    kubectl get pod -l ${1} -n $2 --no-headers=true | awk '{print $1}'|xargs
}

k8s_print_connections(){
    TMPDIR=/tmp/k8s_XXX
    mkdir -p $TMPDIR
    namespace=${NAMESPACE:-'production'}
    label="${LABEL:-'service=xyz'}"
    for p in $(k8s_get_pods $label $namespace); do
        echo ----------------------
        kubectl -n $namespace exec pod/$p netstat | grep "$@" |tee $TMPDIR/$p
        echo "$p $(wc -l $TMPDIR/$p)"
    done
}

k8s_print_eviced_pod_summary(){
    TMPDIR=/tmp/k8s_evicted_XXX
    mkdir -p $TMPDIR
    echo 'searching for evicted pods...'
    kubectl get pods -A|awk '/Evicted/{print $1, $2}' | tee $TMPDIR/evicted
    echo '---------getting-resons-for-eviction-------------'
    cat $TMPDIR/evicted | xargs -n 2 sh -c 'echo -n $2: && kubectl describe -n $1 po/$2|grep -i message:' line
    echo '---------cleaning-up-------------'
    cat $TMPDIR/evicted | xargs -n 2 sh -c 'echo -n $2: && kubectl delete -n $1 po/$2' line
}
