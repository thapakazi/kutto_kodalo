
# depends on ansible
# FIXME: check if ansible is installed and warn
function ami_finder(){
    ansible localhost ${ANSIBLE_LOCAL_FLAGS} -m ec2_ami_find -a ${1:-name="*vpc*"}
}

function aws_list_regions(){
    aws ec2 describe-regions \
        --all-regions \
        --query "Regions[].{Name:RegionName}" \
        --output text
}

# this expects AWS_REGION env variable
function aws_list_azs(){
    aws ec2 describe-availability-zones \
        --all-availability-zones \
        --query "AvailabilityZones[].{Name:ZoneName}" \
        --output text
}

function aws_whomi(){
    aws sts get-caller-identity
}

function aws_quick_help(){
    echo "#create new ssm parameter"
    echo "aws ssm put-parameter --name /service-prefix/ENV_VAR1 --value example"
}

