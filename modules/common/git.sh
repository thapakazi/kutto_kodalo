# @module git
# @summary Git log formatting, commit counting across projects, and a couple of
#          everyday branch helpers.

require git || return 0

# @describe Print the commit graph in the compact one-line-per-commit format:
#           abbreviated hash, refs, subject, relative date, author.
# @usage    git_log_graph [git-log-argument]...
# @example  git_log_graph
# @example  git_log_graph -20 --author=milan
# @requires git
# @os       any
git_log_graph() {
    git log --graph --abbrev-commit \
        --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' \
        "$@"
}

# @describe Count non-merge commits by one author in the current repository for a
#           single calendar year. The author string is matched as a substring of
#           the author name and email, so "milan" or an email both work.
# @usage    git_count_commits [author] [year]
# @example  git_count_commits
# @example  git_count_commits milan 2024
# @requires git
# @os       any
git_count_commits() {
    local author="$1" year="$2"

    if [ -z "$author" ]; then
        author="$(git config user.name 2>/dev/null)"
        [ -n "$author" ] || author="$USER"
    fi
    [ -n "$year" ] || year="$(date +%Y)"

    git rev-list \
        --author="$author" \
        --count \
        --since="Jan 1 $year" \
        --before="Dec 31 $year 23:59:59" \
        --all --no-merges
}

# @describe Count an author's commits for every git repository one level below the
#           current directory. Prints "<count> <project>" per line.
# @usage    git_count_commits_by_project [author] [year]
# @example  git_count_commits_by_project
# @example  git_count_commits_by_project milan 2024 | sort -rn
# @requires git
# @see      git_count_commits git_count_commits_total
# @os       any
git_count_commits_by_project() {
    local author="$1" year="$2" entry="" project="" count=""

    # `find` rather than a */.git glob: zsh aborts on an unmatched glob.
    find . -mindepth 2 -maxdepth 2 -name .git 2>/dev/null | sort |
        while IFS= read -r entry; do
            project="${entry%/.git}"
            project="${project#./}"
            count="$( (cd "$project" && git_count_commits "$author" "$year") 2>/dev/null )"
            [ -n "$count" ] || count=0
            printf '%s %s\n' "$count" "$project"
        done
}

# @describe Sum an author's commits across every git repository one level below the
#           current directory.
# @usage    git_count_commits_total [author] [year]
# @example  git_count_commits_total milan 2024
# @requires git
# @see      git_count_commits_by_project
# @os       any
git_count_commits_total() {
    git_count_commits_by_project "$1" "$2" |
        awk '{ total += $1 } END { print total + 0 }'
}

# @describe List local branches most-recently-committed first, with relative date
#           and last author. Useful for finding what you were working on.
# @usage    git_show_recent_branches [count]
# @example  git_show_recent_branches
# @example  git_show_recent_branches 5
# @requires git
# @os       any
git_show_recent_branches() {
    local count="${1:-15}"
    git for-each-ref \
        --sort=-committerdate \
        --count="$count" \
        --format='%(color:green)%(committerdate:relative)%(color:reset)%09%(refname:short)%09%(color:blue)%(authorname)%(color:reset)' \
        refs/heads/
}

# @describe Print the repository's default branch, as advertised by the remote.
#           Falls back to main, then master, when the remote HEAD is not set.
# @usage    git_get_default_branch [remote]
# @example  git rebase "origin/$(git_get_default_branch)"
# @requires git
# @os       any
git_get_default_branch() {
    local remote="${1:-origin}" ref=""

    ref="$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2>/dev/null)"
    if [ -n "$ref" ]; then
        printf '%s\n' "${ref#"$remote"/}"
        return 0
    fi

    local candidate
    for candidate in main master; do
        if git show-ref --quiet --verify "refs/heads/$candidate" 2>/dev/null; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    log_error "git_get_default_branch: could not determine default branch for '$remote'"
}

# ------------------------------------------------------------ back-compat ----
# Old names from shellrc.d/git.sh. The long names above are the API.

alias git_log='git_log_graph'
alias git_commits_on_projects='git_count_commits_by_project'
alias git_commits_on_projects_total='git_count_commits_total'
