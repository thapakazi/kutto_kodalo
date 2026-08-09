# @module aws
# @summary AWS helpers: caller identity, EC2/region inspection, SSM Parameter
#          Store CRUD, IAM bootstrap, and Session Manager shells.
#
# Everything here shells out to the `aws` CLI; the module defines nothing when
# the CLI is absent. A handful of functions additionally need `jq`,
# `ec2-session`, or `ansible` — those are checked at call time so the rest of
# the module stays usable.

require aws || return 0

# ---------------------------------------------------------------- internals --

# Safe indirect expansion. `eval` is used with a *constant* expression (the
# variable name is validated first and never interpolated into the eval string),
# which is what makes this different from the old `eval echo \$$var`.
_aws_var_value() {
    local _name="$1" _val=""
    case "$_name" in
        "" | *[!A-Za-z0-9_]* | [0-9]*) return 1 ;;
    esac
    if [ -n "$ZSH_VERSION" ]; then
        eval '_val=${(P)_name}'
    else
        eval '_val=${!_name}'
    fi
    printf '%s\n' "$_val"
}

# Fail loudly when a required environment variable is empty or unset.
_aws_require_env_var() {
    local name="$1" value
    value="$(_aws_var_value "$name")" || {
        log_error "aws: '$name' is not a usable variable name"
        return 1
    }
    if [ -z "$value" ]; then
        log_error "aws: $name is not set"
        return 1
    fi
    return 0
}

# Emit `--region <r>` only when AWS_REGION is actually set, so we never pass an
# empty --region to the CLI.
_aws_region_args() {
    [ -n "${AWS_REGION:-}" ] && printf -- '--region %s' "$AWS_REGION"
    return 0
}

# Path of the cached `ec2-session --list` output for the active profile. Lives
# under SHELLRC_CACHE (exported by the loader), never in a predictable /tmp path.
_aws_ssm_instance_cache() {
    printf '%s/aws-instances-%s\n' \
        "${SHELLRC_CACHE:-$HOME/.cache/shellrc}" "${AWS_PROFILE:-default}"
}

# Split a `/env/app/suffix...` parameter path into "app env suffix".
_aws_ssm_split_path() {
    local param_path="$1" env app suffix
    env="$(printf '%s\n' "$param_path" | cut -d/ -f2)"
    app="$(printf '%s\n' "$param_path" | cut -d/ -f3)"
    suffix="$(printf '%s\n' "$param_path" | cut -d/ -f4-)"
    if [ -z "$env" ] || [ -z "$app" ] || [ -z "$suffix" ]; then
        log_error "aws: not a /environment/app/suffix parameter path: $param_path"
        return 1
    fi
    printf '%s\n%s\n%s\n' "$app" "$env" "$suffix"
}

# Split a whitespace-separated flag string into an array. zsh does not word-split
# unquoted parameters, so the two shells need different syntax.
_aws_split_flags() {
    # Callers declare `flags` local; dynamic scoping makes this assignment land
    # in the caller (true in both bash and zsh).
    flags=()
    [ -n "${1:-}" ] || return 0
    if [ -n "$ZSH_VERSION" ]; then
        eval 'flags=(${=1})'
    else
        eval 'flags=($1)'
    fi
    return 0
}

# ---------------------------------------------------------------- identity ---

# @describe Print the IAM identity the current credentials resolve to.
# @usage    aws_whoami
# @example  aws_whoami
# @requires aws
# @os       any
aws_whoami() {
    aws sts get-caller-identity "$@"
}

# @describe List every AWS region, including regions this account has not opted
#           into.
# @usage    aws_list_regions
# @example  aws_list_regions | sort
# @requires aws
# @os       any
aws_list_regions() {
    aws ec2 describe-regions \
        --all-regions \
        --query "Regions[].{Name:RegionName}" \
        --output text
}

