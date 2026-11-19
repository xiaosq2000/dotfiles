# Dotfiles refactoring plan (late 2026)

Checked on 2026-11-19.

## Locked-in decisions

| Area | Decision |
| --- | --- |
| Primary coding agents | Codex, Claude Code, Antigravity CLI (`agy`), Pi |
| Retired tools & configs | Alacritty, KMonad, OpenCode, Aider, `.condarc`, all of `dot_sh_utils/tools/` (35 functions) |
| Toolchain consolidation | Adopt `mise` + committed `mise.lock` for cross-platform CLIs and repo tasks; keep `pixi global` for conda-forge / HPC strongholds (`zsh`, `um-vpn`, `ffmpeg`, `huggingface_hub`, C++/LSP) |
| `zotero/extra-meta` | Extract to standalone repo `xiaosq2000/zotero-extra-meta` with GitHub Release `.xpi` assets |
| Shell history & navigation | Add `zoxide`; skip `atuin` for now |
| Agent sandboxing | Ship `agent-jail` (`bwrap`/Landlock) as opt-in first alongside 4-agent native hooks/permissions; promote to default after daily burn-in |
| Proxy routing | Align dotfiles and agent rules with `sbc`'s modern split-routing rules |

## Execution rules

- Develop each wave in a sibling worktree beside the source tree (`../chezmoi-wave-<n>`), never inside `~/.local/share/chezmoi`.
- Verify offline with `chezmoi --source "$PWD" diff` and repo checks before merging to `main`.
- Roll out across machines in canary order: `container` (CI) → `workstation` → `laptop` → `imrl` → `sicc` → `vps`.
- Keep unmanaged host leftovers (for example `~/.local/kitty.app`, `/opt/zotero`, old `opencode`/`alacritty` installs) untouched until the wave stabilizes; offer cleanup explicitly afterward.

## Waves

### Wave 0 — Clean slate, retirements, and P0 hardening

- **PR 0A (dotfiles repo)**:
  - Retire `alacritty`, `kmonad`, `opencode`, `aider`, `.condarc`, `dot_sh_utils/tools/`, and dead shell helpers; add retired managed paths to `.chezmoiremove`; ignore `.agents/`, `.aws/`, `.claude/`, `.codex/` in `.gitignore`.
  - Add `private_` (`0700`/`0600`) to all 4 agent directories/configs and gate `.claude`/`.codex`/`.gemini`/`.pi` under `agent-tools`.
  - Patch all verified `key-guard.py` bypasses, expand protected credential targets, remove `@~/.codex/RTK.md` from shared `AGENTS.md`, and make `ste-lint.py` executable.
  - Fix P0 bugs: `dot_latexmkrc` (drop global `--shell-escape` and `$HOME/scripts`, gate under `dev-tex`), `power-tunables.service` (drop `RemainAfterExit=yes`), `kitty.conf.tmpl` (slim to ~50 active lines, `socket-only`, add `~/.pixi/bin` to `exe_search_path`), `basics.sh` (drop global `LD_LIBRARY_PATH`, fix `MANPATH`), `dot_zshrc` (drop `.tmpl`, fix TeX `INFOPATH`/`MANPATH`, `dircolors` order, `xclip`, `TERM=dumb` starship guard, `chezmoi edit` aliases, `$EPOCHREALTIME`), Neovim (`0.13` `ui2` guard, `lualine`, `folding`, `kitty_scrollback` gating, `vimtex` scoping, `clangd`, `bashls`), `refresh-rate-on-power`, `zathura`, `zotero-user.js.tmpl`, and `zotero/extra-meta/bootstrap.js`.
  - Convert `95-pi-packages` and `96-zotero-profile` to `run_onchange_after_` with empty-output gating to restore `chezmoi verify` without `--exclude scripts`; reorder `agent-skills` after `90-downloads` with `--prune`; wire orphaned tests and all-theme checks into CI.
- **PR 0B (separate repo)**:
  - Extract `zotero/extra-meta` + tests into `xiaosq2000/zotero-extra-meta`, publish `.xpi` release, consume it like `better-bibtex`, and drop Node.js from dotfiles CI.

