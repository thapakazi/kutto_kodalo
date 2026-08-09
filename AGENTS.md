# AGENTS.md

Guidance for AI agents working in this repository. Humans may find it useful too.

`docs/CONVENTIONS.md` is the **code contract** — doc-block format, naming,
portability and safety rules. Read it before writing shell.
This file is the **working contract** — how to verify, what silently breaks
here, and what to leave alone. **Where the two disagree, this file wins**;
report the contradiction so it gets fixed.

---

## If you read nothing else

1. This config is sourced into the user's **live interactive shell**. A bug here
   breaks their terminal. There is no staging.
2. **Loading without errors is not the same as working.** Assert end state.
3. Run `bash -n` *and* `zsh -n` on every file you touch. The two shells disagree
   silently and constantly.
4. Never `local` a zsh **tied** name: `path fpath cdpath manpath mailpath
   module_path fignore`. `local path=…` empties `$PATH` for that function.
5. Function definitions must start at **column 0** or they vanish from the docs.
6. `docs/` is generated. Edit the doc block, run `just docs`.
7. Don't run destructive recipes (`just fmt`, `just clean`, `just site-clean`)
   while other agents are working — `just fmt` rewrites every shell file.
8. Report bugs in files you don't own. Don't fix them. Say what you **verified**
   versus what you **inferred**.

---

## Layout

```
shellrc            loader; resolves its own symlink, sources everything below
lib/               numbered, always loaded: guards, colours, os, compat
modules/common/    portable      modules/darwin/  macOS    modules/linux/  Linux
modules/local/     machine-specific, gitignored, loaded last, overrides anything
bin/               bootstrap, doctor, shellrc-doc, shelp-show
completions/       HAND-WRITTEN zsh completions — not generated, do not delete
docs/              generated AND committed, except CONVENTIONS.md
attic/             retired code, never sourced
```

The old flat `shellrc.d/` layout and its `Makefile` were removed in the Phase 4
cutover; they survive in git history and the retired parts in `attic/`. Comments
across the modules still cite `shellrc.d/<file>` when explaining why something
was renamed — those are historical references, not live paths.

---

## Verification

```sh
bin/doctor                     # load, effective shell state, collisions, docs
bin/shellrc-doc --check        # fails if a doc block changed without regenerating
just docs                      # regenerate after ANY doc-block edit
bash -n FILE && zsh -n FILE    # syntax, both dialects, every file you touch

# clean load — the flags matter: without them you get the user's own rc noise
bash --noprofile --norc -c 'source ./shellrc'
zsh -f -c 'source ./shellrc'
# both must emit ZERO bytes on stderr
```

### `just check` is not CI

It skips shellcheck when shellcheck isn't installed. It now says
`checks passed, but some were SKIPPED` rather than claiming success — believe
the SKIPPED, and don't report "all checks passed" for a check that never ran.

CI (`.github/workflows/check.yml`) is the authority. Its shellcheck invocation
is mirrored in the Justfile; keep them identical if you change either.

### Loading clean is not the same as working

A loader change once used `setopt local_options`, which reverted **every shell
option the modules set** — `PROMPT_SUBST`, `vi` mode, all the history options —
the moment the loader function returned. **No stderr, no failure, and
`bin/doctor` said "nothing broken."** The user found it because their prompt
rendered its own source code.

`bin/doctor`'s "Effective shell state" section exists because of that bug and
must keep passing. After touching `shellrc` or anything setting shell state,
assert the end state, not the absence of errors.

### Test interactive behaviour interactively

`zle`, `bindkey`, widgets and keymaps do not exist under `zsh -c`. A binding
looks absent and you will "fix" a bug that was never there. Use `zsh -i`, and
compare against `zsh -f` to tell your bug from the user's own `~/.zshrc`.

### Destructive functions: read, never run

`cleanup_*`, `files_purge_node_modules`, `k8s_delete_*` delete gigabytes. Verify
by reading and sourcing, or against a fake `$HOME` in a scratch directory.
`jq -r '.[]|select(.danger!="")|.name' docs/functions.json` lists them.

### `bin/bootstrap` is not a diagnostic

