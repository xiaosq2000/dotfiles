# Outstanding work

Written 2026-09-18, after the machine-layer, bundles, theme, shell and secrets
refactors were deployed to the workstation, imrl and sicc. Pruned as things
land. Everything here needs a decision, a credential, or a moment when no job is
running.

Nothing here is required for any of the three machines to work. Encryption is
finished end to end, key backed up and read back; the caches and pre-migration
environments are reclaimed; the twenty commits are pushed. Nothing on this page
carries urgency any more, so work down it in whatever order appeals.

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

Both carry a full rustup: 1.8 GB on imrl, 2.0 GB on sicc. Their machine entries
say `rust = false`, meaning this repository will not install or maintain one,
and after the cleanup the only cargo-installed tool left on either is
`tre-command`, which conda-forge does not package.

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

### Neovim leftovers from the retired installer

`neovim.sh` did `cp -a` of the release tarball into `~/.local`, so
`~/.local/share/nvim/runtime` is a copy of an old Neovim's runtime sitting
beside `lazy/`, `mason/` and the session files. `.chezmoiremove` deliberately
does not touch `~/.local/share/nvim`, because plugin state is in there and is
not replaceable. The stale `runtime/` is inert, since nvim resolves its runtime
relative to its own binary. Removing it by hand reclaims a few tens of
megabytes.

Mason is also still installing language servers per machine on any machine
without the `lsp` bundle. That is the designed fallback, not a bug.

### Shell startup is about 510 ms

Dropping oh-my-zsh did not change it, because the framework was never the cost.
`~/.sh_utils/*.sh` is roughly 1300 lines sourced at every shell start, including
a 614-line network script, and `setup_texlive` globs the texlive tree on every
start. Autoloaded functions would fix most of it. Nothing is broken; it is just
half a second.

### Delete the migration scaffolding

Three things exist only to get from the old layout to this one, and each says so
where it lives:

- The legacy theme-name map in `.chezmoi.toml.tmpl`, translating `main`, `moon`
  and `dawn`. Needs laptop and vps to have run `chezmoi init`.
- `run_onchange_before_01-stale-externals.sh`, which removes git-submodule
  remnants. Needs laptop and vps to have applied.
- Most blocks in `.chezmoiremove`. Each names the machines still outstanding.

Workstation, imrl and sicc are done, all three deployed and verified on
2026-09-18. Laptop and vps are not, and the vps has no `hostnamePattern`, so its
machine name has to be given by hand at init:

```sh
chezmoi init --apply --promptString machine=vps --promptString theme=rose-pine-dawn xiaosq2000
```

### One duplicate left

`pre-commit` is installed twice: once from the `core` bundle and once as a uv
tool at `~/.local/share/uv/tools/pre-commit`. This is the one case
`.chezmoiremove` deliberately leaves alone, because the copy in `~/.local/bin`
is a shim into the tool's own virtual environment and deleting it would leave uv
still believing the tool is installed.

```sh
uv tool uninstall pre-commit
```

All the other duplicates deployment turned up are gone: cargo's `starship`,
`eza`, `tree-sitter` and `taplo`, and stale `~/.local/bin` copies of `starship`,
`difft`, `lazygit`, `lazydocker`, `hf`, `nvim` and `uv`. Every tool on all three
machines now resolves to `~/.pixi/bin`, which is what makes the manifest an
accurate description of the machine rather than an aspiration.
