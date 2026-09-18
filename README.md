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
    --promptString theme=rose-pine \
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
which had to be kept in step by hand and drifted anyway. They are now one value:

```sh
theme                          # current variant, and the alternatives
theme rose-pine-dawn           # switch everywhere and apply
theme --dry-run catppuccin-mocha
```

One switch covers btop, kitty, alacritty, Neovim, zathura, fzf and starship.

Variants are named after the slug upstream uses, so `rose-pine-moon` rather than
`moon`. Each colour scheme is one file,
[.chezmoidata/themes-rose-pine.toml](.chezmoidata/themes-rose-pine.toml) and
[.chezmoidata/themes-catppuccin.toml](.chezmoidata/themes-catppuccin.toml), and
chezmoi merges them, so adding a scheme means adding a file and editing nothing.
Each file holds two things:

- `[schemes.<name>]` — where the theme files come from and which Neovim plugin
  provides them. Selecting a Catppuccin variant installs `catppuccin/nvim`, not
  just a different colorscheme name.
- `[themes.<slug>]` — the token each tool uses for that variant, its
  `appearance` (`light` or `dark`), and its fzf palette.

The tokens are per tool because they have to be. Catppuccin's btop theme is
`catppuccin_mocha`, its kitty theme is `mocha`, and its alacritty theme is
`catppuccin-mocha`.

Theme files are fetched, not vendored, and always to a fixed name:
`~/.config/btop/themes/current.theme`,
`~/.config/alacritty/current-theme.toml`,
`~/.config/kitty/current-theme.conf`. Vendoring meant one committed copy per
variant per tool, which is how the dark kitty copy came to have white and
bright-white set to Dawn's foreground.

Coverage is uneven and `theme` says so. The starship configs come from a
personal fork that only carries Rosé Pine, so a Catppuccin variant leaves
`~/.config/starship.toml` unmanaged. `appearance` is what a tool with no port
for a scheme can fall back on, and the only field every variant is guaranteed
to have.

To restyle another tool, add a key to each scheme file and reference it from
that tool's template. Do not hard-code a variant name in a config file: zathura
had `include rose-pine-dawn` written into `zathurarc`, and so sat on the light
theme no matter what the rest of the machine was set to.

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

## Secrets

This repository is public, so anything secret in it is age ciphertext: a file
named `encrypted_*` is decrypted on apply, and the key is never committed.
Bitwarden holds one copy of the key so a new machine can fetch it once.

It is currently **off**. `.chezmoidata/secrets.toml` has an empty
`ageRecipient`, so the generated config has no `[age]` section and every machine
applies without a key. [docs/secrets.md](docs/secrets.md) has the design and the
commands to turn it on.

The plaintext half is already done:
[.chezmoidata/machines.toml](.chezmoidata/machines.toml) is the machine
inventory, in the clear, because bundles, roles and filesystem layout are not
secrets. Addresses, account names and tokens are.

## Outstanding

[docs/todo.md](docs/todo.md), which separates what needs a credential or a
decision from what is merely worth doing.
