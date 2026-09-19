# Outstanding work

Written 2026-09-18, after the machine-layer, bundles, theme, shell and secrets
refactors were deployed to the workstation, imrl and sicc. Pruned as things
land. Everything here needs a decision, a credential, or a moment when no job is
running.

Nothing here is required for any of the three machines to work. Encryption is
finished end to end, key backed up and read back; the caches and pre-migration
environments are reclaimed; everything is pushed, `chezmoi status` is empty on
all three machines, and CI is green again after a day red on assertions that
had outlived what they described. Nothing on this page carries urgency any
more, so work down it in whatever order appeals.

The disk reclamation of 2026-09-19, for the record, because the numbers were
not what the plan predicted:

| | imrl | sicc |
| --- | --- | --- |
| Stale rattler cache deleted | 31 GB | 18 GB |
| Pre-migration environments rebuilt and deleted | 18 GB | 1.2 GB |
| Actually returned to the constrained filesystem | 18 GB | 19.2 GB |

imrl's two figures do not add up, and the reason is worth keeping. rattler
hardlinks package files out of the cache into every environment, so deleting a
31 GB cache returned only 5 GB: the blocks stayed alive through the
environments still pointing at them, and came back only once those were rebuilt
on the other filesystem. About 5 GB is still held that way by `~/.pixi/envs`,
the global bundle environments, which live on the root filesystem and were
never part of this move.

Two things went wrong in the doing, both caught before anything was deleted. A
bare `pixi install` builds only the default environment, so the first pass
would have dropped `hf` on vlm_toolkit and `research` and `style` on sicc had
the old copies been removed on trust; `--all`, or naming each environment, is
the correct invocation. And `.pixi/envs` becomes a *symlink* to the detached
path, so a non-empty check on it looks like a failed migration when it is
exactly the intended result.

## Needs you

### Clean up after the deleted API tokens

The chezmoi half of the secrets migration is finished. The age key reached imrl
and sicc on 2026-09-19 by scp, rather than by repeating the `rbw register` dance
on each, and `~/.ssh/config` is managed on all three machines now; `chezmoi
status` is empty on both remotes. One thing to know if this is ever repeated:
`chezmoi` is not on `PATH` over a non-interactive ssh, so the apply has to name
it, `ssh imrl '~/.pixi/bin/chezmoi apply'`.

The 15-host `~/.secrets/ssh/config` was read against the managed one and
deliberately not merged back. Only `id_ed25519` exists on this machine, so every
`IdentityFile ~/.ssh/id_rsa` in it was already dead, and `vps-dmit-root` names a
key directory that is gone. One entry was worth keeping and was added by hand:
`workstation-imrl`, which reaches this machine through the reverse tunnel
`nat-traversal@1.service` holds open on imrl's `127.0.0.1:28080`.

`~/.secrets/env` held ten API tokens, seven LLM keys plus two GitHub tokens and
a prefix.dev token, all outdated; it was deleted on 2026-09-19 and nothing
sourced it, so no shell behaviour changed. `~/.secrets` never existed on imrl or
sicc, so there was nothing to remove there.

Two things that deletion did **not** do, both still open:

- The ten tokens remain in `~/.secrets`'s git history, across 34 commits. The
  repository has no remote, so they are on this disk only, but a `git log -p`
  still prints them. Purging means rewriting the whole history:

  ```sh
  git -C ~/.secrets filter-branch --index-filter 'git rm --cached --ignore-unmatch env' -- --all
  ```

- Deleting a local copy does not revoke a credential. If any of those keys were
  never revoked at the provider, they are still live regardless of what this
  disk holds. Worth a pass through the OpenAI, Anthropic, Google, DeepSeek,
  SiliconFlow, Tencent, GitHub and prefix.dev dashboards.

### Decide whether imrl and sicc still need a Rust toolchain

Both carry a full rustup: 1.3 GB on imrl, 1.5 GB on sicc, remeasured 2026-09-19.
Their machine entries say `rust = false`, meaning this repository will not
install or maintain one, and after the cleanup the only cargo-installed tool
left on either is `tre-command`, which conda-forge does not package.

So the toolchain is being kept for one small CLI tool and whatever Rust you
might write there. If neither, `rustup self uninstall` reclaims about 2 GB per
machine, and `tre` goes with it.

## Worth doing, nobody is blocked

### The typefaces installer

`setup.d/typefaces.sh` is 433 lines and the largest thing left in that
directory. It stayed a script rather than becoming `.chezmoiexternal.toml`
entries: it installs sixteen families, each with its own release-asset naming
and its own set of wanted extensions, and every machine currently has
`typefaces = false`, so a rewrite would be both large and impossible to test
without downloading about a gigabyte of fonts. chezmoi's
`gitHubLatestReleaseAssetURL` would do most of the work if it is ever worth it.

Fonts are installed on this workstation despite the flag being false, so they
came from somewhere else. Nothing removes them.

### gnome-terminal is not theme-aware

`.chezmoiexternal.toml` checks out a Rosé Pine gnome-terminal theme, and nothing
loads its `template.dconf` into dconf. Since starship stopped depending on a
per-scheme checkout on 2026-09-19, this is the last thing in the repository
still hard-wired to one colour scheme. Either wire it up or drop it; kitty and
alacritty are what actually get used.

