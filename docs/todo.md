# Outstanding work

Nothing here is required for any machine to work. What is left needs a machine
that is not to hand, or is simply worth doing.

**State:** all five machines — workstation, laptop, imrl, sicc and vps — are
deployed; `chezmoi status` is empty on each and CI is green.

The laptop came up on 2026-09-20, the last of the five, and its second apply
cleared about 115 MB of pre-chezmoi leftovers: oh-my-zsh, the fzf checkout, and
the `~/.local/bin` copies of nvim, uv, lazydocker and the huggingface tools.
The stale 27 MB `~/.local/share/nvim/runtime` came off by hand at the same
time; `.chezmoiremove` could never take it, because its siblings under
`~/.local/share/nvim` are lazy, mason and session state.

With the laptop done, the migration scaffolding went with it on the same day:
`.chezmoiremove`, `run_onchange_before_01-stale-externals.sh` and the legacy
`main`/`moon`/`dawn` theme-name map in `.chezmoi.toml.tmpl` are all deleted. No
machine still carries the old `$HOME`-as-a-git-worktree layout, so there was
nothing left for any of them to clean.

The laptop took its age identity by hand on 2026-09-20, because the fetcher was
`run_once_before_` and so could never succeed on a first init. It is
`run_onchange_before_` now, keyed on whether rbw exists yet, so it retries on
the second apply; see [secrets.md](secrets.md). imrl and sicc still have no key
and apply everything else in full.

rustup is installed on the workstation and the laptop, the two machines with
`rust = true`. It is gone from imrl, sicc and the vps, and no machine sources
`~/.cargo/env`.

## Do these next

### imrl and sicc still have no age key

So `.chezmoiignore` leaves `~/.ssh/config` unmanaged on both and they apply
everything else in full. They pick it up the moment a key arrives, with no other
change. Whether that is worth doing depends on whether you want the SSH config
on a shared lab server and a cluster login node at all.

## Worth doing

### Shell startup, fixed and measured everywhere

All five machines were on the fix and measured on 2026-09-20, ten warm runs each
with a tty attached:

| machine | before | after |
| --- | ---: | ---: |
| laptop | 750 ms | 230 ms (325 ms in a fresh terminal, which pays for `proxy shell on`) |
| workstation | — | 161 ms |
| imrl | ~1.1 s | 256 ms |
| sicc | ~1.1 s | 397 ms |

sicc stays the slowest, which is what you would expect with home on NFS. It is
no longer the outlier it was.

The entry that stood here blamed `~/.sh_utils/*.sh` — "roughly 1300 lines sourced
at every shell start" — and proposed autoloaded functions. That was wrong, and
profiling with `PS4` xtrace timestamps said so plainly:

| cost | ms | |
| --- | ---: | --- |
| `eval "$(pixi completion --shell zsh)"` | 375 | 11,781 lines, re-parsed every shell |
| `proxy shell on` | 133 | systemctl and tun probes |
| `eval "$(codex completion zsh)"` | 102 | 4,232 lines |
| `source` the uv completion | 30 | 552 KB read every shell |
| 10 × `tput` in `lib/ui.sh` | 15 | only when stdout is a tty |
| **sourcing all of `~/.sh_utils`** | **5** | what the entry blamed |
| `setup_texlive` | 0.3 | what the entry blamed |

Two thirds of startup was three completion scripts being re-parsed on every
shell. They are cached to files on `fpath` now and load on the first Tab
instead; see [CAVEATS.md](../dot_sh_utils/CAVEATS.md). `proxy shell on` is
skipped when `http_proxy` is already set, so only the first shell under a
terminal pays for it.

The lesson is worth keeping: the line count of what gets sourced was a bad
proxy for what it cost. Sourcing 2,776 lines of function definitions is 5 ms.

What is left is about 150 ms locally with nothing individually above 11 ms, so
there is no single next thing to fix. The `tput` forks in `lib/ui.sh:20-29` are
the largest remaining item at 15 ms, and they could be replaced by zsh's own
`%F{}` escapes — worth more on sicc than here, since ten forks over NFS is where
its remaining 397 ms mostly goes.

Measure with a tty attached. `lib/ui.sh` skips its `tput` branch when stdout is
a pipe, so a piped benchmark understates by those 15 ms:

```sh
time ( for i in $(seq 10); do script -qec "zsh -ic exit" /dev/null >/dev/null 2>&1; done )
```

### The typefaces installer

`setup.d/typefaces.sh` is 433 lines, the largest thing left in that directory.
It installs sixteen families, each with its own release-asset naming and wanted
extensions. Every machine has `typefaces = false`, so a rewrite to
`.chezmoiexternal.toml` would be large and untestable without downloading about
a gigabyte of fonts. `gitHubLatestReleaseAssetURL` would do most of the work.

Fonts are installed on the workstation despite the flag being false; they came
from elsewhere and nothing removes them.

### Mason installs language servers per machine

On any machine without the `lsp` bundle. This is the intended fallback, not a
bug. Listed so it is not rediscovered as one.
