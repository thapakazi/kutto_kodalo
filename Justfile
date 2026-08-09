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
SITE := REPO + "/site"

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

# ---------------------------------------------------------------- docs site --
#
# site/ is an Astro app that renders docs/ into the published documentation at
# https://thapakazi.github.io/kutto_kodalo/. Its own prebuild step re-derives
# site content from docs/, so `just docs` first is only needed when you want the
# doc blocks re-scanned from the shell source.
#
# Deliberately NOT folded into `just check`: that recipe is the CI gate and must
# stay fast and node-free (bin/bootstrap depends on it being so). The site is
# built by .github/workflows/pages.yml, checked by .github/workflows/check.yml
# only insofar as docs/ must be current.

# Run the docs site locally with hot reload.
site-dev:
    cd "{{ SITE }}" && npm install && npm run dev

# Build the docs site into site/dist, exactly as CI does.
site-build:
    "{{ BIN }}/shellrc-doc"
    cd "{{ SITE }}" && npm ci && npm run build

# Serve the built site/dist locally, to check it before pushing.
site-preview:
    cd "{{ SITE }}" && npm run preview

# Drop the docs site's build output and dependencies.
site-clean:
    #!/usr/bin/env bash
    set -euo pipefail
    for d in dist .astro node_modules src/content/docs; do
        target="{{ SITE }}/$d"
        if [ -e "$target" ]; then rm -rf "$target"; echo "removed site/$d"; fi
    done

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
    @echo "site         {{ SITE }}"