# @describe List the availability zones of the region in AWS_REGION.
# @usage    aws_list_azs
# @example  AWS_REGION=us-east-1 aws_list_azs
# @requires aws
# @os       any
aws_list_azs() {
    aws ec2 describe-availability-zones \
        --all-availability-zones \
        --query "AvailabilityZones[].{Name:ZoneName}" \
        --output text
}

# ------------------------------------------------------------------- ec2 -----

# @describe Search for EC2 AMIs through Ansible's ec2_ami_find module. Extra
#           ansible flags come from ANSIBLE_LOCAL_FLAGS.
# @usage    aws_ec2_find_ami [ansible-module-args]
# @example  aws_ec2_find_ami 'name=*ubuntu-22.04*'
# @requires ansible
# @os       any
aws_ec2_find_ami() {
    local args="${1:-name=*vpc*}"
    local flags
    has ansible || { log_error "aws_ec2_find_ami needs ansible on PATH"; return 1; }
    _aws_split_flags "${ANSIBLE_LOCAL_FLAGS:-}"
    ansible localhost "${flags[@]}" -m ec2_ami_find -a "$args"
}

# @describe Diff two versions of an EC2 launch template. Version indexes are
#           offsets into the API response, newest first: 0 is latest, 1 the one
#           before it.
# @usage    aws_ec2_diff_launch_template_versions <launch-template-id> [older-index] [newer-index]
# @example  aws_ec2_diff_launch_template_versions lt-0123456789abcdef0 1 0
# @requires aws jq
# @os       any
aws_ec2_diff_launch_template_versions() {
    local lt_id="$1" older="${2:-1}" newer="${3:-0}" tmp rc=0
    [ -n "$lt_id" ] || {
        log_error "usage: aws_ec2_diff_launch_template_versions <lt-id> [older-index] [newer-index]"
        return 1
    }
    require jq || { log_error "aws_ec2_diff_launch_template_versions needs jq"; return 1; }

    log_info "using AWS_PROFILE=${AWS_PROFILE:-<unset>} AWS_REGION=${AWS_REGION:-<unset>}"
    tmp="$(tmp_file "lt-$lt_id")" || return 1
    trap 'rm -f "$tmp"' EXIT INT TERM HUP

    if aws ec2 describe-launch-template-versions --launch-template-id "$lt_id" > "$tmp"; then
        diff <(jq ".LaunchTemplateVersions[$older]" "$tmp") \
             <(jq ".LaunchTemplateVersions[$newer]" "$tmp")
        rc=$?
    else
        rc=1
    fi

    rm -f "$tmp"
    trap - EXIT INT TERM HUP
    return "$rc"
}

# ------------------------------------------------------- ssm parameter store -

# Fetch the raw (JSON-quoted) parameter value.
_aws_ssm_get_param_raw() {
    local app="$1" env="${2:-development}" suffix="${3:-env}"
    local flags
    _aws_split_flags "$(_aws_region_args)"
    aws "${flags[@]}" ssm get-parameter \
        --with-decryption \
        --name "/${env}/${app}/${suffix}" \
        --query "Parameter.Value" \
        --output json
}

# @describe Print a decrypted SSM parameter stored under /<env>/<app>/<suffix>.
# @usage    aws_ssm_get_param <app> [environment] [suffix]
# @complete environment:(development staging production) suffix:(env config/appsettings.json)
# @example  aws_ssm_get_param billing production env
# @example  aws_ssm_get_param billing staging config/appsettings.json
# @requires aws jq
# @os       any
aws_ssm_get_param() {
    local app="$1"
    [ -n "$app" ] || {
        log_error "usage: aws_ssm_get_param <app> [environment] [suffix]"
        return 1
    }
    require jq || { log_error "aws_ssm_get_param needs jq"; return 1; }
    _aws_ssm_get_param_raw "$@" | jq -r
}