`bin/doctor` exits non-zero on a machine where `~/.shellrc` isn't linked. That
is a real finding, not a false positive, and it is CI's problem — not yours.

**Do not run `bin/bootstrap` to silence it.** Even `--no-install --yes` symlinks
`~/.shellrc`, appends to `~/.zshrc` and `~/.bashrc`, creates `modules/local/`,
and regenerates `docs/`. `--dry-run` is the only safe probe.

---

## Landmines

Every one shipped here at least once. Most produce **no error at all**.

### Column-0 definitions

`bin/shellrc-doc` anchors its matcher at column 0. An indented definition — one
wrapped in `if require …; then`, or moved by a reformat — is **dropped from the
docs, `shelp`, the site and doctor's census** with no error.

It now warns when a *documented* function is indented. Silence is not proof:
undocumented indented functions are still dropped silently, by design. Annotate
deliberate exceptions (lazy-load stubs) with `# shellrc-doc: ignore`.

A blank line between the doc block and the function also detaches it.

### zsh special parameter names

Applies to `lib/` and `modules/`, which are sourced into zsh. `bin/` scripts run
under a bash shebang and are exempt — `bin/bootstrap` uses `local prompt`
correctly.

**Tied to an uppercase variable — silent damage:**

```
path  fpath  cdpath  manpath  mailpath  module_path  fignore
```

`local path=…` sets `PATH=…` for the rest of that function; you get
`cut: command not found` from an unrelated line. Passes every bash test.

