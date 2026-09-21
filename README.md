# dotfiles

Managed with [chezmoi](https://www.chezmoi.io/). This repository is the chezmoi
*source* tree, so files here carry chezmoi's naming: `dot_zshrc.tmpl` becomes
`~/.zshrc`, `private_dot_config/` becomes `~/.config` with mode 0700,
`executable_` sets the executable bit, and `encrypted_` is age ciphertext.

## Install

> [!CAUTION]
> This replaces your dotfiles. Back up first.

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply xiaosq2000
```

Needs `curl`, `git`, `unzip` and a [Nerd Font](https://www.nerdfonts.com/)
enabled in your terminal. `zsh` is not a prerequisite; without root,
`pixi global install zsh` puts one in your home directory — see
[CAVEATS.md](dot_sh_utils/CAVEATS.md) for that and the other shell-setup
constraints.

`init` asks two questions and records the answers in
`~/.config/chezmoi/chezmoi.toml`, so they are never asked again:

| prompt    | value |
| --------- | ----- |
| `machine` | an entry of [.chezmoidata/machines.toml](.chezmoidata/machines.toml) |
| `theme`   | `rose-pine`, `rose-pine-moon`, `rose-pine-dawn`, `catppuccin-latte`, `catppuccin-frappe`, `catppuccin-macchiato`, `catppuccin-mocha` |

`machine` defaults to whichever entry's `hostnamePattern` matches, so on a known
host press enter. To answer up front, for a container, a script, or a host with
no pattern:

```sh
chezmoi init --apply \
    --promptString machine=workstation \
    --promptString theme=rose-pine \
    xiaosq2000
```

A machine not in the table yet can start as `generic`: a working shell, nothing
else assumed.

## Day to day

```sh
chezmoi diff          # what would change
chezmoi apply         # make ~ match this repo
chezmoi update        # pull, then apply
chezmoi edit ~/.zshrc # edit the source of a file, not the copy in ~
chezmoi cd            # open a shell in the source tree
```

Editing a file in `~` does not update the repository. Use `chezmoi edit`, or
edit in place and run `chezmoi re-add`.

`chezmoi edit` takes a target path, so it cannot reach the files that have no
target: `.chezmoidata/*.toml`, `.chezmoiignore` and `.chezmoiexternal.toml` are
read by chezmoi and never deployed. Reach them through the source tree:

```sh
chezmoi cd                                              # then edit normally
$EDITOR "$(chezmoi source-path)/.chezmoidata/machines.toml"
chezmoi edit-config-template                            # the config template
```

## Themes

```sh
theme                          # pick a variant with fzf (--help for the plain list)
theme rose-pine-dawn           # switch everywhere and apply
theme --dry-run catppuccin-mocha
```

One switch covers btop, kitty, alacritty, Neovim, zathura, fzf and starship.
Variants use the slug upstream uses.

Each colour scheme is one file —
[themes-rose-pine.toml](.chezmoidata/themes-rose-pine.toml),
[themes-catppuccin.toml](.chezmoidata/themes-catppuccin.toml) — and chezmoi
merges them, so adding a scheme means adding a file and editing nothing. Each
holds:

- `[schemes.<name>]` — where theme files come from, and which Neovim plugin
  provides them.
- `[themes.<slug>]` — the token each tool uses for that variant, its
  `appearance` (`light` or `dark`), and its fzf and starship palettes.

Tokens are per tool because upstreams disagree: Catppuccin Mocha is
`catppuccin_mocha` to btop, `mocha` to kitty and `catppuccin-mocha` to
alacritty.

Theme files are fetched to a fixed name —
`~/.config/btop/themes/current.theme`,
`~/.config/alacritty/current-theme.toml`,
`~/.config/kitty/current-theme.conf` — so nothing is vendored per variant.
Starship is the exception: it has no include mechanism, so
`~/.config/starship.toml` is rendered from
[a template](private_dot_config/starship.toml.tmpl) with the palette inlined
from `[themes.<slug>.starship]`.

`appearance` is the fallback for a tool with no port for a scheme, and the one
field every variant has.

To restyle another tool, add a key to each scheme file and reference it from
that tool's template. Never hard-code a variant name in a config file.

## Agent output

```sh
/i-have-adhd                   # Claude Code, for this session
$i-have-adhd                   # Codex, for this session
stop adhd mode                 # end it
```

[i-have-adhd](https://github.com/ayghri/i-have-adhd) reshapes agent output to be
acted on: next action first, numbered steps, no preamble.
[setup.d/adhd.sh](dot_sh_utils/setup.d/executable_adhd.sh) installs it wherever
`claude` or `codex` is on PATH, and does nothing where neither is, so it is not
gated on the machine's bundles.

Installing changes nothing by itself, which is the point. The skill is opt-in on
both agents, so neither model can reach for it unasked and `chezmoi update` does
not quietly change how a machine's agents talk.

There was briefly an `adhd on` command here that made the rules apply from
message one of every session, by touching a flag the plugin's SessionStart hook
reads and writing the condensed rules into `~/.codex/AGENTS.md`. It is gone: two
mechanisms and a wrapper to remember them, against typing nine characters when
you actually want it. Upstream's flag file still works if the itch returns.

## Context for agents

[AGENTS.md](AGENTS.md), which `CLAUDE.md` imports, is for an agent changing this
repository. It covers the source-versus-target model, the naming attributes, and
the rules that keep secrets out of a public repository.

The `machines` skill is for an agent working anywhere else. It carries a page per
machine (what it is for, how to reach it, accounts, hardware, storage, rules and
quirks) plus a page on the network between them. The pages are age-encrypted in
[dot_agents/skills/private_machines](dot_agents/skills/private_machines) and
decrypted to `~/.agents/skills/machines` on apply, so they exist only where the
key is. `machine` prints the path of the current machine's page.

## Installed tools

Tools come from pixi in named bundles.
[.chezmoidata/tools.toml](.chezmoidata/tools.toml) defines the bundles; each
machine selects the ones it wants:

| bundle | contents |
| --- | --- |
| `core` | shell, editor, navigation — every machine, including a login node |
| `dev-c` `dev-py` `dev-web` `dev-tex` | per-language build and format tooling |
| `lsp` | language servers and the binaries Neovim's plugins call |
| `media` | audio, video and image conversion |
| `ml` | model and dataset transfer |
| `secrets` | age, sops, Bitwarden client |
| `extras` | convenience and diagnostics; nothing load-bearing |

`~/.pixi/manifests/pixi-global.toml` is **generated** from `tools.toml` and
`machines.toml`, so add a package to a bundle and run `chezmoi apply`. A
`pixi global install` by hand is undone by the next apply.

`pixi global sync` makes a machine match the manifest exactly, so dropping a
bundle from a machine uninstalls its tools.

Each package gets its own environment, and `exposed` is listed explicitly, so
one dependency conflict cannot break a whole bundle and conda-forge runtimes
(`node`, `openssl`, `python3.14`, `tclsh`, `wish`) stay off `PATH`.

## Secrets

This repository is public, so anything secret in it is age ciphertext:
`encrypted_*` is decrypted on apply and the key is never committed.

Encryption is **on**. `.chezmoidata/secrets.toml` holds the recipient; the
identity lives at `~/.config/chezmoi/key.txt`, with a copy in Bitwarden so a new
machine can fetch it once. [docs/secrets.md](docs/secrets.md) has the design and
the commands.

Two things are encrypted: `~/.ssh/config`, and the machine pages of the
`machines` agent skill. A pre-commit hook refuses a commit that would put
plaintext where either lives, and on a machine with the key `git diff` shows
both decrypted.

[.chezmoidata/machines.toml](.chezmoidata/machines.toml) is deliberately in the
clear: bundles, roles and filesystem layout are not secrets. Addresses, account
names and tokens are.

## Outstanding

[docs/todo.md](docs/todo.md).