# @describe Print a decrypted SSM parameter addressed by its full path.
# @usage    aws_ssm_get_param_by_path </environment/app/suffix>
# @example  aws_ssm_get_param_by_path /production/billing/env
# @requires aws jq
# @os       any
aws_ssm_get_param_by_path() {
    local param_path="$1" app env suffix parts
    [ -n "$param_path" ] || { log_error "usage: aws_ssm_get_param_by_path </env/app/suffix>"; return 1; }
    parts="$(_aws_ssm_split_path "$param_path")" || return 1
    app="$(printf '%s\n' "$parts" | sed -n 1p)"
    env="$(printf '%s\n' "$parts" | sed -n 2p)"
    suffix="$(printf '%s\n' "$parts" | sed -n 3p)"
    aws_ssm_get_param "$app" "$env" "$suffix"
}

# @describe Write a SecureString parameter to /<env>/<app>/<suffix>, overwriting
#           any existing value.
# @usage    aws_ssm_put_param <app> <environment> <suffix> <value>
# @complete environment:(development staging production) suffix:(env config/appsettings.json)
# @example  aws_ssm_put_param billing staging env "$(cat .env)"
# @requires aws
# @danger   Overwrites the parameter in place; the previous value is only
#           recoverable through parameter history.
# @os       any
aws_ssm_put_param() {
    local app="$1" env="${2:-development}" suffix="${3:-env}" value="$4"
    local flags
    [ -n "$app" ] || {
        log_error "usage: aws_ssm_put_param <app> <environment> <suffix> <value>"
        return 1
    }
    [ -n "$value" ] || { log_error "aws_ssm_put_param: refusing to write an empty value"; return 1; }
    _aws_split_flags "$(_aws_region_args)"
    aws "${flags[@]}" ssm put-parameter \
        --overwrite \
        --name "/${env}/${app}/${suffix}" \
        --value "$value" \
        --type "SecureString"
}

# @describe Write a SecureString parameter addressed by its full path.
# @usage    aws_ssm_put_param_by_path </environment/app/suffix> <value>
# @example  aws_ssm_put_param_by_path /staging/billing/env "$(cat .env)"
# @requires aws
# @danger   Overwrites the parameter in place.
# @os       any
aws_ssm_put_param_by_path() {
    local param_path="$1" value="$2" app env suffix parts
    [ -n "$param_path" ] || { log_error "usage: aws_ssm_put_param_by_path </env/app/suffix> <value>"; return 1; }
    parts="$(_aws_ssm_split_path "$param_path")" || return 1
    app="$(printf '%s\n' "$parts" | sed -n 1p)"
    env="$(printf '%s\n' "$parts" | sed -n 2p)"
    suffix="$(printf '%s\n' "$parts" | sed -n 3p)"
    aws_ssm_put_param "$app" "$env" "$suffix" "$value"
}

# @describe Fetch a parameter into a private temp file, open it in $EDITOR, then
#           write the edited content back. The plaintext file is created with
#           mode 600 and removed on return, on error, and on interrupt.
# @usage    aws_ssm_edit_param <app> [environment] [suffix]
# @complete environment:(development staging production) suffix:(env config/appsettings.json)
# @example  aws_ssm_edit_param billing production env
# @requires aws jq
# @danger   Materialises a decrypted SecureString on local disk for the duration
#           of the edit, and overwrites the stored parameter on save.
# @os       any
aws_ssm_edit_param() {
    local app="$1" env="${2:-development}" suffix="${3:-env}"
    local tmp value rc=0
    [ -n "$app" ] || {
        log_error "usage: aws_ssm_edit_param <app> [environment] [suffix]"
        return 1
    }
    require jq || { log_error "aws_ssm_edit_param needs jq"; return 1; }

    tmp="$(tmp_file "ssm-${env}-${app}")" || return 1
    chmod 600 "$tmp" 2>/dev/null
    trap 'rm -f "$tmp"' EXIT INT TERM HUP

    if aws_ssm_get_param "$app" "$env" "$suffix" > "$tmp"; then
        "${EDITOR:-vi}" "$tmp"
        if jq -e . "$tmp" >/dev/null 2>&1; then
            value="$(jq -c . "$tmp")"
        else
            value="$(cat "$tmp")"
        fi
        if [ -n "$value" ]; then
            aws_ssm_put_param "$app" "$env" "$suffix" "$value" || rc=1
        else
            log_warn "aws_ssm_edit_param: empty buffer, nothing written"
            rc=1
        fi
    else
        rc=1
    fi

    value=""
    rm -f "$tmp"
    trap - EXIT INT TERM HUP
    return "$rc"
}

