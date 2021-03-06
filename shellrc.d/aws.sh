
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

function env_to_ssm(){
    service_prefix=${2:-'/service-prefix/'}
    while read line; do
        key=$(cut -d'=' -f1) <<< $line
        value=$(cut -d'=' -f2) <<< $line
        aws ssm put-parameter \
            --name $service_prefix$key \
            --value $value \
            --type SecureString
    done < $1
}

function configmap_cleanup(){
    cat $@ | awk '/^data:$/,/^kind:/ {print }' \
        | sed -e '1d' -e '$d' -e 's/^[ \t]*//'
}

function configmap_to_env(){
    configmap_cleanup $@ | sed -e 's/: /=/'
}

function configmap_to_json(){
    configmap_cleanup $@ | jq -R 'split(" ")|{service:.[0], server:.[1], status:.[2]}'
}


# ssm paramater store
aws_get_sm_parm_value(){
    app=$1
    env=${2:-'development'}
    suffix=${3:-'env'}
    aws ssm get-parameters \
        --names "/${env}/${app}/${suffix}" \
        --with-decryption \
        | jq -r .Parameters[].Value
}

aws_put_sm_parm_value(){
    app=$1
    env=${2:-'development'}
    suffix=${3:-'env'}
    value=${4}
    aws ssm put-parameter \
        --overwrite \
        --name "/${env}/${app}/${suffix}" \
        --value $value \
        --type "SecureString"
}

# edit ssm paramater store
aws_edit_sm_value(){

    tmp_file=/tmp/${app}_${env}.json
    env=${2:-'development'}
    app=$1
    suffix=${3:-'env'}
    aws_get_sm_parm_value $app $env $suffix |tee $tmp_file
    vim $tmp_file
    values=$(cat $tmp_file|jq -c)
    aws_put_sm_parm_value $app $env $suffix $values
}

# get iam user for key
aws_get_iam_user_for_key(){
    aws --output text iam list-users |grep $1
    # awk '{print $NF}' | \
        # xargs -P10 -n1 aws --output text iam list-access-keys --user-name | grep $1

}
#######################################
# IAM Section
#######################################
aws_iam_create_user(){
    username=${1}
    aws iam create-user --user-name $username
}

aws_iam_sample_policy(){
   bucket_name=$1
    cat <<EOF > /tmp/${bucket_name}-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PermissionToPutObject",
            "Effect": "Allow",
            "Action": ["s3:PutObject"],
            "Resource": [
               "arn:aws:s3:::${bucket_name}/*"
            ]
        }
    ]
}
EOF
}

aws_iam_create_policy(){
    bucket_name=$1
    policy_name=$2
    aws iam create-policy --policy-name $policy_name --policy-document file:///tmp/${bucket_name}-policy.json
}
aws_iam_attach_policy(){
   aws iam attach-user-policy --user-name $1 --policy-arn $2
}

aws_iam_create_user_with_policy(){
    username=$1
    bucket_name=$2
    policy_name=$3
    aws_iam_create_user $username
    aws_iam_sample_policy $bucket_name
    vim /tmp/${bucket_name}-policy.json
    aws_iam_create_policy $bucket_name $policy_name
    echo aws iam attach-user-policy --user-name $1 --policy-arn POLICY_ARN
}
