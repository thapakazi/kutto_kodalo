# Developing

How to add to this repo and verify what you added. For the rules themselves see
[`CONVENTIONS.md`](CONVENTIONS.md); for working here as an AI agent see
[`../AGENTS.md`](../AGENTS.md).

## Adding a module

Create `modules/common/thing.sh` — or `modules/darwin/`, `modules/linux/` if it
is OS-specific.

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

Then regenerate and check:

```sh
just docs      # docs/INDEX.md, functions.json, reference/
just check     # shellcheck + docs freshness + clean load in bash and zsh
```

Four rules catch most mistakes: `<namespace>_<verb>_<noun>` naming, never shadow
a real binary, never call `pbcopy`/`sed -i`/`readlink -f` directly (use
`lib/30-compat.sh`), and nothing may fork a process at source time. Definitions
must also start at column 0 — an indented one is silently dropped from the docs.

## How the docs are generated

`bin/shellrc-doc` is bash + awk, with no python/node/perl dependency. It scans
`lib/*.sh` and `modules/*/*.sh` for `# @tag` doc blocks and writes:

| File | Audience |
|------|----------|
| `docs/reference/<module>.md` | one page per module, full detail |
| `docs/INDEX.md` | humans skimming for "what do I have?" |
| `docs/functions.json` | agents and `shelp` |

Generated files open with a `DO NOT EDIT` banner. `_`-prefixed functions are
private and skipped. A public function with no doc block still appears, marked
undocumented with a warning on stderr, so the gap is visible instead of silent.

```sh
bin/shellrc-doc                  # regenerate
bin/shellrc-doc --check          # exit 1 if regenerating would change anything
bin/shellrc-doc --list-requires  # the dependency set, derived not hardcoded
```

`--check` is what CI and `just check` run — a stale `docs/` fails the build.

## Machine-local config

Anything private, work-specific, or true only on this machine goes in
`modules/local/*.sh`. Gitignored, loaded last so it can override anything, never
leaves the machine.

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

`doctor` is read-only. It reports your OS/arch/shell/package manager, whether
`~/.shellrc` is linked and sourced, whether the config loads with **zero stderr**
in both bash and zsh, startup time against a 100 ms budget, which modules stayed
silent for missing tools (with the exact install command for each), which names
shadow a real binary on `PATH`, whether the shell options and prompt actually
took effect, and whether `docs/` is current. Non-zero exit means something is
genuinely broken; warnings do not fail it.

```sh
just check     # what CI runs
just clean     # drop the runtime cache and editor droppings
just fmt       # shfmt, 4-space indent — rewrites every shell file in place
```

`just check` skips shellcheck when shellcheck is not installed, and says so
rather than reporting success. CI is the authority.

## CI

[`check.yml`](../.github/workflows/check.yml) runs on pull requests and pushes to
the default branch, on **`ubuntu-latest` and `macos-latest` both** —
cross-platform correctness is the point of this repo, so a change that works on
only one of them fails.

| Check | Fails when |
|-------|-----------|
| `shellcheck` over `shellrc`, `lib/`, `modules/`, `bin/` | a new warning appears (dual bash+zsh files carry a documented exclusion list) |
| `bin/shellrc-doc --check` | a doc block changed and `just docs` was not run |
| sourcing `shellrc` in bash and zsh | either exits non-zero or writes **anything** to stderr |
| `bin/doctor` after `bin/bootstrap --no-install` | the config installs but the resulting shell state is wrong |

[`pages.yml`](../.github/workflows/pages.yml) regenerates the docs, builds the
Astro site in `site/`, and publishes to GitHub Pages — so the published docs
derive from the shell source on every push.

```sh
just site-dev      # docs site locally, hot reload
just site-build    # regenerate docs + build site/dist, as CI does
just site-preview  # serve the built site/dist
```

## Load order

`lib/` (numbered), then `modules/common/`, then `modules/<os>/`, then
`modules/local/`. `SHELLRC_DEBUG=1 zsh -i -c exit` prints per-file timing.
