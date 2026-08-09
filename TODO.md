# Revamp TODO

The restructure from a flat 63-file `shellrc.d/` into a documented,
cross-platform layout with generated docs. See `docs/CONVENTIONS.md` for the code
contract and `AGENTS.md` for the working one.

**Phases 0–4 are complete.** The old tree is gone; what remains is listed under
"Still open" at the bottom.

---

## Phase 0 — Foundation ✅

Self-locating loader (one symlink, explicit load order, OS-gated dirs,
`SHELLRC_DEBUG=1` timing); `lib/` with dependency guards, `C_*` colours, OS
detection and the compat layer; `docs/CONVENTIONS.md`.

## Phase 1 — Module port ✅

Seven parallel agents on disjoint file sets: cloud, containers, utils, devtools,
darwin, shell+linux+attic, tooling. Every module carries doc blocks, guards on
its dependencies, and keeps the old short names as back-compat aliases.

## Phase 2 — Generated documentation ✅

`bin/shellrc-doc` (bash+awk, no runtime deps) emits `docs/INDEX.md`,
`docs/reference/<module>.md` and `docs/functions.json`. `shelp` searches it from
the shell; `shelp -i` is an fzf picker with live preview; `Ctrl-G` drops a
function name on the command line. Published as an Astro site.

## Phase 3 — Verification ✅

CI green on ubuntu **and** macos: shellcheck, docs freshness, clean load in both
shells failing on any stderr, bootstrap and doctor. `bin/doctor` additionally
asserts *effective shell state*, added after a loader bug silently reverted every
module-set option while producing no output at all.

## Phase 4 — Cutover ✅

- [x] `shellrc.d/` removed — 62 files. Every name was accounted for first by
      diffing the old tree against the new **source** (not the macOS runtime,
      which hides `modules/linux/`), then checking the remainder against `attic/`
- [x] The last 5 genuinely unported functions → `modules/linux/system.sh`
- [x] The nunchux tmux hook → `modules/local/`. The plugin **is** installed on
      this machine, so dropping it would have broken tmux
- [x] `Makefile` deleted — its `all:` target re-installed the old layout
- [x] `README.org` → `README.md`; dangling `~/.shellrc.d` symlink removed

---

## Security fixes — all landed ✅

| # | Issue | Resolution |
|---|-------|------------|
| 1 | `gpg_backup` wrote a **private key** into a literal `./~/` dir; its key-id helper printed to stdout so it captured the whole key table — it never worked | `umask 077` in a trapped subshell, encryption mandatory |
| 2 | `ssh` override deleted `known_hosts` lines from a `/tmp` file it never wrote | Retired |
| 3 | `ssh_config_refresh` ran at startup, clobbering `~/.ssh/config` | User-invoked, timestamped backups |
| 4 | Hardcoded Postgres password written to `/tmp/secrets` | Random per invocation, `chmod 600`, trapped |
| 5 | Decrypted SSM values on the clipboard and left in `/tmp` | In-memory only, trapped cleanup |
| 6 | ~20 predictable `/tmp` paths | `tmp_file` / `tmp_dir` |
| 7 | `curl \| bash`, unpinned | Download → checksum → `confirm` |
| 8 | `damn_it` replayed the last command under sudo silently | Prints it, requires `confirm` |
| 9 | `[Y/n]` prompt proceeded on any input | `confirm`, defaults to no |
| 10 | `exit` in sourced functions killed the shell | `return` |
| 11 | `eval` for indirect expansion | Shell-branched safe expansion |
| 12 | `.deepsec/` (818MB, holds a token) unignored | Gitignored |
| 13 | Private SSH keys written to a world-readable `/tmp` dir | `~/.ssh/generated`, mode 700 |
| 14 | `claude` wrapper leaked `IS_DEMO=1` into every descendant process | Not ported |
| 15 | Real hostname, account and colleague names in examples destined for a public site | Replaced with RFC 5737 placeholders |

## Correctness fixes — all landed ✅

Unterminated `jq` program (the function could never run); infinite pagination
loop; `rm -rf /tmp_node_junk` typo meaning node_modules scans were never
refreshed; `dushd` walking the parent directory; malformed password character
ranges; delete-cluster targeting a literal `_cluster_name`; `gcloud` remove
missing both `--zone` and its rrdata; `hf_cleanup` defined twice; dead
`-f`-on-a-directory guard; unguarded `~/.kubectl_aliases` source; ten functions
shadowing real binaries; `LC_ALL` forced globally; broken `Justfile` `{{}}`
interpolation; three files that were never valid bash.

Plus four found by reviewing the tooling itself: `just check` claiming success
while skipping shellcheck; `bin/doctor` blind to aliases and zsh-only functions;
`bin/shellrc-doc` silently dropping indented definitions; `CONVENTIONS.md`
documenting a completion generator that does not exist.

---

## Still open

### Autocompletion — the main outstanding feature
- [ ] `bin/shellrc-completions` generating zsh/bash completers from
      `docs/functions.json`
- [ ] `@complete` tag parsed by `bin/shellrc-doc` (the spec is written in
      `docs/CONVENTIONS.md` and clearly marked NOT IMPLEMENTED)
- [ ] Annotate the ~20 functions with real word lists; inference covers the rest
- [ ] `completions/_shelp` and `_aws_ssm_session` are hand-written until then

### Deploy
- [ ] Pages deploy needs `pages.yml` on the default branch — merge PR #1, or
      cherry-pick that one file, so `workflow_dispatch` becomes available

### Cleanups
- [ ] shellcheck backlog: `SC2088` ×9 (literal `~` in strings), `SC2015`,
      `SC2119/2120`. Currently excluded in CI with a TODO
- [ ] `k9s_install_themes` has an `is_macos` branch inside `modules/common/` —
      belongs in `modules/darwin/k9s.sh`
- [ ] `configmap_*` helpers sit in `aws.sh` behind `require aws`, but are pure
      Kubernetes — they vanish on a machine with kubectl and no AWS CLI
- [ ] `claude_demo` (scoped replacement for the `IS_DEMO` wrapper) has no home
- [ ] `shellcheck` not installed locally, so `just check` skips that stage

### Questions for the user
- [ ] `workaround.sh` held a hardcoded WiFi password. Retired to `attic/`, but it
      is still in git history — port it properly, or genuinely dead?
- [ ] `transferX` pointed at transfer.sh, offline since 2024. Add
      `net_upload_file` against a host you pick, or leave it retired?
- [ ] Install `fzf` and retire the percol `Ctrl-R` block? fzf ships a better one,
      and having both is a load-order race for the binding
