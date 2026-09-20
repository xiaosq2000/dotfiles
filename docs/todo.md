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

The laptop took its age identity by hand on 2026-09-20, which is the only way a
new machine can get one: see [secrets.md](secrets.md), which records why the
fetcher cannot succeed on a first init. imrl and sicc still have no key and
apply everything else in full.

rustup is installed on the workstation and the laptop, the two machines with
`rust = true`. It is gone from imrl, sicc and the vps, and no machine sources
`~/.cargo/env`.

## Worth doing

### Shell startup is ~510 ms locally, ~1.1 s on imrl and sicc

`~/.sh_utils/*.sh` is roughly 1300 lines sourced at every shell start, including
a 614-line network script, and `setup_texlive` globs the texlive tree every
time. Autoloaded functions would fix most of it. The remote figure is the one
that stings, and sicc's home is on NFS.

The laptop measures 657 ms, so this is not only a remote problem.

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
