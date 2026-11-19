# dotfiles

Managed with [chezmoi](https://www.chezmoi.io/). This repository is the chezmoi
*source* tree, so files here carry chezmoi's naming: `dot_zshrc` becomes
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

Checked on 2026-11-19. The unified `dotfiles` CLI (built in Rust under
[cli/](cli/Cargo.toml), with a zero-dependency Python fallback at
`~/.local/bin/dotfiles`) wraps daily operations, dynamic Zsh tab completion
(via `fzf-tab`), and an interactive Ratatui TUI:

```sh
dotfiles                            # interactive Ratatui TUI (5 tabs + live Theme Studio)
dotfiles doctor [--json]            # host health, drift, secrets, toolchain, agents and sandbox
dotfiles sync [--update] [--dry-run] # chezmoi apply/update bypassing the metered proxy
dotfiles theme [variant]            # switch or preview colour theme across tools
dotfiles fetch <status|sync|outdated|update>
dotfiles jail [options] -- <cmd>    # run any command inside agent-jail
dotfiles agent <skills|status>
dotfiles check                      # pre-commit + full tests/ suite via `mise run check`
dotfiles completion <zsh|bash|fish> # cached automatically on fpath in zsh
```

Raw `chezmoi` commands work directly as well:

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
target: `.chezmoidata/*.toml`, `.chezmoiignore`, `.chezmoiexternal.toml`, `cli/`,
`tests/`, and `mise.toml` are read by chezmoi or development tooling and never
deployed. Reach them through the source tree:

```sh
chezmoi cd                                              # then edit normally
$EDITOR "$(chezmoi source-path)/.chezmoidata/machines.toml"
chezmoi edit-config-template                            # the config template
```

## Git configuration and diffs

Shared Git defaults live in `~/.config/git/config` (`histogram` diffs, `zdiff3`
conflict style, `rerere`, `pull.rebase`, `fetch.prune`, `push.autoSetupRemote`,
and global excludes in `~/.config/git/ignore`). Machine-local identity
(`user.name`, `user.email`), credential helpers, and overrides stay in
`~/.gitconfig` (which Git reads after `~/.config/git/config`) or
`~/.config/git/config.local`.

Native unified `git diff` stays the default so coding agents, patch tools, and
this repository's `.age` text-conversion driver work without extra flags. Opt
into Difftastic via aliases or `lazygit`:

```sh
git diff                     # standard unified diff and .age textconv
git dft                      # Difftastic working-tree diff
git dfts                     # Difftastic staged diff
git dshow                    # Difftastic commit diff
git dlog                     # Difftastic patch history
```

## Themes

```sh
dotfiles                       # open the TUI Theme Studio (Tab 2) for truecolor live preview
dotfiles theme rose-pine-dawn  # switch everywhere and apply (`theme` alias works too)
theme --dry-run catppuccin-mocha
```

One switch covers btop, kitty, tmux, Neovim, zathura, fzf, starship and Herdr
(plus the `dotfiles` TUI itself). Variants use the slug upstream uses.

Zathura starts with recolouring off on every variant, so documents keep their
own colours; `Ctrl+R` turns it on in the open window.

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
`catppuccin_mocha` to btop and `mocha` to kitty.

Theme files are fetched to a fixed name —
`~/.config/btop/themes/current.theme`,
`~/.config/kitty/current-theme.conf` — so nothing is vendored per variant.
Starship is the exception: it has no include mechanism, so
`~/.config/starship.toml` is rendered from
[a template](private_dot_config/starship.toml.tmpl) with the palette inlined
from `[themes.<slug>.starship]`.

`appearance` is the fallback for a tool with no port for a scheme, and the one
field every variant has.

To restyle another tool, add a key to each scheme file and reference it from
that tool's template. Never hard-code a variant name in a config file.

## Context and 4-agent control plane

Checked on 2026-11-19. Four primary coding agents share one declarative control
plane in [agents.toml](.chezmoidata/agents.toml) and one security policy in
[policy.toml](.chezmoidata/policy.toml): **Claude Code (`claude`)**, **Codex
(`codex`)**, **Antigravity CLI (`agy`)**, and **Pi (`pi`)**.

- **Shared instructions**: [private_dot_agents/AGENTS.md](private_dot_agents/AGENTS.md)
  holds user preferences for every project. It deploys to `~/.agents/AGENTS.md`
  and links to `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/AGENTS.md`,
  and `~/.pi/agent/AGENTS.md` on `agent-tools` machines.
- **Shared skills**: `~/.agents/skills/` is read directly by Pi and symlinked
  for Claude Code, Codex, and Antigravity CLI (`~/.gemini/config/skills/`). See
  [Shared agent skills](private_dot_agents/skills/README.md).
- **Non-destructive reconciliation**: `dot_local/libexec/dotfiles/executable_agent-reconcile.py`
  merges shared privacy defaults (`claude_profile` in `chezmoi.toml`, Codex
  `[otel]`), `gh` rules, MCP servers, `key-guard.py` (`PreToolUse`),
  `agent-notify.py` (`Stop`), and Pi settings/packages into each agent's native
  config on `chezmoi apply` while preserving local auth, sessions, and Herdr hooks.
- **Default OS sandboxing (`agent-jail`)**: Interactive `zsh` and `bash` shells
  wrap `claude`, `codex`, `agy`, and `pi` in `agent-jail --wrap <agent>`
  (`bwrap` primary backend, rootless Linux Landlock fallback for `sicc`). Use
  `unjail <agent>` (or `DOTFILES_NO_JAIL=1`) to bypass when editing `~` (for
  example running `chezmoi apply`), and `DOTFILES_JAIL_RW=/path1:/path2` to add
  extra writable directories. See [docs/secrets.md](docs/secrets.md).

[AGENTS.md](AGENTS.md), which `CLAUDE.md` imports, is for an agent changing this
repository. It covers the source-versus-target model, the naming attributes, and
the rules that keep secrets out of a public repository.

The `machines` skill is for an agent working anywhere else. It carries a page per
machine (what it is for, how to reach it, accounts, hardware, storage, rules and
quirks) plus a page on the network between them. The pages are age-encrypted in
[private_dot_agents/skills/private_machines](private_dot_agents/skills/private_machines) and
decrypted to `~/.agents/skills/machines` on apply, so they exist only where the
key is. `machine` prints the path of the current machine's page.

## Pi and RTK

Workstation, laptop, imrl and sicc select `agent-tools`. The vps, container and
generic profiles do not. The bundle installs Pi and RTK through `mise` with
SHA-256 verification from `private_dot_config/mise/mise.lock`, plus Node/npm for
Pi extensions.

Checked on 2026-11-19. Pi is pinned to `1.5.2`, and RTK to `1.0.0`, in
[mise.toml](.chezmoidata/mise.toml). To upgrade or roll back, change the version
there, run `mise run lock-tools`, and run `chezmoi apply` on each target. Do not
use `pi update` to update the dotfiles-managed executable.

```sh
command -v pi rtk              # ~/.local/share/mise/shims on a new shell
pi --version
rtk --version
mise ls
```

Pi loads `~/.pi/agent/AGENTS.md` and discovers `~/.agents/skills` natively.
[agents.toml](.chezmoidata/agents.toml) defines the unified control plane for
Claude Code, Codex, Antigravity CLI (`agy`), and Pi — including Pi's shared
startup settings, `pi-subagents` global-context inheritance (`inheritGlobalContext: true`
plus `defaultSubagentOnlyExtensions` for `dotfiles-guard.ts`), and pinned
packages (`pi-openai-toolkit`, `pi-ask-user`, `pi-subagents`).
`dot_local/libexec/dotfiles/executable_agent-reconcile.py` merges those values
into each agent's native config while preserving local settings, sessions,
credentials, Herdr hooks, and unrelated packages.

Each apply checks installed Pi package versions after `mise` installs `pi`.
Matching versions need no network request. Missing or mismatched packages
install through the managed Pi. Failed installations warn and retry on the next
apply. Change shared package versions in `.chezmoidata/agents.toml`, not
through `pi update --extensions`. Package installation and startup repairs clear
the proxy variables.

`pi-subagents` enables delegated tasks when you request them. Installation does
not start a reviewer or authorize automatic delegation. Run `/subagents-doctor`
to check setup and `/subagents-fleet` to inspect active work. Builtin subagents
are configured via `subagents.agentOverrides` in `.chezmoidata/agents.toml` to
inherit both project and global `AGENTS.md` context and load `dotfiles-guard.ts`.

New sessions default to `openai-codex/gpt-6.1-sol` with `xhigh` thinking.
[Toolkit configuration](private_dot_pi/private_agent/extensions/pi-openai-toolkit/config.json)
enables remote compaction for the `openai-codex-responses` API, including new
Codex model IDs. Other APIs use Pi's native compaction. Remote failure can fall
back to a text summary, so a completed `/compact` is not proof of a checkpoint.
Search remains unmanaged. Image generation and Toolkit WebSocket transport stay
off.

Authenticate separately on each machine with `/login openai-codex`. Credentials,
sessions, device IDs, caches and unrelated extensions remain local. Existing
sessions keep their model selection. To check a new session, run
`/toolkit-config validate`, then test `/compact` after a few turns.

RTK is available for explicit commands, such as `rtk git status`. This bundle
does not install RTK hooks, change telemetry consent, or enable automatic
filtering. Existing RTK integrations stay unchanged.

Manual installations remain in place as fallbacks. New bash and zsh shells put
the managed downloads before those copies. Downloads bypass the metered AI
proxy. If a target cannot reach an upstream directly, transfer the verified
archives or resolve network access before deployment. Do not use the proxy
without explicit approval.

## Antigravity CLI

Checked on 2026-11-19. `agent-tools` installs Antigravity CLI (`agy`) from its
per-platform release `manifest` in [downloads.toml](.chezmoidata/downloads.toml),
linking `~/.local/opt/dotfiles/bin/agy` to the downloaded `antigravity` binary.
`~/.config/dotfiles/env.sh` exports `AGY_CLI_DISABLE_AUTO_UPDATE=true` so
background self-updates do not replace the managed payload; upgrade through
`dotfiles fetch update agy`. Interactive sessions default to
`--dangerously-skip-permissions` inside `agent-jail`, while `key-guard.py`
(`PreToolUse`) hard-denies secret reads and `agent-notify.py` handles `Stop`
notifications. Shared context comes from `~/.gemini/AGENTS.md` and
`~/.gemini/config/skills/`, linked by `agent-skills.sh`. `agent-reconcile.py`
merges hooks and declared MCP servers into `~/.gemini/config/hooks.json` and
`~/.gemini/config/mcp_config.json` while preserving Herdr and local entries.

## Herdr

The workstation, laptop, imrl and sicc select the `herdr` bundle for coding agents.
Start `herdr` in a project directory. The shared `herdr` skill teaches agents to
control panes when asked.

`theme` selects a supported Herdr palette, preserving light or dark appearance,
and reloads the running session when available. It owns the `[theme]` section of
Herdr's config; other settings are preserved.

| Dotfiles variants | Herdr palette |
| --- | --- |
| `rose-pine`, `rose-pine-moon` | `rose-pine` |
| `rose-pine-dawn` | `rose-pine-dawn` |
| `catppuccin-frappe`, `catppuccin-macchiato`, `catppuccin-mocha` | `catppuccin` |
| `catppuccin-latte` | `catppuccin-latte` |

Herdr may add more built-in variants. When it does, update each variant's
`herdr` token in `.chezmoidata/themes-*.toml`.

Checked on 2026-10-04 with Herdr 0.9.3 and Codex 0.160.0. Codex commands can lose
the pane's inherited `HERDR_*` variables, preventing agents from using the skill.
The cause is unresolved.

## Installed software

A machine's `bundles` in [machines.toml](.chezmoidata/machines.toml) decide
everything it gets. Each bundle in [tools.toml](.chezmoidata/tools.toml) can
name four kinds of thing: pixi `packages` (conda-forge / HPC strongholds),
`mise` tools from [mise.toml](.chezmoidata/mise.toml) locked in
`private_dot_config/mise/mise.lock`, `downloads` from
[downloads.toml](.chezmoidata/downloads.toml) for GUI bundles, fonts, `.xpi`
plugins and `agy`, and `config` paths that only a machine selecting it receives.

| bundle | contents |
| --- | --- |
| `core` | `zsh`, `mosh`, `sqlite`, `chezmoi`, `mise`, plus 22 locked CLIs (`dotfiles`, `nvim`, `tmux`, `fzf`, `rg`, `fd`, `eza`, `yazi`, `starship`, `zoxide`, `lazygit`, `difft`, `sheldon`, `pre-commit`, `gitleaks`, ...) — every machine |
| `dev-c` `dev-py` `dev-web` `dev-tex` | per-language build and format tooling |
| `lsp` | language servers and the binaries Neovim's plugins call |
| `media` | audio, video and image conversion |
| `ml` | model and dataset transfer |
| `secrets` | age, sops, Bitwarden client |
| `github` | the GitHub CLI; every machine except the vps |
| `extras` | convenience and diagnostics, including `tre`; nothing load-bearing |
| `desktop` | kitty, the Maple Mono NF CN terminal font, and the GUI programs' config |
| `fonts` | eighteen more document, slide, design, math, CJK and emoji families |
| `research` | Zotero, pinned Better BibTeX, and pinned Extra Meta |
| `agent-tools` | locked Codex, Claude Code, Pi, RTK, Node (`mise`), Antigravity CLI (`agy`), and shared 4-agent control plane, on every computing machine except the vps |
| `herdr` | terminal workspaces for coding agents on workstation, laptop, imrl and sicc |
| `vpn` | um-vpn, the university VPN client, which pixi builds from its repository |
| `laptop` | a user service that drops the panel to 60 Hz on battery |

To add software, add it to a bundle and run `chezmoi apply`.

**Packages.** `~/.pixi/manifests/pixi-global.toml` is generated, and
`pixi global sync` makes the machine match it exactly, so a `pixi global
install` by hand is undone by the next apply and dropping a bundle uninstalls
its tools. Each package gets its own environment, and `exposed` is listed
explicitly, so one dependency conflict cannot break a whole bundle and
conda-forge runtimes (`node`, `openssl`, `python3.14`, `tclsh`, `wish`) stay off
`PATH`.

**Locked CLIs, runtimes, LSPs, and agents (`mise`).** `mise` is the primary
manager for cross-platform CLIs, language runtimes (`node`, `pnpm`, `deno`,
`uv`, `ruff`, `ty`), language servers, and coding agents (`codex`,
`claude-code`, `pi`, `rtk`, `herdr`, plus `dotfiles-cli`). chezmoi renders
`~/.config/mise/config.toml` from each machine's selected `mise` entries
alongside the shared multi-arch `~/.config/mise/mise.lock` (`linux-x64` and
`linux-arm64`), and runs `mise install --locked`, `mise reshim`, and
`mise prune --yes`. Shims live in `~/.local/share/mise/shims`. To upgrade a
tool, update its version in `.chezmoidata/mise.toml`, run `mise run lock-tools`,
and apply. `pixi global` stays minimal for conda-forge / HPC ABI strongholds
(`zsh`, `mosh`, `ffmpeg`, `sqlite`, `clang-tools`, `rbw`, `libsecret`,
`huggingface_hub`, `um-vpn`).

**Downloads.** chezmoi renders the selection into
`~/.config/dotfiles/downloads.json` and runs `dotfiles-fetch sync` whenever it
changes. chezmoi never downloads these itself, so `chezmoi diff` and `cat` stay
fast and work offline. `dotfiles-fetch` installs only under names of its own:

| what | where |
| --- | --- |
| applications, one directory per version | `~/.local/opt/dotfiles/<id>/` |
| their commands, on `PATH` before `mise` and `pixi` | `~/.local/opt/dotfiles/bin/` |
| fonts | `~/.local/share/fonts/dotfiles/<id>/` |
| launchers | `~/.local/share/applications/dotfiles-*.desktop` |

A kitty, Zotero or font installed some other way is never touched, so there is
nothing to adopt or back up. The one shared path is `~/.terminfo`, where kitty's
entry is written only if missing, the same files `kitten ssh` writes on a
remote machine. Removing a download from a bundle removes what it installed.

Unpinned downloads keep their installed version until you request an update.
A GitHub download with a catalog `tag` follows that pin on every sync, including
upgrades and rollbacks. Updating is a decision, as with `sheldon lock --update`:

```sh
dotfiles-fetch status          # what is selected and installed; offline
dotfiles-fetch outdated        # GitHub releases newer than what is installed
dotfiles-fetch update [id...]  # latest release, or the catalog tag when pinned
```

GitHub releases are verified against committed catalog `sha256` digests (required
for pinned tags) and GitHub's published release digests. Zotero's built-in updater
is disabled, since `dotfiles-fetch update` replaces the application. A download
with no build for the machine's platform is skipped with a warning.

Kitty, Zotero and the fonts that `setup.d/typefaces.sh` installed before this
lived at shared paths. `dotfiles-fetch migrate` lists the font directories that
script wrote, and `--apply` deletes them; it only reports the rest.

**Config.** The `config` paths of every bundle a machine does not select go into
`.chezmoiignore`. Zathura and Fcitx5 come from the distribution; `desktop`
supplies only their configuration. A machine that drops a bundle keeps the files
it already has, the way an application keeps its profile.

### Zotero, Better BibTeX and Extra Meta

Checked on 2026-11-19 with Zotero 10.0.6, Better BibTeX 9.0.71 and Extra Meta 0.1.7.
The `research` bundle pins both Better BibTeX and
[Extra Meta](https://github.com/xiaosq2000/zotero-extra-meta) (`extra-meta@dotfiles.local`)
in `.chezmoidata/downloads.toml`. `dotfiles-fetch` downloads both `.xpi` release
assets and checks their published digests. An apply installs both plugins in the
default Zotero profile and leaves identical installations unchanged. If Zotero is
running, an install or upgrade waits until you close Zotero and run
`chezmoi apply` again. It saves replaced plugins in
`~/.local/state/dotfiles/zotero-plugins/` (pruning to the five newest backups).
It will not downgrade a newer installation or replace an existing plugin symlink.

On a new profile, open Zotero and enable Better BibTeX and Extra Meta in the plugin
manager. For Better BibTeX, set automatic updates to Off in the plugin's settings on
each machine so Zotero does not change the pinned version. To upgrade Better BibTeX,
update the catalog pin, check plugin compatibility and apply on each machine.

The bundle shares Better BibTeX preferences and `extensions.startupScanScopes`
(`1`, so Zotero discovers sideloaded plugins in `extensions/` on startup)
through `~/.config/dotfiles/zotero-user.js`. An apply links the profile's
`user.js` to that file. Zotero reads it at startup. If a `user.js` already
exists, apply leaves it unchanged and warns. Open Zotero once and apply again
if the profile does not exist yet.

Edit `private_dot_config/dotfiles/zotero-user.js.tmpl`, apply it, and restart
Zotero to change a shared preference. The template sets the key formula once
for both the active and editable fields. A change made in Zotero to a shared
preference lasts only until Zotero restarts. Machine paths, auto-export jobs,
migration state, generated character maps and debug settings stay local. Check
new preferences when upgrading Better BibTeX.

Zotero syncs the native Citation Key field with each item. Changing the shared
key formula does not refresh existing keys. Do not refresh keys used by papers
without updating their citations. To stop applying the shared settings, remove
the profile's `user.js` link. Zotero retains the last loaded values in its own
preferences, so change them in Zotero if needed.

## Checks

Checked on 2026-11-19. [CI](.github/workflows/ci.yml) has three jobs, plus
[release-cli.yml](.github/workflows/release-cli.yml) for `cli-v*` static musl
releases (`linux-amd64` and `linux-arm64`):

| Job | Scope |
| --- | --- |
| `checks` | Pre-commit hooks (except local Gitleaks) plus `tests.test_suite.UnitChecks` |
| `cli` | `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `zsh -n` on generated completions |
| `smoke` | `tests.test_suite.ChezmoiChecks` plus clean no-key `container` apply and verify |

CI skips external theme downloads. It does not enforce specific package versions,
key bindings, colours, or other configuration choices.

Run the unified CLI and full local test suite:

```sh
dotfiles doctor                     # host health, drift, tools, agents and sandbox
dotfiles doctor --json              # machine-readable report
mise run check                      # pre-commit + full tests/ suite (unittest/pytest)
mise run cli-check                  # Rust clippy + unit tests for cli/
mise run build-cli                  # build release Rust CLI locally into ~/.local/opt/dotfiles/bin
python3 -m unittest discover -s tests -v
```

The chezmoi test group requires chezmoi, Python 3.11+, bash, zsh, and ShellCheck.
Individual test modules under `tests/` remain directly executable for targeted
checks.

`python3 tests/check_fetch.py --live` installs the real catalog in a temporary
home. It downloads a few gigabytes. Run it manually without the proxy when
testing upstream downloads. CI uses local fixtures only.

## System files

Files outside `~`, such as scripts in `/usr/local/sbin`, systemd units and udev
rules, live in `system/<machine>/` at their paths under `/`.
`.chezmoiscripts/run_after_80-system-files.sh.tmpl` installs the ones that
differ, as root, and never asks for a password: without cached sudo it lists
them and the next apply tries again. To install:

```sh
sudo -v && chezmoi apply
```

It reloads systemd and udev and enables installed units, but restarts nothing.
Deleting a file from `system/` leaves the installed copy in place.

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

All four primary coding agents (`claude`, `codex`, `agy`, `pi`) are protected by
two complementary layers — default OS-level `agent-jail` (`bwrap` / Landlock)
plus `key-guard.py` hooks and native rules — and pre-commit/pre-push hooks
refuse commits containing secrets.
[docs/secrets.md](docs/secrets.md#keeping-agents-away-from-private-keys) lists
what each layer enforces and its boundaries.

[.chezmoidata/machines.toml](.chezmoidata/machines.toml) is deliberately in the
clear: bundles, roles and filesystem layout are not secrets. Addresses, account
names and tokens are.

## Outstanding

[docs/todo.md](docs/todo.md).
