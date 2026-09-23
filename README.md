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

Needs `curl`, `git` and `unzip`, and Python 3 on a machine whose bundles select
downloads. The `desktop` bundle installs the terminal font; a remote machine
uses the font of the terminal you connect from. `zsh` is not a prerequisite;
without root, `pixi global install zsh` puts one in your home directory — see
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
[agent-plugins.sh](dot_local/libexec/dotfiles/executable_agent-plugins.sh) installs it wherever
`claude` or `codex` is on PATH, and does nothing where neither is, so it is not
gated on the machine's bundles.

Installing changes nothing by itself, which is the point. The skill is opt-in on
both agents, so neither model can reach for it unasked and `chezmoi update` does
not quietly change how a machine's agents talk.

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

## Installed software

A machine's `bundles` in [machines.toml](.chezmoidata/machines.toml) decide
everything it gets. Each bundle in [tools.toml](.chezmoidata/tools.toml) can
name three kinds of thing: pixi `packages`, `downloads` from
[downloads.toml](.chezmoidata/downloads.toml) for software conda-forge does not
package, and `config` paths that only a machine selecting it receives.

| bundle | contents |
| --- | --- |
| `core` | shell, editor, navigation — every machine, including a login node |
| `dev-c` `dev-py` `dev-web` `dev-tex` | per-language build and format tooling |
| `lsp` | language servers and the binaries Neovim's plugins call |
| `media` | audio, video and image conversion |
| `ml` | model and dataset transfer |
| `secrets` | age, sops, Bitwarden client |
| `extras` | convenience and diagnostics, including `tre`; nothing load-bearing |
| `desktop` | kitty, the Maple Mono NF CN terminal font, and the GUI programs' config |
| `fonts` | fourteen more document, design, CJK and emoji families |
| `research` | Zotero |

To add software, add it to a bundle and run `chezmoi apply`.

**Packages.** `~/.pixi/manifests/pixi-global.toml` is generated, and
`pixi global sync` makes the machine match it exactly, so a `pixi global
install` by hand is undone by the next apply and dropping a bundle uninstalls
its tools. Each package gets its own environment, and `exposed` is listed
explicitly, so one dependency conflict cannot break a whole bundle and
conda-forge runtimes (`node`, `openssl`, `python3.14`, `tclsh`, `wish`) stay off
`PATH`.

**Downloads.** chezmoi renders the selection into
`~/.config/dotfiles/downloads.json` and runs `dotfiles-fetch sync` whenever it
changes. chezmoi never downloads these itself, so `chezmoi diff` and `cat` stay
fast and work offline. `dotfiles-fetch` installs only under names of its own:

| what | where |
| --- | --- |
| applications, one directory per version | `~/.local/opt/dotfiles/<id>/` |
| their commands, on `PATH` after pixi's | `~/.local/opt/dotfiles/bin/` |
| fonts | `~/.local/share/fonts/dotfiles/<id>/` |
| launchers | `~/.local/share/applications/dotfiles-*.desktop` |

A kitty, Zotero or font installed some other way is never touched, so there is
nothing to adopt or back up. The one shared path is `~/.terminfo`, where kitty's
entry is written only if missing, the same files `kitten ssh` writes on a
remote machine. Removing a download from a bundle removes what it installed.

Versions stay where they were installed until you move them. Updating is a
decision, as with `sheldon lock --update`:

```sh
dotfiles-fetch status          # what is selected and installed; offline
dotfiles-fetch outdated        # GitHub releases newer than what is installed
dotfiles-fetch update [id...]  # move to the latest release and reinstall
```

GitHub releases are verified against the digest GitHub publishes. Zotero's
built-in updater is disabled, since `dotfiles-fetch update` replaces the
application. A download with no build for the machine's platform is skipped with
a warning; as of 2026-09-23 that is `tre` on linux-arm64.

Kitty, Zotero and the fonts that `setup.d/typefaces.sh` installed before this
lived at shared paths. `dotfiles-fetch migrate` lists the font directories that
script wrote, and `--apply` deletes them; it only reports the rest.

**Config.** The `config` paths of every bundle a machine does not select go into
`.chezmoiignore`. Alacritty, Zathura, Fcitx5 and kmonad come from the
distribution; `desktop` supplies only their configuration. A machine that drops
a bundle keeps the files it already has, the way an application keeps its
profile.

`.github/scripts/check-fetch.py` tests `dotfiles-fetch` against local fixtures
in seconds. With `--live` it installs the whole catalog from the real upstreams
into a disposable home, which takes a few gigabytes; CI runs that only when
started by hand.

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

Claude Code, Codex and opencode are kept from reading ssh private keys and the
age identity, and pre-commit hooks refuse a commit that contains either.
[docs/secrets.md](docs/secrets.md#keeping-agents-away-from-private-keys) lists
what each agent gets and what it does not stop.

[.chezmoidata/machines.toml](.chezmoidata/machines.toml) is deliberately in the
clear: bundles, roles and filesystem layout are not secrets. Addresses, account
names and tokens are.

## Outstanding

[docs/todo.md](docs/todo.md).