### Wave 1 — `sbc` split-routing & toolchain convergence (`mise` + `pixi`)

- Audit and align `sbc route` split rules for package registries/downloads; simplify proxy-bypass wording in `AGENTS.md` and provisioning scripts.
- Introduce `mise` + committed `mise.lock` (SHA-256 locked) for cross-platform CLIs (`gitleaks`, `pi`, `rtk`, `herdr`, `tre`, `kitty`, `stylua`, `shfmt`, `prettierd`, `zoxide`) and repo tasks (`mise run check`).
- Trim `pixi global` to conda-forge / HPC strongholds (`zsh`, pinned `um-vpn`, `ffmpeg`, `huggingface_hub`, C++/LSP).
- Shrink `dotfiles-fetch` to a minimal SHA-256-verified asset/font/Zotero helper (fixing `version` containment and atomic swap, replacing unverified floating personal font repos).

### Wave 2 — Dual-mode shell contract & modern Git / Tmux / Starship

- Extract a silent POSIX `~/.config/dotfiles/env.sh` shared by `.zshenv`, `.profile`, `BASH_ENV`, and `environment.d` so non-interactive agent/SSH shells (both `zsh -c` and `bash -c`) get deterministic `PATH` and telemetry-off env vars (`PI_TELEMETRY=0`, `RTK_TELEMETRY_DISABLED=1`, `AGY_CLI_DISABLE_AUTO_UPDATE=true`).
- Simplify `dot_bashrc` to a minimal fallback; add `zoxide` to `dot_zshrc`; move Wayland `xhost` into a systemd user oneshot.
- Manage `~/.config/git/config` + local include (`histogram`, `zdiff3`, `rerere`, `pull.rebase`, `fetch.prune`, `push.autoSetupRemote`, SSH signing, global excludes); stop setting global `diff.external = difft` (use `git dft` + `lazygit` so agents and `.age` textconv stay intact).
- Modernize `tmux.conf` (portable zsh, `tmux-256color`, OSC 52, `theme` integration, drop `send-keys` hack) and `starship.toml.tmpl` (add `[pixi]`, drop unused languages and `surface`).

### Wave 3 — 4-Agent unified control plane (`.chezmoidata/agents.toml`)

- Declare shared privacy/telemetry defaults, MCP server registry (per-bundle, secrets via `rbw`/env), command approval rules, and desktop/terminal notification hook (`agent-notify`) in `.chezmoidata/agents.toml`.
- Compile/reconcile from one Python 3.10+ reconciler across Claude Code, Codex, Antigravity CLI (`~/.gemini/config/hooks.json`, `mcp_config.json`), and Pi (local extension + `pi-subagents` `inheritGlobalContext: true`).
- Retire imperative `ai-privacy` (move Claude `strict`/`remote-control` profile into `chezmoi.toml` data) and pin or vendor `i-have-adhd`.
- Tighten `herdr/SKILL.md` into a concise table with explicit-invocation metadata.

### Wave 4 — OS-level capability sandbox (`agent-jail`) & unified security policy

- Consolidate protected paths and allowlists into `.chezmoidata/policy.toml` shared by `agent-jail`, multi-protocol `key-guard` (Claude/Codex + `agy` JSON + Pi extension), and git secret hooks.
- Implement opt-in `agent-jail` (`bwrap` with Landlock fallback for rootless HPC) mounting workspace RW and masking SSH private keys, age identity, `~/.secrets`, cloud/CLI/agent auth files while exposing `SSH_AUTH_SOCK`.
- Complete Codex `/hooks` trust across hosts and transition SSH private keys to passphrase or FIDO2 (`ed25519-sk`).

### Wave 5 — Unified `dotfiles` CLI, `pytest` suite, and 5-machine rollout

- Unify `machine`, `theme`, `agent`, `bootstrap`, and `doctor --json` under `dotfiles` CLI (keeping compatibility symlinks).
- Consolidate `.github/scripts/check-*.py` into `tests/` (`pytest`) invoked identically locally and in CI via `mise run check`.
- Complete canary rollout across all 5 machines (`dotfiles doctor` + `chezmoi verify` green) and offer optional host cleanup.