`status` is read-only and errors loudly, so it can't ship unnoticed. `argv
options commands functions aliases dirstack psvar prompt watch` are special but
harmless to shadow locally. `signals` is **not** special — don't rename it.

When unsure: `zsh -f -c 'print ${(t)NAME}'` — "tied" or "special" means avoid.

**Match the identifier, not the substring.** `local param_path=` is fine. A grep
for `path` flags it, and a bogus report against exactly that has already been
filed here once.

### The two shells disagree silently

| Construct | Behaviour |
|---|---|
| `${var//\'/\'\'}` | bash correct; zsh emits `\'\'` → invalid SQL |
| unquoted `$VAR` splitting | bash splits; **zsh does not** — flags arrive as one arg |
| unmatched glob | zsh `NOMATCH` **aborts the whole script**; bash leaves it literal |
| array indexing | bash 0-based, zsh 1-based |
| `read -p` / `read "v?…"` | bash / zsh — neither works in both |

Remedies, because knowing the hazard isn't enough:

```sh
# quote doubling — portable. The naive zsh fix ${var//'/''} is a bash SYNTAX ERROR.
q="'"; out=${var//$q/$q$q}

# globs — copy the pattern in shellrc's _shellrc_source_dir: scoped null_glob,
# restore ONLY that option (never `local_options`), plus `[ -f "$f" ] || continue`.
```

The glob one matters more than it looks: under `zsh -c 'source ./shellrc'` — how
doctor, `just check` and CI all load the config — one unmatched glob at load time
kills the rest of the load.

### BSD vs GNU

macOS ships BSD userland: `sed -i` needs an argument there and must not have one
on GNU; `base64 -w0`, `readlink -f`, `ps` flags, `shuf`, `stat` all differ.

**Read `lib/30-compat.sh`** — it is short, and it is the complete list. Never
call `sed -i`, `readlink -f`, `base64 -w0`, `pbcopy`/`xclip`, `xdg-open`, or a
literal `/tmp/name` path directly.

A tool working locally proves nothing: `base64 -w0` succeeds here only because
GNU coreutils is on this PATH. It fails on a clean Mac.

### Nothing may fork at source time

Modules may assign variables, define functions, and set shell options
(`setopt`, `bindkey`, `set -o vi` — that's configuration). Everything else is
banned: no network, no `git clone`, no file writes, no subshells.

Past violations: `ssh_config_refresh` rewrote `~/.ssh/config` on every shell
start; `cowfortune` forked `brew list` per shell. Budget is 100ms;
`SHELLRC_DEBUG=1` gives per-file timing.

### macOS `/home` is an autofs mount

Stat-ing a non-existent `/home/…` path costs ~14ms **each** on macOS. Two
linuxbrew probes cost 30ms of startup on a machine that never had it. Guard
behind `is_linux`; never test the path directly.

### Shadowing and `exit`

`exit` in a sourced file kills the user's interactive shell — use `return`.
For naming, see CONVENTIONS rule 3. `bin/doctor` checks functions, aliases and
zsh-only functions against **this machine's** PATH, so a collision that exists
only on the other OS still gets through.

---

## Known false positives

- **shellcheck dialect errors** — dual bash/zsh files linted as bash: `SC2296`
  on `${(%):-%x}`, `SC2206` on `fpath=(…)`, `SC2154` on zsh-managed vars,
  `SC2153` on `LBUFFER`. CI excludes these.
  CI *also* excludes `SC2088`, `SC2119`, `SC2120` — those are a **real backlog**,
  not false positives. Don't confuse "suppressed" with "wrong".
- **`bin/doctor` reporting `prompt` as "dependencies missing"** — `prompt.sh` is
  zsh-only and doctor's census runs under bash. Not a missing dependency; do not
  "fix" it by removing its zsh guard. (`calendar`, `gcloud` are genuinely
  dependency-gated.)
- **`completions/_shellrc_generated` and `shellrc-generated.bash`** are
  generated — edit the `@complete` block and run `just docs`. `_shelp` and
  `_aws_ssm_session` alongside them are hand-written and predate the generator.

---

## Scope discipline

If you were given a file list, **write only those files**. Read anything.

**Exception: `docs/`.** It is generated *and* committed, so regenerating it is
expected and exempt. Never hand-edit or hand-merge `docs/functions.json` — re-run
`just docs`.

Found a real bug in a file you don't own? **Report it, don't fix it.** Give the
exact identifier and line, and separate what you verified by running something
from what you inferred by reading. Cross-file reports here have been wrong before.

Don't run `just fmt` (rewrites every shell file in place, and can re-indent
functions out of the docs), `just clean`, or `just site-clean` while others are
working. `site-clean` once deleted another agent's freshly installed packages.

---

## Common tasks

**Add a function.** Doc block first. Column 0, no blank line before the
definition. `_`-prefix it if it's a private helper, or it lands in the public API
and on the docs site. Use `lib/` helpers. Quote everything, `local` everything.
If it's destructive it **must** call `confirm` and carry `@danger`. Back-compat
alias if you renamed something. Then `just docs` and `bin/doctor`.

**Adding an `@requires` tool has a consequence.** `bin/bootstrap` installs
whatever `bin/shellrc-doc --list-requires` reports, and bootstrap's
tool→package table is the only place that mapping lives. A new or typo'd token becomes a package the next bootstrap tries
to install. Add it to the table.

**Add a module.** One topic per file, `@module`/`@summary` header, guard on
dependencies at the top (`require docker || return 0`) so it defines nothing when
its tools are missing. OS-specific code goes in `darwin/` or `linux/`, never
behind an `if` in `common/`.

**Retire something.** Copy to `attic/`, add a one-line reason to
`attic/README.md`. Prefer retiring dead code to porting it — several functions
here targeted services that shut down years ago. **Verify the service is actually
dead**, and never silently repoint a function at a different provider: that
changes where the user's data goes.

**Query the docs instead of grepping.** `docs/functions.json` has one entry per
public function — run `jq '.[0] | keys' docs/functions.json` for the fields, and
`bin/shelp-show <name>` for one rendered entry.

---

## Repo conventions

- Never commit or push unless asked.
- Default branch is **`gumantae`**, not `main`.
- `.deepsec/` is large and holds a token — it must stay gitignored.
- Check for pre-existing uncommitted work before committing; keep it in its own
  commit rather than absorbing it into yours.
- Doc-block examples are published to a search-indexed website. **No real
  hostnames, account names, colleague names, IPs or emails** — use
  `example.com`, `myaccount`, `192.0.2.0/24` (RFC 5737).
- Don't hardcode counts or sizes in documentation. They go stale silently; print
  them (`jq length docs/functions.json`) instead.
