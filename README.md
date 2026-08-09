# kutto_kodalo

> _kutto kodalo_ — Nepali for the hand tools you work a field with.

Shell configuration for bash and zsh, on macOS and Linux. Every function
documents itself, and the docs are generated from that — never hand-written.

## Install

```sh
git clone git@github.com:thapakazi/kutto_kodalo.git ~/repos/kutto_kodalo
cd ~/repos/kutto_kodalo && ./bin/bootstrap
```

Installs the tools the modules ask for, symlinks `~/.shellrc` (one symlink — the
loader finds the rest), and adds the source line to your rc files. Re-running is
safe.

```sh
./bin/bootstrap --dry-run     # show every action, change nothing
./bin/bootstrap --no-install  # wire it up, skip the packages
```

## Use

```sh
shelp                # every module, and how many functions it has
shelp ssm            # search names, usage and descriptions
shelp -m docker      # everything in one module
shelp -i             # fuzzy picker with live preview
Ctrl-G               # pick a function, drop it on the command line
```

```sh
bin/doctor           # is this machine set up correctly?
just docs            # regenerate the docs after editing a doc block
```

## Docs

- **[thapakazi.github.io/kutto_kodalo](https://thapakazi.github.io/kutto_kodalo/)**
  — everything, searchable, in a browser
- [`docs/INDEX.md`](docs/INDEX.md) — every function, one line each
- [`docs/DEVELOPING.md`](docs/DEVELOPING.md) — adding a module, generating docs, CI
- [`docs/CONVENTIONS.md`](docs/CONVENTIONS.md) — the rules every module follows
- [`AGENTS.md`](AGENTS.md) — for AI agents working in this repo
- [`docs/functions.json`](docs/functions.json) — the same data, for machines

## Layout

```
shellrc          entry point; resolves its own path, sources everything below
lib/             always loaded, in order. The cross-platform compat layer.
modules/common/  portable        modules/darwin/  macOS    modules/linux/  Linux
modules/local/   machine-specific, gitignored, loaded last, overrides anything
bin/             bootstrap, doctor, shellrc-doc, shelp-show
docs/            generated, except CONVENTIONS.md and DEVELOPING.md
attic/           retired code, never sourced
```

## Requirements

`bash` or `zsh`, plus `awk`, `sed` and `git`. Everything else is optional: a
module whose tools are missing defines nothing and says nothing, and `doctor`
tells you what you're missing and how to get it.
