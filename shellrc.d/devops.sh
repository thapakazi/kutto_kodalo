alias tailf.ngxinx='tail -f /var/log/nginx/*.log'
alias susu='sudo su - '


# some hanging odds
export PATH_TO_PROMETHEUS_DOCS="~/experiments/prometheus/docs"
prometheus_docs(){
    cd ${PATH_TO_PROMETHEUS_DOCS}
    bundle exec nanoc view -p 3001
}