### Mason still installs language servers per machine

`~/.local/share/nvim/runtime`, the 27 MB copy `neovim.sh` left behind with its
`cp -a` of a release tarball, was removed on 2026-09-19. It was confirmed inert
first: nvim resolves `$VIMRUNTIME` to `~/.pixi/envs/nvim/share/nvim/runtime`,
and the stale directory was not on `runtimepath`, which carries only `site/`
and the `lazy/` plugins. `lazy/`, `mason/`, `site/`, `sessions/` and
`auto_session/` are untouched; `.chezmoiremove` still, correctly, refuses to go
near `~/.local/share/nvim`.

What remains is by design, not a bug: Mason installs language servers per
machine on any machine without the `lsp` bundle. That is the intended fallback.

### Shell startup is about 510 ms

Dropping oh-my-zsh did not change it, because the framework was never the cost.
`~/.sh_utils/*.sh` is roughly 1300 lines sourced at every shell start, including
a 614-line network script, and `setup_texlive` globs the texlive tree on every
start. Autoloaded functions would fix most of it. Nothing is broken; it is just
half a second.

### Delete the migration scaffolding

Three things exist only to get from the old layout to this one. They were
written as one blocked item, waiting on "laptop and vps". Surveying the vps on
2026-09-19 split them apart, and they are no longer blocked on the same thing:

- The legacy theme-name map in `.chezmoi.toml.tmpl`, translating `main`, `moon`
  and `dawn`. **Blocked on the laptop alone.** The map rewrites a theme value
  already *stored* in `~/.config/chezmoi/chezmoi.toml`, and the vps has no such
  file: chezmoi has never run there. A first init on the vps would be given a
  current name by hand and never touch the map.
- `run_onchange_before_01-stale-externals.sh`, which removes git-submodule
  remnants of chezmoi externals. **Blocked on the laptop alone**, for the same
  reason: no chezmoi on the vps means no externals to have been submodules.
- Most blocks in `.chezmoiremove`. **These do apply to the vps**, which carries
  the full old layout — `~/.oh-my-zsh`, `~/.sh_utils`, `~/.fzf`,
  `~/.local/bin/nvim`, `~/.config/yazi` — installed by the old `.sh_utils`
  bootstrap rather than by chezmoi.

So two thirds of this item is waiting on the laptop, which is being handled by
hand and off this machine, and nothing here should assume it.

The starship fork checkout that `.chezmoiremove` deletes is gone from
workstation, imrl and sicc, so the TTY stall it causes over ssh is only ahead
of these two machines, not behind anyone.

#### What the vps can actually afford

Surveyed 2026-09-19: BandwagonHOST, Ubuntu 24.04, root, **21 GB disk with
5.0 GB free (75% used)**. Its job is network plumbing to get past the GFW, and
nothing else runs there.

Its machine entry says `bundles = ["core"]`, which is the one decision worth
revisiting before any init. Measured against this workstation, core's
twenty-two packages are about 680 MB of environments, and rattler's cache holds
the extracted packages the environments hardlink from, so the real cost on one
filesystem is roughly 1 to 1.5 GB — a fifth to a third of the free space left,
for a toolchain a networking box will rarely open. The bulk is not the shell:
`pre-commit` 271 MB, `difftastic` 140 MB, `sheldon` 117 MB, `sqlite` 90 MB.

`bundles = []`, as the `container` entry already does, costs nothing and still
deploys every config file. Two consequences to weigh, not to discover
afterwards:

- `.chezmoiremove` guards each replaced binary on *either* the pixi copy
  existing *or* the package not being in this machine's bundles. With no
  bundles the second branch is always true, so `~/.local/bin/nvim`, `~/.fzf`
  and the rest are removed with nothing arriving to replace them. The vps falls
  back to whatever the base image ships.
- `~/.oh-my-zsh` would stay, because its removal is guarded on sheldon having
  cloned its plugins and sheldon would not be installed.

`.zshrc` itself is safe either way: `sheldon` and `starship` are both behind
`if has`, so a bundle-less vps gets a working plain zsh and a warning line, not
a broken login shell. That matters more than usual here, since zsh is root's
login shell on a box whose whole purpose is being reachable.

### Every duplicate is gone

`pre-commit` was the last one, installed twice: once from the `core` bundle and
once as a uv tool. The uv copy was 4.6.1 against the bundle's 4.6.2, and already
shadowed, since `~/.pixi/bin` precedes `~/.local/bin` on `PATH` — fifteen
megabytes that did nothing except wait to become the wrong version if that
order ever changed. `uv tool uninstall pre-commit` on 2026-09-19 removed both
the tool and its `~/.local/bin` shim; nothing pinned that path. `nvitop` and
`doc-sync` remain uv tools and should, conda-forge packages neither.

Before it went: cargo's `starship`, `eza`, `tree-sitter` and `taplo`, and stale
`~/.local/bin` copies of `starship`, `difft`, `lazygit`, `lazydocker`, `hf`,
`nvim` and `uv`. Every tool on all three machines now resolves to `~/.pixi/bin`,
which is what makes the manifest an accurate description of the machine rather
than an aspiration.
