# Outstanding work

Nothing here is required for any machine to work. Everything needs a decision, a
credential, or a machine that is not to hand.

**State:** workstation, imrl and sicc are deployed and verified; `chezmoi
status` is empty on all three and CI is green. Laptop and vps have never had
chezmoi run on them.

## Needs a decision

### What bundles the vps should get

Ubuntu 24.04, root, **21 GB disk with 5.0 GB free**. Its job is network
plumbing and nothing else. `hostnamePattern` is empty, so init needs the name by
hand:

```sh
chezmoi init --apply --promptString machine=vps --promptString theme=rose-pine-dawn xiaosq2000
```

Its entry currently says `bundles = ["core"]`, which is ~680 MB of pixi
environments plus a hardlinked package cache — call it 1–1.5 GB, a fifth to a
third of the free space, for tools a networking box rarely opens. Most of the
weight is not the shell: `pre-commit` 271 MB, `difftastic` 140 MB, `sheldon`
117 MB, `sqlite` 90 MB.

`bundles = []` costs nothing and still deploys every config file. Two
consequences:

- `.chezmoiremove` removes a replaced binary when the pixi copy exists *or* the
  package is not in this machine's bundles. With no bundles the second branch
  always fires, so `~/.local/bin/nvim`, `~/.fzf` and the rest go with nothing
  replacing them.
- `~/.oh-my-zsh` stays, since its removal is guarded on sheldon having cloned
  its plugins.

`.zshrc` is safe either way — `sheldon` and `starship` are both behind `if has`.

Deploying the vps is optional; it unblocks nothing below.

## Blocked on the laptop

The laptop is being handled by hand, off this machine. Until it has run
`chezmoi init --apply`, three pieces of migration scaffolding have to stay:

- the legacy theme-name map in `.chezmoi.toml.tmpl`, translating `main`, `moon`
  and `dawn`;
- `run_onchange_before_01-stale-externals.sh`, which removes git-submodule
  remnants of chezmoi externals;
- most blocks in `.chezmoiremove`.

The first two act only on state a previous chezmoi init leaves behind, so they
are no-ops on the vps and blocked on the laptop alone. `.chezmoiremove` does
apply to the vps, which carries the old `.sh_utils` layout.

Deleting all three is one commit once the laptop is done.

## Worth doing

### Wire up or drop the gnome-terminal theme

`.chezmoiexternal.toml` checks out a Rosé Pine gnome-terminal theme and nothing
loads its `template.dconf` into dconf. It is the last thing in the repository
hard-wired to one colour scheme. kitty and alacritty are what actually get used.

### Shell startup is ~510 ms locally, ~1.1 s on imrl and sicc

`~/.sh_utils/*.sh` is roughly 1300 lines sourced at every shell start, including
a 614-line network script, and `setup_texlive` globs the texlive tree every
time. Autoloaded functions would fix most of it. The remote figure is the one
that stings, and sicc's home is on NFS.

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
