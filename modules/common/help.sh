# @module help
# @summary Search the generated documentation from inside the shell. Reads
#          docs/functions.json, which bin/shellrc-doc regenerates from the doc
#          blocks in lib/ and modules/.

# Path to the generated database. Resolved lazily so nothing runs at load time.
_shelp_db() {
    printf '%s/docs/functions.json\n' "${SHELLRC_ROOT:-}"
}

# Emit `module<TAB>summary` for every public function, one line per function.
_shelp_modules_tsv() {
    local db="$1"
    if has jq; then
        jq -r '.[] | select(.private | not) | [.module, .module_summary] | @tsv' "$db"
    else
        _shelp_awk "$db" modules
    fi
}

# Emit `name<TAB>module<TAB>os<TAB>usage<TAB>describe<TAB>danger` for matches.
_shelp_search_tsv() {
    local db="$1" query="$2" mode="$3"
    if has jq; then
        jq -r --arg q "$query" --arg mode "$mode" '
            .[]
            | select(.private | not)
            | select(
                if $mode == "module" then (.module | ascii_downcase) == $q
                else ((.name + " " + .describe + " " + .usage)
                      | ascii_downcase | contains($q))
                end
              )
            | [.name, .module, .os, .usage, .describe, .danger] | @tsv' "$db"
    else
        _shelp_awk "$db" "$mode" "$query"
    fi
}

# Pure-awk JSON reader, used when jq is absent. It relies on the exact layout
# bin/shellrc-doc emits: one `"key": value` per line inside a `{ … }` block.
_shelp_awk() {
    local db="$1" mode="$2" query="${3:-}"
    LC_ALL=C awk -v mode="$mode" -v query="$query" '
        function unesc(c) {
            if (c == "n") return "\n"
            if (c == "t") return " "
            if (c == "r") return ""
            if (c == "b") return ""
            if (c == "f") return ""
            return c
        }
        # scan every double-quoted JSON string in s into arr[]; returns the count
        function jstrings(s, arr,   n, i, len, c, cur, inq, esc) {
            n = 0; inq = 0; esc = 0; cur = ""; len = length(s)
            for (i = 1; i <= len; i++) {
                c = substr(s, i, 1)
                if (inq) {
                    if (esc)            { cur = cur unesc(c); esc = 0 }
                    else if (c == "\\") { esc = 1 }
                    else if (c == "\"") { n++; arr[n] = cur; cur = ""; inq = 0 }
                    else                { cur = cur c }
                } else if (c == "\"")   { inq = 1; cur = "" }
            }
            return n
        }
        function scalar(v,   a, n) {
            n = jstrings(v, a)
            return (n > 0) ? a[1] : ""
        }
        function lower(s) { return tolower(s) }

        /^  [{]/ {
            name = ""; module = ""; msum = ""; os = ""; usage = ""
            describe = ""; danger = ""; private = "false"
            next
        }
        /^    "/ {
            k = $0; sub(/^    "/, "", k); sub(/".*$/, "", k)
            v = $0; sub(/^    "[^"]*": /, "", v); sub(/,$/, "", v)
            if      (k == "name")           name     = scalar(v)
            else if (k == "module")         module   = scalar(v)
            else if (k == "module_summary") msum     = scalar(v)
            else if (k == "os")             os       = scalar(v)
            else if (k == "usage")          usage    = scalar(v)
            else if (k == "describe")       describe = scalar(v)
            else if (k == "danger")         danger   = scalar(v)
            else if (k == "private")        private  = v
            next
        }
        /^  [}]/ {
            if (private == "true" || name == "") next
            if (mode == "modules") {
                printf("%s\t%s\n", module, msum)
            } else if (mode == "module") {
                if (lower(module) == query) fmt()
            } else {
                if (index(lower(name " " describe " " usage), query) > 0) fmt()
            }
            next
        }
        function fmt() {
            printf("%s\t%s\t%s\t%s\t%s\t%s\n",
                   name, module, os, usage, describe, danger)
        }
    ' "$db"
}

