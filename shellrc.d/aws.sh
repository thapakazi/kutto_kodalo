
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

###############################################
## SSM / Paramater Store | Helper Utilsities ##
###############################################
aws_ssm_get_param_raw(){
    app=$1
    env=${2:-'development'}
    suffix=${3:-'env'}
    aws ssm get-parameter --region $AWS_REGION --with-decryption  \
        --name "/${env}/${app}/${suffix}" \
        --query  "Parameter.Value"
}

aws_ssm_get_param(){
    : ${1?"Usage: $0 appname environment{development,staging} secret_type{env,config/appsettings.json} "}
    aws_ssm_get_param_raw "$@" | jq -r
}

aws_ssm_put_param(){
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

aws_ssm_new_ssm(){
    : ${1?"Usage: $0 appname environment{development,staging} secret_type{env,config/appsettings.json} "}
    aws_ssm_put_param  "$@"
}
# edit ssm paramater store
aws_ssm_edit_param(){
    : ${1?"Usage: $0 appname environment{development,staging} secret_type{env,config/appsettings.json} "}
    env=${2:-'development'}
    app=$1
    suffix=${3:-'env'}
    tmp_file=$(mktemp -u)-${app}_${env}.$(date +%F-%R).json
    aws_ssm_get_param $app $env $suffix |tee $tmp_file
    vim $tmp_file
    values=$(cat $tmp_file|jq -c) && aws_ssm_put_param $app $env $suffix $values
}

# assuming you follow convention
# parameter store name: /env/app/env or /env/app/config/...
aws_ssm_get_all_params(){
    aws ssm describe-parameters | jq '.Parameters[].Name' -r
}

aws_ssm_get_param_easy(){
    aws_ssm_get_param $(echo $1 | cut -d/ -f3) $(echo $1 | cut -d/ -f2) $(echo $1 | cut -d/ -f4-)
}

aws_ssm_edit_param_easy(){
    aws_ssm_edit_param $(echo $1 | cut -d/ -f3) $(echo $1 | cut -d/ -f2) $(echo $1 | cut -d/ -f4-)
}

# Disclaimer: you been warned, very very fragile/hariy function, don't use it on yours
# selfnote: make sure you export respective AWS profiles first
aws_ssm_copy_param(){
    source=$1
    dest=$2
    export AWS_PROFILE=$SOURCE_PROFILE; aws_ssm_get_param_easy $source | buffer
    export AWS_PROFILE=$DEST_PROFILE; aws_ssm_edit_param_easy $dest
}

##################################

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
