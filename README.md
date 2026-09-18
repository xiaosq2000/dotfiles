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

`init` asks three questions, and `chezmoi init` records the answers in
`~/.config/chezmoi/chezmoi.toml` so they are never asked again:

| prompt             | meaning                                                           |
| ------------------ | ----------------------------------------------------------------- |
| `theme`            | `main`, `moon` or `dawn` — see [.chezmoidata/themes.toml](.chezmoidata/themes.toml) |
| `installBinaries`  | run the `~/.sh_utils/setup.d` tool chain                          |
| `installTypefaces` | install Maple Mono and friends                                    |

To answer them up front, for a container or a script:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply \
    --promptChoice theme=main \
    --promptBool installBinaries=true \
    --promptBool installTypefaces=false \
    xiaosq2000
```

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

## Installed tools

`~/.pixi/manifests/pixi-global.toml` is the source of truth, and it is tracked
here. Adding a tool is:

```sh
pixi global install <package>
chezmoi re-add ~/.pixi/manifests/pixi-global.toml
```

The install *is* the edit. `.sh_utils/setup.d/pixi.sh` then only has to run
`pixi global sync`, which makes any machine match the manifest.

## TODO

- [ ] gnome-terminal: the rose-pine theme is fetched as an external, but
      nothing loads `template.dconf` into dconf yet.
