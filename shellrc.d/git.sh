#git log like a boss
# found somewhere in stackoverflow reply
alias git_log="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"


# TODO: fix this shit next year
git_count_commits(){
    git rev-list \
        --author="${1:-thapakazi}" \
        --count  \
        --since="Jan 1 2020"  \
        --before="Dec 31 2020" \
        --all --no-merges
}

git_commits_on_projects(){
    user="${1:-thapakazi}"
    for i in `ls -1d */.git|cut -d / -f1|xargs`; do
        (cd $i && echo "$(git_count_commits $user) $i")
    done
}

git_commits_on_projects_total(){
    git_commits_on_project "${1:-thapakazi}" | awk '{print $1}' | paste -sd+ |bc
}
