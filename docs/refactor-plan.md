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

### Wave 0 — Clean slate, retirements, and P0 hardening (Done on 2026-11-19)

- **PR 0A (done)**: Retired `alacritty`, `kmonad`, `opencode`, `aider`, `.condarc`, `dot_sh_utils/tools/`, hardened agent permissions (`private_`) and `key-guard.py`, fixed P0 bugs across `dot_latexmkrc`, `power-tunables.service`, `kitty.conf.tmpl`, `basics.sh`, `dot_zshrc`, Neovim, `refresh-rate-on-power`, `zathura`, restored `chezmoi verify`, and wired CI checks.
- **PR 0B (done)**: Extracted `zotero/extra-meta` to public repo `xiaosq2000/zotero-extra-meta` (`v0.1.7`), switched dotfiles to consume its GitHub Release `.xpi` via `dotfiles-fetch`, and removed Node.js from dotfiles CI.

### Wave 1 — `sbc` split-routing & toolchain convergence (`mise` + `pixi`) (Done on 2026-11-19)

- Aligned `private_dot_agents/AGENTS.md` with `sbc route` split modes (`ai-only`/`gfw-proxy` vs `china-direct`/`global`) while stripping metered proxy vars defensively in `05-pixi`, `06-sheldon`, `07-mise`, and `agent-plugins.sh`.
- Introduced `mise` + committed multi-arch `private_dot_config/mise/mise.lock` (`linux-x64` & `linux-arm64`, SHA-256 + `aube` locked) for 9 cross-platform CLIs (`gitleaks`, `zoxide`, `stylua`, `shfmt`, `prettierd`, `tre`, `herdr`, `pi`, `rtk`) and root `mise.toml` repo tasks (`check`, `render`, `fetch-test`, `secrets-test`, `lock-tools`).
- Trimmed `pixi global` (dropped unused conda `prettier`, pinned `um-vpn` to `rev`, added `mise`) and wired `zoxide` into `dot_zshrc`.
- Hardened `dotfiles-fetch` (safe version names, fail-closed digest requirement on pinned tags, committed `sha256` verification for Zotero `.xpi` plugins, crash-safe `.old` swap recovery, non-empty font dir checks) and kept it scoped to GUI bundles (`kitty`, `zotero`), `.xpi` plugins, `agy` manifest, and fonts.

### Wave 2 — Dual-mode shell contract & modern Git / Tmux / Starship (Done on 2026-11-19)

