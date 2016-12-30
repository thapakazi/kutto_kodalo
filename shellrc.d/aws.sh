
# depends on ansible
# FIXME: check if ansible is installed and warn
function ami_finder(){
    ansible localhost ${ANSIBLE_LOCAL_FLAGS} -m ec2_ami_find -a ${1:-name="*vpc*"}
}