# @describe Edit a parameter addressed by its full path.
# @usage    aws_ssm_edit_param_by_path </environment/app/suffix>
# @example  aws_ssm_edit_param_by_path /production/billing/env
# @requires aws jq
# @danger   See aws_ssm_edit_param.
# @see      aws_ssm_edit_param
# @os       any
aws_ssm_edit_param_by_path() {
    local param_path="$1" app env suffix parts
    [ -n "$param_path" ] || { log_error "usage: aws_ssm_edit_param_by_path </env/app/suffix>"; return 1; }
    parts="$(_aws_ssm_split_path "$param_path")" || return 1
    app="$(printf '%s\n' "$parts" | sed -n 1p)"
    env="$(printf '%s\n' "$parts" | sed -n 2p)"
    suffix="$(printf '%s\n' "$parts" | sed -n 3p)"
    aws_ssm_edit_param "$app" "$env" "$suffix"
}

# @describe List every SSM parameter name visible to the current credentials.
# @usage    aws_ssm_list_params
# @example  aws_ssm_list_params | grep production
# @requires aws jq
# @os       any
aws_ssm_list_params() {
    require jq || { log_error "aws_ssm_list_params needs jq"; return 1; }
    aws ssm describe-parameters | jq -r '.Parameters[].Name'
}

# @describe Copy one decrypted SecureString from a source account to a
#           destination account. The value is passed in memory from the read to
#           the write; it never touches the clipboard or disk.
# @usage    aws_ssm_copy_param <source-path> <dest-path> [source-profile] [dest-profile]
# @example  aws_ssm_copy_param /production/billing/env /staging/billing/env prod-ro staging-rw
# @requires aws jq
# @danger   Moves a decrypted secret between AWS accounts and overwrites the
#           destination parameter. Profiles default to $SOURCE_PROFILE and
#           $DEST_PROFILE. Double-check both before confirming.
# @see      aws_ssm_get_param_by_path aws_ssm_put_param_by_path
# @os       any
aws_ssm_copy_param() {
    local source_path="$1" dest_path="$2"
    local src_profile="${3:-${SOURCE_PROFILE:-}}" dst_profile="${4:-${DEST_PROFILE:-}}"
    local saved_profile="${AWS_PROFILE:-}" value rc=0

    [ -n "$source_path" ] && [ -n "$dest_path" ] || {
        log_error "usage: aws_ssm_copy_param <source-path> <dest-path> [source-profile] [dest-profile]"
        return 1
    }
    [ -n "$src_profile" ] || { log_error "aws_ssm_copy_param: no source profile (arg 3 or \$SOURCE_PROFILE)"; return 1; }
    [ -n "$dst_profile" ] || { log_error "aws_ssm_copy_param: no dest profile (arg 4 or \$DEST_PROFILE)"; return 1; }

    log_warn "About to copy a DECRYPTED SecureString between accounts."
    confirm "Copy $source_path ($src_profile) -> $dest_path ($dst_profile)?" || return 0

    export AWS_PROFILE="$src_profile"
    value="$(aws_ssm_get_param_by_path "$source_path")" || rc=1

    if [ "$rc" -eq 0 ] && [ -n "$value" ]; then
        export AWS_PROFILE="$dst_profile"
        aws_ssm_put_param_by_path "$dest_path" "$value" || rc=1
    else
        log_error "aws_ssm_copy_param: source parameter was empty or unreadable"
        rc=1
    fi

    value=""
    if [ -n "$saved_profile" ]; then
        export AWS_PROFILE="$saved_profile"
    else
        unset AWS_PROFILE
    fi
    return "$rc"
}

