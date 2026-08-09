# kutto_kodalo

> _kutto kodalo_ — the dog's hoe. A tool you keep sharpening even though nobody
> asked you to.

A shell configuration for bash and zsh, on macOS and Linux, where **every
function documents itself** and the documentation is generated from the source.
Nothing here is hand-maintained prose that can drift out of date.

- [`docs/INDEX.md`](docs/INDEX.md) — every function, one line each. Generated.
- [`docs/functions.json`](docs/functions.json) — the same thing for machines and
  AI agents. Generated.
- [`docs/CONVENTIONS.md`](docs/CONVENTIONS.md) — the rules every module follows.
  The only hand-written doc.

---

## New machine

```sh
git clone <this-repo> ~/repos/kutto_kodalo
cd ~/repos/kutto_kodalo
./bin/bootstrap
```

That one command:

1. detects your OS and package manager, offering to install Homebrew on macOS
   (it downloads the installer, shows it to you, and asks before running it —
   no `curl | bash`);
2. installs every tool the modules declare via `@requires`, mapping tool names
   to package names per platform (`magick` → `imagemagick`, `kubectl` →
   `kubernetes-cli`, …);
3. backs up any existing `~/.shellrc` with a timestamp and symlinks
   `~/.shellrc` → `<repo>/shellrc` — **one symlink, the loader finds the rest**;
4. appends the source line to `~/.zshrc` and `~/.bashrc` only if it is not
   already there, so re-running is safe;
5. creates `modules/local/` for machine-specific config;
6. regenerates the docs and runs `bin/doctor`.

Look before you leap:

```sh
./bin/bootstrap --dry-run     # print every action, change nothing
./bin/bootstrap --no-install  # wire things up, skip the packages
```

Or with [`just`](https://github.com/casey/just): `just install`, `just preview`.

## Searching it from the shell

```sh
shelp                # every module and how many functions it has
shelp ssm            # case-insensitive search over names, usage, descriptions
shelp -m docker      # everything in one module
```

`shelp` reads `docs/functions.json`. It uses `jq` when available and falls back
to awk when it isn't, so it works on a machine where nothing is installed yet.
Zsh completion for it is generated from the same file.

## Layout

```
shellrc              entry point; resolves its own path, sources everything below
lib/                 numbered, always loaded, in order. The compat layer.
modules/common/      portable — must work on macOS and Linux
modules/darwin/      macOS only
modules/linux/       Linux only
modules/local/       machine-specific, gitignored, never committed
completions/         zsh completion functions (_name)
bin/                 bootstrap, doctor, shellrc-doc
docs/reference/      GENERATED — do not edit
attic/               retired code, kept for history, never sourced
```

Load order is explicit: `lib/` (numbered), then `modules/common/`, then
`modules/<os>/`, then `modules/local/`. `SHELLRC_DEBUG=1 zsh -i -c exit` prints
per-file load timing.

## Adding a module

Create `modules/common/thing.sh` (or `modules/darwin/`, `modules/linux/`):

```sh
# @module thing
# @summary One line about what this module is for.

require thing || return 0        # absent tool -> defines nothing, stays silent

# @describe Do the thing. The first sentence lands in docs/INDEX.md.
# @usage    thing_do <target> [flags]
# @example  thing_do ~/some/file
# @requires thing jq
# @os       any
# @danger   Deletes files without asking twice.
thing_do() {
    local target="$1"
    ...
}
```

Then:

```sh
just docs      # regenerate docs/INDEX.md, functions.json, reference/
just check     # shellcheck + docs freshness + clean load in bash and zsh
```

Rules worth internalising before you write one: `<namespace>_<verb>_<noun>`
naming, never shadow a binary, never call `pbcopy`/`sed -i`/`readlink -f`
directly (use `lib/30-compat.sh`), nothing executes at source time. They are all
in [`docs/CONVENTIONS.md`](docs/CONVENTIONS.md), and `bin/doctor` enforces the
ones it can.

## How the docs are generated

`bin/shellrc-doc` is bash + awk, with no python/node/perl dependency. It scans
`lib/*.sh` and `modules/*/*.sh` for the `# @tag` doc blocks and writes:

| File | Audience |
|------|----------|
| `docs/reference/<module>.md` | one page per module, full detail |
| `docs/INDEX.md` | humans skimming for "what do I have?" |
| `docs/functions.json` | agents and `shelp` |

Every generated file opens with a `DO NOT EDIT` banner. Functions prefixed with
`_` are private and skipped. A public function with no doc block still appears —
marked undocumented, with a warning on stderr, so the gap is visible instead of
silent.

```sh
bin/shellrc-doc                  # regenerate
bin/shellrc-doc --check          # exit 1 if regenerating would change anything
bin/shellrc-doc --list-requires  # the dependency set, derived not hardcoded
```

`--check` is what CI and `just check` run — a stale `docs/` fails the build.

## Machine-local config

Anything private, work-specific, or true only on this laptop goes in
`modules/local/*.sh`. That directory is gitignored, loaded last (so it can
override anything), and never leaves the machine.

```sh
cat >> modules/local/work.sh <<'EOF'
# @module work
# @summary Work-only helpers.
export AWS_PROFILE=work
EOF
```

## Checking it

```sh
just doctor    # or bin/doctor
```

`doctor` is read-only and reports: your OS/arch/shell/package manager, whether
`~/.shellrc` is linked and sourced, whether the config loads with **zero stderr
output** in both bash and zsh, startup time against a 100 ms budget, which
modules stayed silent because their tools are missing (with the exact
`brew install …` to fix each one), which function names shadow a real binary on
`PATH`, and whether `docs/` is current. It exits non-zero when something is
actually broken.

```sh
just check     # what CI runs
just clean     # drop the runtime cache and editor droppings
just fmt       # shfmt, 4-space indent
```

## Requirements

`bash` or `zsh`, plus `awk`, `sed` and `git` — all of which you already have.
Everything else is optional: a module whose tools are missing defines nothing
and says nothing, and `doctor` tells you what you are missing and how to get it.