# Colourise a match stream produced by _shelp_search_tsv.
_shelp_render() {
    LC_ALL=C awk -F '\t' \
        -v cn="$C_B_CYAN" -v cm="$C_DIM" -v cu="$C_GREEN" \
        -v cd="$C_B_RED" -v cr="$C_RESET" '
        {
            tag = $2
            if ($3 == "darwin") tag = tag ", macOS only"
            else if ($3 == "linux") tag = tag ", Linux only"
            printf("%s%s%s %s(%s)%s\n", cn, $1, cr, cm, tag, cr)
            if ($4 != "") printf("    %s%s%s\n", cu, $4, cr)
            if ($5 != "") printf("    %s\n", $5)
            if ($6 != "") printf("    %s! %s%s\n", cd, $6, cr)
            print ""
        }'
}

# @describe Search the generated function documentation from the shell. With no
#           arguments it lists every module and how many functions it has; with a
#           query it matches case-insensitively against function names,
#           descriptions and usage strings.
# @usage    shelp [-m <module>] [query]
# @example  shelp
# @example  shelp ssm
# @example  shelp -m docker
# @requires jq
# @os       any
# @see      shellrc-doc
shelp() {
    local db query module_mode="" out count
    db="$(_shelp_db)"

    if [ -z "${SHELLRC_ROOT:-}" ]; then
        log_error "shelp: SHELLRC_ROOT is not set — is ~/.shellrc sourced?"
        return 1
    fi
    if [ ! -f "$db" ]; then
        log_error "shelp: $db is missing — run 'bin/shellrc-doc' (or 'just docs')"
        return 1
    fi

    case "${1:-}" in
        -h | --help)
            printf '%sshelp%s — search the generated shellrc documentation\n\n' \
                "$C_BOLD" "$C_RESET"
            printf '  shelp                list every module and its function count\n'
            printf '  shelp <query>        case-insensitive search over name, description, usage\n'
            printf '  shelp -m <module>    list every function in one module\n\n'
            printf '  Full index: %s/docs/INDEX.md\n' "$SHELLRC_ROOT"
            return 0
            ;;
        -m | --module)
            shift
            if [ $# -eq 0 ]; then
                log_error "shelp: -m needs a module name"
                return 1
            fi
            module_mode=module
            ;;
    esac

    # ---- no arguments: the module overview ----
    if [ $# -eq 0 ] && [ -z "$module_mode" ]; then
        out="$(_shelp_modules_tsv "$db")" || return 1
        printf '%s\n' "$out" | LC_ALL=C awk -F '\t' \
            -v cn="$C_B_CYAN" -v cm="$C_DIM" -v cr="$C_RESET" -v cb="$C_BOLD" '
            {
                if (!($1 in n)) { n[$1] = 0; nmod++; order[nmod] = $1 }
                n[$1]++
                if (s[$1] == "") s[$1] = $2
                total++
            }
            END {
                printf("%s%d functions across %d modules%s\n\n",
                       cb, total, nmod, cr)
                i = nmod
                # insertion sort — portable across awk implementations
                for (a = 2; a <= i; a++) {
                    v = order[a]
                    for (b = a - 1; b >= 1 && order[b] > v; b--) order[b + 1] = order[b]
                    order[b + 1] = v
                }
                for (a = 1; a <= i; a++) {
                    m = order[a]
                    sum = s[m]
                    if (length(sum) > 62) sum = substr(sum, 1, 59) "..."
                    printf("  %s%-16s%s %s%3d%s  %s%s%s\n",
                           cn, m, cr, cr, n[m], cr, cm, sum, cr)
                }
                printf("\n  %sshelp <query>%s to search, %sshelp -m <module>%s to list one\n",
                       cb, cr, cb, cr)
            }'
        return 0
    fi

    query="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    out="$(_shelp_search_tsv "$db" "$query" "${module_mode:-search}")" || return 1

    if [ -z "$out" ]; then
        if [ -n "$module_mode" ]; then
            log_warn "shelp: no module named '$1' (try 'shelp' for the list)"
        else
            log_warn "shelp: nothing matches '$1'"
        fi
        return 1
    fi

    count="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
    printf '%s\n' "$out" | _shelp_render
    printf '%s%s match%s%s\n' "$C_DIM" "$count" \
        "$([ "$count" = 1 ] || printf 'es')" "$C_RESET"
}
