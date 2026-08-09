# shellrc — task runner.
#
# `just` on its own lists everything below.
#
# NOTE ON SYNTAX: `{{ }}` interpolation is only valid inside recipe *bodies*.
# In variable assignments it is not expanded — it ends up in the string
# literally. Assignments concatenate with `+`. Verify any change with
# `just --evaluate`.

REPO      := justfile_directory()
HOME_DIR  := env_var('HOME')

SHELLRC_SRC  := REPO + "/shellrc"
SHELLRC_LINK := HOME_DIR + "/.shellrc"

BIN  := REPO + "/bin"
DOCS := REPO + "/docs"

# List every recipe (this is what `just` with no arguments runs).
default:
    @just --list --unsorted

# Install onto this machine: packages, symlink, rc files, docs, doctor.
install *ARGS:
    "{{ BIN }}/bootstrap" {{ ARGS }}

# Show what `just install` would do, without touching anything.
preview:
    "{{ BIN }}/bootstrap" --dry-run

# Regenerate docs/INDEX.md, docs/functions.json and docs/reference/.
docs:
    "{{ BIN }}/shellrc-doc"

# Report the health of this machine's installation.
doctor:
    "{{ BIN }}/doctor"

# Everything CI runs: lint, docs freshness, and a clean load in bash and zsh.
check:
    #!/usr/bin/env bash
    set -uo pipefail
    fail=0

    echo "==> shellcheck"
    if command -v shellcheck >/dev/null 2>&1; then
        files=("{{ REPO }}"/lib/*.sh "{{ REPO }}"/shellrc)
        for f in "{{ REPO }}"/modules/*/*.sh; do [ -f "$f" ] && files+=("$f"); done
        for f in "{{ BIN }}"/*; do [ -f "$f" ] && files+=("$f"); done
        shellcheck -s bash -e SC1090,SC1091,SC2034 "${files[@]}" || fail=1
    else
        echo "   shellcheck not installed — skipped (just install adds it)"
    fi

    echo "==> generated docs are current"
    "{{ BIN }}/shellrc-doc" --check || fail=1

    echo "==> loads clean in bash and zsh"
    for sh in bash zsh; do
        command -v "$sh" >/dev/null 2>&1 || { echo "   $sh not installed — skipped"; continue; }
        case "$sh" in
            bash) flags=(--noprofile --norc) ;;
            zsh)  flags=(-f) ;;
        esac
        err="$("$sh" "${flags[@]}" -c 'source "{{ SHELLRC_SRC }}"' 2>&1 >/dev/null)"
        if [ -n "$err" ]; then
            echo "   $sh wrote to stderr at load time:"
            printf '     %s\n' "$err"
            fail=1
        else
            echo "   $sh: clean"
        fi
    done

    [ "$fail" -eq 0 ] && echo "==> all checks passed"
    exit "$fail"

# Format every shell file with shfmt (4-space indent, matching the repo style).
fmt:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v shfmt >/dev/null 2>&1; then
        echo "shfmt is not installed. brew install shfmt / apt install shfmt" >&2
        exit 1
    fi
    shfmt -i 4 -ci -sr -w \
        "{{ REPO }}/shellrc" "{{ REPO }}"/lib/*.sh "{{ REPO }}"/modules/*/*.sh "{{ BIN }}"/*

# Remove generated caches and stray editor/OS droppings. Never touches docs/.
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    cache="${SHELLRC_CACHE:-$HOME/.cache/shellrc}"
    [ -d "$cache" ] && rm -rf "$cache" && echo "removed $cache"
    find "{{ REPO }}" -name '.DS_Store' -type f -print -delete
    find "{{ REPO }}" \( -name '*~' -o -name '*.swp' -o -name '#*#' \) -type f -print -delete
    echo "clean"

# Where does everything live?
paths:
    @echo "repo         {{ REPO }}"
    @echo "shellrc      {{ SHELLRC_SRC }}"
    @echo "symlink      {{ SHELLRC_LINK }}"
    @echo "docs         {{ DOCS }}"
