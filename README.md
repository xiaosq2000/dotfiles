# dotfiles

Managed with [chezmoi](https://www.chezmoi.io/). This repository is the chezmoi
*source* tree, so the files here carry chezmoi's naming: `dot_zshrc.tmpl`
becomes `~/.zshrc`, `private_dot_config/` becomes `~/.config` with mode 0700,
and `executable_` marks a file that is installed with the executable bit set.

## Prerequisites

- `curl`, `git`, `unzip`
- A [Nerd Font](https://www.nerdfonts.com/) installed and enabled in your terminal.

`zsh` is *not* a prerequisite. On a machine without it, and without root to
install it, `pixi global install zsh` puts it in your home directory. See
[CAVEATS.md](dot_sh_utils/CAVEATS.md).

## Install

> [!CAUTION]
> This replaces your dotfiles. Back up first.

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply xiaosq2000
```

`init` asks two questions, and `chezmoi init` records the answers in
`~/.config/chezmoi/chezmoi.toml` so they are never asked again:

| prompt    | meaning                                                                             |
| --------- | ----------------------------------------------------------------------------------- |
| `machine` | which entry of [.chezmoidata/machines.toml](.chezmoidata/machines.toml) describes this host |
| `theme`   | `main`, `moon` or `dawn` — see [.chezmoidata/themes.toml](.chezmoidata/themes.toml)  |

`machine` defaults to whichever entry's `hostnamePattern` matches, so on a known
host you can press enter. To answer up front, for a container or a script:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply \
    --promptString machine=workstation \
    --promptChoice theme=main \
    xiaosq2000
```

A machine that is not in the table yet can start as `generic`, which installs a
working shell and assumes nothing else.

## Day to day

```sh
chezmoi diff          # what would change
chezmoi apply         # make ~ match this repo
chezmoi edit ~/.zshrc # edit the source of a file, not the copy in ~
chezmoi cd            # open a shell in the source tree
```

Editing a file in `~` directly does not update the repository. Either use
`chezmoi edit`, or edit in place and run `chezmoi re-add`.

## Themes

Light and dark used to be two long-lived branches, `main` and `theme/light`,
which had to be kept in step by hand and drifted anyway. They are now one
value:

```sh
theme            # show the current variant
theme dawn       # switch to Rosé Pine Dawn everywhere and apply
theme --dry-run main
```

One switch covers btop, kitty, Neovim, starship, alacritty and fzf. To restyle
another tool, add a key to [.chezmoidata/themes.toml](.chezmoidata/themes.toml)
and reference it from that tool's template. Do not hard-code a variant name in
a config file.

## Machines

Everything that differs per host lives in one table,
[.chezmoidata/machines.toml](.chezmoidata/machines.toml): which tool bundles to
install, whether there is a graphical session, whether to install a Rust
toolchain, and where pixi should keep its package cache and environments.

```sh
machine          # describe this machine and what follows from it
machine --list   # every machine the repository knows about
```

There is no command to change it. A machine is what the hardware is, so either
edit its entry or point this host at a different one with
`chezmoi init --promptString machine=<name>`.

## Installed tools

Tools come from pixi, in named bundles.
[.chezmoidata/tools.toml](.chezmoidata/tools.toml) says which packages each
bundle contains, and each machine selects the bundles it wants. A shared login
node takes `core`, `dev-py`, `ml` and `secrets`; a workstation takes everything.

`~/.pixi/manifests/pixi-global.toml` is **generated** from those two files, so:

```sh
# add a package to the right bundle in .chezmoidata/tools.toml, then
chezmoi apply
```

`pixi global install <package>` still works, and the next `chezmoi apply` still
undoes it. This is a deliberate trade: the install used to *be* the edit, which
was pleasant and gave every machine the same 34 environments, ffmpeg and a
60-binary clang-tools among them, on an HPC login node included.

`pixi global sync` makes a machine match the manifest exactly, so removing a
bundle from a machine uninstalls its tools and reclaims the space.

Each package gets its own environment, and `exposed` is listed explicitly in
`tools.toml`. Both matter: one environment per bundle would make a single
dependency conflict break every tool in it, and omitting `exposed` installs an
environment while linking none of its binaries. Several conda-forge packages
also ship a whole runtime beside the tool you wanted, so exposing everything
would put `node`, `openssl`, `python3.14`, `tclsh` and `wish` on `PATH`.

## TODO

- [ ] gnome-terminal: the rose-pine theme is fetched as an external, but
      nothing loads `template.dconf` into dconf yet.
