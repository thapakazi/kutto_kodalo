# attic

Nothing in this directory is sourced. The loader in `shellrc` only walks `lib/`
and `modules/`, so these files are inert — they are kept because deleting a
decade of shell config feels worse than reading it once more.

If you want something back, port it properly into `modules/` under the rules in
`docs/CONVENTIONS.md`. Do not add `attic/` to the load path.

## Why each file is here

| File | Why it was retired |
|------|--------------------|
| `rhoit/rho.sh` | **Security.** Its `ssh` wrapper deleted lines from `~/.ssh/known_hosts` based on a line number parsed out of `/tmp/ssh_key_error` — a world-writable path the function never actually wrote to, because the `2>` redirect that would have created it was commented out. So it read a stale or attacker-planted file and stripped host keys on that basis, defeating MITM protection. It also overrode `emacs`, `nemo` and `py` with hardcoded `/usr/bin/...` paths. Only `pysrv` survived, as `shell_serve_http` in `modules/common/shell.sh`. |
| `emacs.sh` | Ran Emacs in Docker with `-v ~/.ssh/id_rsa:...` — handing a private SSH key to a third-party container image — and `-e DISPLAY` with an X11 socket mount. Dead since the move off X11. |
| `workaround.sh` | `lets_put_laptop_in_sleep` is an infinite `systemctl suspend` loop, and `wifi_chodam` carried a hardcoded WiFi password in the repo. |
| `forget_me_all_octopress.sh` | Octopress blog helpers. The blog is long gone, and `OCTO_HOME="~/octopress"` had the same quoted-tilde bug as the GPG module. |
| `reveal_js.sh` | Downloads reveal.js 3.3.0, pinned to a version from 2016, by piping `wget` into `tar`. |
| `broken_stuffs.sh` | Self-labelled: "almost everything here is broken or might not work". rawgit.com, which two of the functions depend on, shut down in 2019. |
| `learn_bash.sh` | A scratchpad of bash notes, not configuration. |
| `ansible.sh` | 100% commented out, all of it about Python 2 interpreter workarounds. |
| `ruby.sh` | 100% commented out — a single JRuby JVM flag. |
| `zoxide.sh` | One commented-out line. If you want zoxide, add a real module. |
| `colors.sh` | Superseded by `lib/10-colors.sh`. Same palette, `C_`-prefixed, and blanked automatically for `NO_COLOR` and non-tty output. |
| `os.sh` | Superseded by `lib/20-os.sh`. `get_os`/`if_mac`/`if_linux`/`install_deps` became `os_name`/`is_macos`/`is_linux`/`pkg_install`. |
| `common.sh` | Created `~/.shellrc.d/generated` at source time. The loader owns `$SHELLRC_CACHE` now. |

Originals also remain untouched in `shellrc.d/` — nothing was deleted, this is a
signpost, not a graveyard.