# @describe Read a KEY=VALUE file and write each line to SSM as a SecureString
#           under a shared prefix. Blank lines and # comments are skipped.
# @usage    aws_ssm_put_env_file <env-file> [prefix]
# @example  aws_ssm_put_env_file .env.production /production/billing/
# @requires aws
# @danger   Writes every line of the file into Parameter Store.
# @os       any
aws_ssm_put_env_file() {
    local file="$1" prefix="${2:-/service-prefix/}" line key value
    [ -n "$file" ] || { log_error "usage: aws_ssm_put_env_file <env-file> [prefix]"; return 1; }
    [ -f "$file" ] || { log_error "aws_ssm_put_env_file: no such file: $file"; return 1; }

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            "" | \#*) continue ;;
            *=*) : ;;
            *) log_warn "skipping line without '=': $line"; continue ;;
        esac
        key="${line%%=*}"
        value="${line#*=}"
        [ -n "$key" ] || continue
        aws ssm put-parameter \
            --name "${prefix}${key}" \
            --value "$value" \
            --type SecureString </dev/null || return 1
    done < "$file"
}

# @describe Print the two put-parameter invocations worth remembering.
# @usage    aws_ssm_show_examples
# @example  aws_ssm_show_examples
# @os       any
aws_ssm_show_examples() {
    printf '%s\n' \
        '# create a new ssm parameter' \
        'aws ssm put-parameter --name /service-prefix/ENV_VAR1 --value example --type SecureString' \
        '' \
        '# read it back, decrypted' \
        'aws ssm get-parameter --with-decryption --name /service-prefix/ENV_VAR1 --query Parameter.Value'
}

# ------------------------------------------------------- ssm session manager -

# @describe Refresh the cached EC2 instance list for the active AWS_PROFILE.
#           The cache backs both aws_ssm_start_session and its zsh completion.
# @usage    aws_ssm_list_instances
# @example  AWS_PROFILE=prod aws_ssm_list_instances
# @requires aws ec2-session
# @see      aws_ssm_start_session
# @os       any
aws_ssm_list_instances() {
    local cache dir
    _aws_require_env_var AWS_PROFILE || return 1
    has ec2-session || { log_error "aws_ssm_list_instances needs ec2-session on PATH"; return 1; }

    cache="$(_aws_ssm_instance_cache)"
    dir="$(dirname -- "$cache")"
    [ -d "$dir" ] || mkdir -p "$dir" || return 1

    ec2-session --list > "$cache" || {
        log_error "aws_ssm_list_instances: ec2-session --list failed"
        return 1
    }
    cat "$cache"
}

# @describe Open an SSM Session Manager shell on the first cached instance whose
#           line matches the given substring. Refreshes the cache when missing.
# @usage    aws_ssm_start_session <name-fragment> [ssh-user]
# @complete ssh-user:(ubuntu ec2-user admin root)
# @example  aws_ssm_start_session prod-worker
# @example  aws_ssm_start_session prod-app ec2-user
# @requires aws ec2-session
# @see      aws_ssm_list_instances
# @os       any
aws_ssm_start_session() {
    local name="$1" user="${2:-ubuntu}" cache instance
    [ -n "$name" ] || { log_error "usage: aws_ssm_start_session <name-fragment> [ssh-user]"; return 1; }
    _aws_require_env_var AWS_PROFILE || return 1
    has ec2-session || { log_error "aws_ssm_start_session needs ec2-session on PATH"; return 1; }

    cache="$(_aws_ssm_instance_cache)"
    if [ ! -r "$cache" ]; then
        log_warn "no instance cache for $AWS_PROFILE, refreshing"
        aws_ssm_list_instances >/dev/null || return 1
    fi

    instance="$(awk -v pat="$name" 'index($0, pat) { print $1; exit }' "$cache")"
    [ -n "$instance" ] || {
        log_error "no instance matching '$name' in $cache (try aws_ssm_list_instances)"
        return 1
    }

    log_info "Starting SSM session to $name ($instance) as $user"
    ec2-session "$instance" -u "$user"
}

