# ansible cheeses
# # FIXME: if _ansible_ssh_port is blank put it 22
[ -z $_ansible_ssh_port ] && export _ansible_ssh_port=22
export ANSIBLE_SSH_PORT="${_ansible_ssh_port}" # it comes from somewhere else
export ANSIBLE_SSH_ARGS="-o ForwardAgent=yes -o StrictHostKeyChecking=no -o Port=${ANSIBLE_SSH_PORT}"

# cows are awesome
#export ANSIBLE_NOCOWS=1

# ansible pyton fix
# ansible-playbook() {
# 	  /usr/bin/env ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python2' "$@"
# }

# new easy-way
# it could break; BEAWARE
PYTHON_2=`which python2`
export ANSIBLE_PYTHON_INTERPRETER=${PYTHON_2}

# if above don't work 
# alias ansible-playbook="/usr/bin/env ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python2'"

# assuming there exists ~/.localhost inventory
export ANSIBLE_LOCAL_FLAGS='-c local -i ~/.localhost'

## archive museum samples
## just putting them in limbo for the respect
# before the days of ansible-galaxy :P
# ansible_new_role () {
#     if test -d roles; then
#         mkdir -p roles/$1/{tasks,handlers,files} && touch roles/$1/{tasks,handlers}/main.yml;
#     else
#         echo "Are you inside the ansible codebase ??"
#     fi
# }
# add_new_app_yml(){ APPNAME=$1; touch $APPNAME.yml group_vars/vars/$APPNAME.yml && edit $APPNAME.yml group_vars/vars/$APPNAME.yml }
# in old days
# start_staging() {
#     source ~/.shellrc.d/ansible.exports
#     cd /automation/staging_up
#     gco master && source /random/aws-secrets && ansible-playbook fleet.yml && gco -
# }
