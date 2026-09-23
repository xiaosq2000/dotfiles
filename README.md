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

Needs `curl`, `git`, `unzip` and Python 3. Desktop bundles install the terminal
font; a remote machine uses the font of the terminal you connect from. `zsh` is not a prerequisite; without root,
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
target: `.chezmoidata/*.toml`, `.chezmoiignore` and `.chezmoiexternals/*` are
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

A machine's `bundles` list selects its software and desktop configuration.
[tools.toml](.chezmoidata/tools.toml) lists Pixi packages and named external
resources; [downloads.toml](.chezmoidata/downloads.toml) describes each external
once, including its upstream, archive layout, and owned paths.

| bundle | contents |
| --- | --- |
| `core` | shell, editor, navigation and Kitty terminfo for local or remote sessions |
| `dev-c` `dev-py` `dev-web` `dev-tex` | per-language build and format tooling |
| `lsp` | language servers and the binaries Neovim's plugins call |
| `media` | audio, video and image conversion |
| `ml` | model and dataset transfer |
| `secrets` | age, sops, Bitwarden client |
| `extras` | convenience and diagnostics, including the upstream `tre` binary |
| `desktop` | Kitty, Maple Mono NF CN and GUI configuration |
| `fonts` | fourteen additional document, design, CJK and emoji families |
| `research` | Zotero and its launcher |

Workstation and laptop select all three desktop-related bundles. Headless
machines receive no GUI configuration or desktop downloads. Alacritty, Zathura,
Fcitx and desktop services remain system-installed; `desktop` supplies their
configuration. Removing that bundle preserves existing application settings.
Download resources currently support Linux x86-64; selecting one on an
unsupported platform fails before installation.

Pixi owns the generated global manifest, with a separate environment for each
package and explicitly exposed commands. Add a package to a bundle and apply;
a manual `pixi global install` is undone by the next manifest synchronization.
Rust toolchains are managed separately; `tre` uses an upstream binary.

chezmoi owns downloadable apps and fonts through native externals. Kitty stays
in `~/.local/kitty.app`, Zotero in `~/.local/zotero`, and fonts in named directories
under `~/.local/share/fonts`. A font family directory belongs entirely to its
resource. Put unrelated fonts in a separate directory.

On first adoption, existing payloads and launchers are copied to
`~/.local/state/dotfiles/backups/<resource>/`. The original backup is retained
across subsequent applies. Successful installation records ownership under
`~/.local/state/dotfiles/downloads/`. Deselecting a resource removes its recorded
payload and integration files, preserving profiles, Zotero libraries and other
manual installations. A resource that has never been adopted is left alone.
Keep resource IDs and owned paths stable; changing them needs an explicit
migration. To restore a pre-adoption copy, first deselect the resource and apply,
then copy the saved paths back from its backup directory.

Downloads follow stable releases where upstream provides release assets. Font
repositories without assets follow their existing branches; TeX Gyre Pagella
uses GUST's published versioned URL. Archive downloads are cached, moving URLs
refresh after four weeks, and GitHub release metadata is cached for one day.
Zotero's built-in updater is disabled so it does not compete with
chezmoi over the installed application.

```sh
chezmoi diff
chezmoi apply
chezmoi verify
```

To check all releases and refresh downloads immediately:

```sh
chezmoi state delete-bucket --bucket=gitHubLatestReleaseState
chezmoi apply --refresh-externals
```

Lifecycle scripts live in `.chezmoiscripts/`. They handle Pixi synchronization,
pnpm configuration, adoption backups, cache refreshes and agent integration.
Download and extraction logic belongs to chezmoi. `verify` excludes scripts in
the generated config because cache refreshes run on every apply; it still checks
all managed destination files. Run `chezmoi init` after updating an existing
checkout to regenerate the verification and release-cache settings.

Routine CI uses small local archives to exercise adoption, updates, removal and
reinstallation. A manual CI run also checks every real upstream font and app;
locally, run `python3 .github/scripts/check-software.py --live`. It creates a
disposable home, downloads the collection and needs several gigabytes of space.

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