# -------------------------------------------------------------------- iam ----

# @describe List IAM users whose description matches a pattern.
# @usage    aws_iam_find_user_by_key <pattern>
# @example  aws_iam_find_user_by_key AKIAEXAMPLE
# @requires aws
# @os       any
aws_iam_find_user_by_key() {
    local pattern="$1"
    [ -n "$pattern" ] || { log_error "usage: aws_iam_find_user_by_key <pattern>"; return 1; }
    aws --output text iam list-users | grep -- "$pattern"
}

# @describe Create an IAM user.
# @usage    aws_iam_create_user <username>
# @example  aws_iam_create_user uploads-ci
# @requires aws
# @os       any
aws_iam_create_user() {
    local username="$1"
    [ -n "$username" ] || { log_error "usage: aws_iam_create_user <username>"; return 1; }
    aws iam create-user --user-name "$username"
}

# @describe Print a minimal s3:PutObject policy document for a bucket to stdout.
#           Nothing is written to disk — redirect it yourself if you want a file.
# @usage    aws_iam_print_bucket_policy <bucket>
# @example  aws_iam_print_bucket_policy my-uploads > policy.json
# @os       any
aws_iam_print_bucket_policy() {
    local bucket="$1"
    [ -n "$bucket" ] || { log_error "usage: aws_iam_print_bucket_policy <bucket>"; return 1; }
    cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PermissionToPutObject",
            "Effect": "Allow",
            "Action": ["s3:PutObject"],
            "Resource": [
               "arn:aws:s3:::${bucket}/*"
            ]
        }
    ]
}
EOF
}

# @describe Create a managed IAM policy from a local policy document.
# @usage    aws_iam_create_policy_from_file <policy-name> <policy-file>
# @example  aws_iam_create_policy_from_file uploads-put ./policy.json
# @requires aws
# @os       any
aws_iam_create_policy_from_file() {
    local policy_name="$1" policy_file="$2"
    [ -n "$policy_name" ] && [ -n "$policy_file" ] || {
        log_error "usage: aws_iam_create_policy_from_file <policy-name> <policy-file>"
        return 1
    }
    [ -f "$policy_file" ] || { log_error "no such policy file: $policy_file"; return 1; }
    aws iam create-policy --policy-name "$policy_name" --policy-document "file://$policy_file"
}

# @describe Attach a managed policy to an IAM user.
# @usage    aws_iam_attach_policy <username> <policy-arn>
# @example  aws_iam_attach_policy uploads-ci arn:aws:iam::123456789012:policy/uploads-put
# @requires aws
# @os       any
aws_iam_attach_policy() {
    local username="$1" policy_arn="$2"
    [ -n "$username" ] && [ -n "$policy_arn" ] || {
        log_error "usage: aws_iam_attach_policy <username> <policy-arn>"
        return 1
    }
    aws iam attach-user-policy --user-name "$username" --policy-arn "$policy_arn"
}