- Extracted silent POSIX `~/.config/dotfiles/env.sh` shared across `~/.zshenv`, `~/.bashrc` (before interactive guard), `modify_dot_profile`, `BASH_ENV`, and `~/.config/environment.d/999-dotfiles.conf` (beating Ubuntu's `99-environment.conf`), setting deterministic `PATH` and `PI_TELEMETRY=0` / `RTK_TELEMETRY_DISABLED=1` / `AGY_CLI_DISABLE_AUTO_UPDATE=true`.
- Slimmed `dot_bashrc` from 352 to ~100 lines as a clean fallback (with `zoxide` and `starship`) and moved Wayland `xhost` out of shell startup into `wayland-xhost.service` (gated under `desktop`).
- Managed `~/.config/git/config` + `~/.config/git/ignore` (`histogram`, `zdiff3`, `rerere`, `pull.rebase`, `fetch.prune`, `push.autoSetupRemote`, `git dft`/`dfts`/`dshow`/`dlog` aliases, local include); replaced global `diff.external = difft` with one-time cleanup `run_once_after_09-git-difftastic-cleanup.sh` so agents and `.age` textconv work natively.
- Modernized `tmux.conf.tmpl` (dynamic pixi/system zsh, `tmux-256color`, RGB/hyperlinks/usstyle, native OSC 52 clipboard, `update-environment`, removed dangerous `send-keys` `update_display.sh`) with native `current-theme.conf.tmpl` across all 7 themes + live reload in `theme`.
- Updated `starship.toml.tmpl` (added `[pixi]`, trimmed unused languages and unused `surface` palette key).

### Wave 3 — 4-Agent unified control plane (`.chezmoidata/agents.toml`) (Done on 2026-11-19)

- Consolidated shared privacy/telemetry defaults, MCP server registry, `gh` command rules (including `gh api` prompt), Pi settings/packages/subagent context inheritance, and hooks into `.chezmoidata/agents.toml` (replacing `.chezmoidata/pi.toml`).
- Implemented one Python 3.10+ reconciler (`dot_local/libexec/dotfiles/executable_agent-reconcile.py`) behind 6 thin `modify_*.tmpl` shims across Claude Code (`settings.json`), Codex (`config.toml`, `hooks.json`), Antigravity CLI (`~/.gemini/config/hooks.json`, `mcp_config.json`), and Pi (`settings.json` + `dotfiles-guard.ts` extension + `pi-subagents` `inheritGlobalContext: true` and `defaultSubagentOnlyExtensions`).
- Extended `key-guard.py` with native Antigravity CLI `PreToolUse` JSON protocol (`{"decision":"deny"}` / `{}` passthrough), added unified `agent-notify.py` completion hook across all 4 agents, retired imperative `ai-privacy` (Claude `strict`/`remote-control` via `chezmoi.toml` `[data].claude_profile`), pinned `i-have-adhd` to commit `1ecea1993b7f`, and compressed `herdr/SKILL.md` with `disable-model-invocation: true`.

### Wave 4 — OS-level capability sandbox (`agent-jail`) & unified security policy (Done on 2026-11-19)

- Consolidated protected paths, allowlists, vault rules, and sandbox profiles into `.chezmoidata/policy.toml` (deployed to `~/.config/dotfiles/policy.json`), shared by `agent-jail`, `key-guard.py`, `check-encrypted.sh`, and `check-secrets.py`.
- Implemented opt-in `dot_local/bin/executable_agent-jail` with Linux `bwrap` primary backend (RO root, RW workspace, RO `.git/hooks` & `.git/config`, `/dev/null` secret masks, empty `tmpfs` `~/.secrets`, `SSH_AUTH_SOCK` & `HERDR_SOCKET_PATH` passthrough, agent-scoped own-auth isolation) and rootless Linux Landlock LSM fallback (`ABI v1+`, verified live on kernel 7.0.0) for HPC login nodes (`sicc`), plus automated tests in `.github/scripts/check-agent-jail.py`.
- Remaining operator follow-up across hosts: complete Codex `/hooks` trust on each machine (including the new `Stop` notify hook) and optionally transition SSH private keys to passphrase or FIDO2 (`ed25519-sk`).

### Wave 5 — Unified `dotfiles` CLI, `tests/` suite, and 5-machine rollout (Done on 2026-11-19)

- Added unified `dot_local/bin/executable_dotfiles` CLI (`doctor [--json]`, `machine`, `theme`, `fetch`, `jail`, `agent <skills|plugins|status>`, `sync`, `check`, `bootstrap`) with `dot_zshrc` live `FZF_DEFAULT_OPTS` reload for `dotfiles theme`, while retaining all legacy standalone binaries (`machine`, `theme`, `dotfiles-fetch`, `agent-jail`) for compatibility.
- Consolidated all 13 `.github/scripts/check-*.py` test scripts into `tests/` with `tests/check_dotfiles_cli.py` and stdlib `unittest`/`pytest`-compatible `tests/test_suite.py` (`UnitChecks`, `ChezmoiChecks`, `SecretHookChecks`), invoked identically locally via `mise run check` and in `.github/workflows/ci.yml`.
- Completed deployment and verification on `container` (CI) and `workstation`; documented the canary rollout checklist for `laptop` → `imrl` → `sicc` → `vps` in `docs/todo.md`.
