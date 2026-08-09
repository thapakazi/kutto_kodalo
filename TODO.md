# Revamp TODO

Tracking the restructure from a flat 63-file `shellrc.d/` into a documented,
cross-platform, generated-docs layout. See `docs/CONVENTIONS.md` for the rules
every module follows.

**Cutover strategy:** the new tree is built alongside the old one. `shellrc.d/`
stays live and untouched until Phase 4, so existing shells keep working
throughout.

---

## Phase 0 — Foundation ✅

- [x] Branch `revamp`
- [x] New `shellrc` loader — self-locating, explicit load order, OS-gated,
      `SHELLRC_DEBUG=1` timing
- [x] `lib/00-core.sh` — `has`, `require`, `require_any`, `confirm`, logging
- [x] `lib/10-colors.sh` — `C_*` namespace, honours `NO_COLOR` and non-tty
- [x] `lib/20-os.sh` — `os_name`, `is_macos`, `os_arch`, `pkg_install`
- [x] `lib/30-compat.sh` — `clip_copy`, `os_open`, `sed_inplace`, `path_resolve`,
      `b64_encode`, `tmp_file`, `path_size`
- [x] `docs/CONVENTIONS.md` — doc-block format, naming, portability, safety
- [x] Verified identical behaviour under zsh and bash

## Phase 1 — Module port (parallel)

Each agent owns a disjoint set of source files and writes only to its targets.

- [ ] **cloud** — `aws.sh` `gcloud.sh` `ssh.sh` → `modules/common/{aws,gcloud,ssh}.sh`
- [ ] **containers** — `docker.sh` `docker_fun.sh` `kube.sh` `k8s.sh` `k9s.sh`
      → `modules/common/{docker,kubernetes}.sh`
- [ ] **utils** — `utils.sh` `jpt.sh` `ps.sh` `process.sh` `inspector.sh`
      → `modules/common/{files,net,text,process}.sh`
      (`media.sh` belongs to the darwin agent, not this one)
- [ ] **devtools** — `git.sh` `golang.sh` `ruby*.sh` `nvm.sh` `uv.sh`
      `pip_function.sh` `db.sh` `redis.sh` `openssl.sh` `emacs.sh`
      → `modules/common/{git,lang,db,tls}.sh`
- [ ] **darwin** — `clean.sh` `ai.sh` `alacrity.sh` `media.sh` `edits.sh`
      `phone.sh` → `modules/darwin/*.sh`
- [ ] **shell+linux+attic** — shell env, `gpg.sh`, Linux-only modules, retirements
- [ ] **tooling** — `bin/shellrc-doc`, `bin/doctor`, `bin/bootstrap`, `Justfile`

## Phase 2 — Generated documentation

- [ ] `bin/shellrc-doc` parses `@describe`/`@usage`/`@requires`/`@os` blocks
- [ ] Emits `docs/reference/<module>.md` — one page per module
- [ ] Emits `docs/INDEX.md` — every function, one line each, grouped by module
- [ ] Emits `docs/functions.json` — machine-readable, for agents
- [ ] Runtime `shelp <query>` searches it from the shell
- [ ] Regeneration wired into `just docs` and checked in CI

## Phase 3 — Verification

- [ ] `shellcheck -s bash` clean across `lib/` and `modules/`
- [ ] Loads clean in zsh AND bash with no stderr output
- [ ] Startup under 100ms (`SHELLRC_DEBUG=1`)
- [ ] `bin/doctor` reports missing deps without false positives
- [ ] Simulated fresh-machine test: bootstrap into a clean HOME

## Phase 4 — Cutover

- [ ] `git rm -r shellrc.d/` (history preserved; retired code lives in `attic/`)
- [ ] `Justfile` symlinks `~/.shellrc` → repo `shellrc` (single symlink now)
- [ ] `Makefile` deleted (duplicate of the Justfile)
- [ ] `README.md` replaces `README.org`
- [ ] Back-compat alias shim for renamed functions, so muscle memory survives

---

## Security fixes (tracked individually — all must land)

| # | Issue | Where | Status |
|---|-------|-------|--------|
| 1 | `gpg_backup` writes private key to a literal `./~/` dir (quoted tilde) | `gpg.sh:8` | [ ] |
| 2 | `ssh` override deletes `known_hosts` lines from an unwritten `/tmp` file | `rhoit/rho.sh:64` | [ ] |
| 3 | `ssh_config_refresh` runs at startup, clobbers `~/.ssh/config` | `ssh.sh:20` | [ ] |
| 4 | Hardcoded Postgres password, written to `/tmp/secrets` | `docker_fun.sh:6` | [ ] |
| 5 | Decrypted SSM secrets left in `/tmp` and on the clipboard | `aws.sh:99,127` | [ ] |
| 6 | Predictable `/tmp` paths across ~20 sites → use `tmp_file` | repo-wide | [ ] |
| 7 | `curl \| bash` unpinned | `kube.sh:69`, `kube.sh:41` | [ ] |
| 8 | `alias damn_it='sudo $(fc -ln -1)'` — silent sudo replay | `fun.sh:64` | [ ] |
| 9 | `[Y/n]` prompt proceeds on any input → `confirm` | `utils.sh:17` | [ ] |
| 10 | `exit` inside sourced functions kills the shell | `pacman.sh:52`, `theme_switch.sh:91` | [ ] |
| 11 | Unnecessary `eval` for indirect expansion | `aws.sh:194` | [ ] |
| 12 | `.deepsec/` (818MB, holds a Vercel token) unignored at root | `.gitignore` | [ ] |

## Correctness fixes

- [ ] `Justfile` `{{}}` interpolation invalid in assignments — evaluates to a
      literal string, would symlink to a nonsense path
- [ ] `gcloud.sh` defines global `init()`; `$doamin` typo deletes wrong record
- [ ] `ai.sh` defines `hf_cleanup` twice
- [ ] `ai.sh purge_pure_junk` duplicates `clean.sh` without confirmation
- [ ] `clean.sh` Claude VM guard uses `-f` on a directory — dead code
- [ ] `kube.sh` sources `~/.kubectl_aliases` unguarded after a conditional fetch
- [ ] `aws.sh` `autoload -Uz assm` is a no-op on a defined function
- [ ] 10 functions shadow real binaries: `uptime` `emacs` `ssh` `nemo` `py`
      `claude` `init` `try` `remind` `buffer`
- [ ] `LC_ALL` forced globally in `generic.sh` — should be `LANG` only