# @describe Create an IAM user plus a bucket-scoped PutObject policy, giving you
#           a chance to edit the policy in $EDITOR before it is created. The
#           policy document lives in a private temp file that is removed on
#           return.
# @usage    aws_iam_create_bucket_writer <username> <bucket> <policy-name>
# @example  aws_iam_create_bucket_writer uploads-ci my-uploads uploads-put
# @requires aws
# @danger   Creates real IAM principals. The attach step is printed, not run.
# @see      aws_iam_attach_policy
# @os       any
aws_iam_create_bucket_writer() {
    local username="$1" bucket="$2" policy_name="$3" tmp rc=0
    [ -n "$username" ] && [ -n "$bucket" ] && [ -n "$policy_name" ] || {
        log_error "usage: aws_iam_create_bucket_writer <username> <bucket> <policy-name>"
        return 1
    }
    confirm "Create IAM user '$username' and policy '$policy_name' for bucket '$bucket'?" || return 0

    tmp="$(tmp_file "iam-${bucket}-policy")" || return 1
    trap 'rm -f "$tmp"' EXIT INT TERM HUP

    aws_iam_create_user "$username" || rc=1
    if [ "$rc" -eq 0 ]; then
        aws_iam_print_bucket_policy "$bucket" > "$tmp" || rc=1
    fi
    if [ "$rc" -eq 0 ]; then
        "${EDITOR:-vi}" "$tmp"
        aws_iam_create_policy_from_file "$policy_name" "$tmp" || rc=1
    fi
    if [ "$rc" -eq 0 ]; then
        log_info "then: aws_iam_attach_policy $username <POLICY_ARN>"
    fi

    rm -f "$tmp"
    trap - EXIT INT TERM HUP
    return "$rc"
}

# ------------------------------------------------------ kubernetes configmaps -
#
# TODO(move): these three are Kubernetes helpers that historically lived in
# shellrc.d/aws.sh. They belong in modules/common/k8s.sh; until that module
# exists they stay here (and are therefore gated on the `aws` guard above).

# @describe Print the data: block of a Kubernetes ConfigMap manifest, stripped of
#           its YAML indentation.
# @usage    k8s_show_configmap_data <manifest>...
# @example  k8s_show_configmap_data configmap.yaml
# @os       any
k8s_show_configmap_data() {
    [ $# -gt 0 ] || { log_error "usage: k8s_show_configmap_data <manifest>..."; return 1; }
    cat "$@" \
        | awk '/^data:$/,/^kind:/ { print }' \
        | sed -e '1d' -e '$d' -e 's/^[ \t]*//'
}

# @describe Convert a ConfigMap data: block into KEY=VALUE lines.
# @usage    k8s_convert_configmap_to_env <manifest>...
# @example  k8s_convert_configmap_to_env configmap.yaml > .env
# @see      k8s_show_configmap_data
# @os       any
k8s_convert_configmap_to_env() {
    k8s_show_configmap_data "$@" | sed -e 's/: /=/'
}

# @describe Convert a ConfigMap data: block into one JSON object per line.
# @usage    k8s_convert_configmap_to_json <manifest>...
# @example  k8s_convert_configmap_to_json configmap.yaml | jq .
# @requires jq
# @see      k8s_show_configmap_data
# @os       any
k8s_convert_configmap_to_json() {
    require jq || { log_error "k8s_convert_configmap_to_json needs jq"; return 1; }
    k8s_show_configmap_data "$@" \
        | jq -R 'split(" ") | {service: .[0], server: .[1], status: .[2]}'
}

# ------------------------------------------------------- back-compat aliases -
# The long names above are the API. These keep old muscle memory working.

alias assm='aws_ssm_start_session'
alias assmli='aws_ssm_list_instances'

alias aws_whomi='aws_whoami'
alias ami_finder='aws_ec2_find_ami'
alias env_to_ssm='aws_ssm_put_env_file'
alias aws_quick_help='aws_ssm_show_examples'
alias aws_ssm_new_ssm='aws_ssm_put_param'
alias aws_ssm_get_all_params='aws_ssm_list_params'
alias aws_ssm_get_param_easy='aws_ssm_get_param_by_path'
alias aws_ssm_edit_param_easy='aws_ssm_edit_param_by_path'
alias aws_get_iam_user_for_key='aws_iam_find_user_by_key'
alias aws_iam_sample_policy='aws_iam_print_bucket_policy'
alias aws_iam_create_user_with_policy='aws_iam_create_bucket_writer'
alias aws_diff_last_two_lt_version='aws_ec2_diff_launch_template_versions'
alias configmap_cleanup='k8s_show_configmap_data'
alias configmap_to_env='k8s_convert_configmap_to_env'
alias configmap_to_json='k8s_convert_configmap_to_json'
