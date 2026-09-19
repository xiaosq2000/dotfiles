# Outstanding work

Written 2026-09-18, after the machine-layer, bundles, theme, shell and secrets
refactors were deployed to the workstation, imrl and sicc. Pruned as things
land. Everything here needs a decision, a credential, or a moment when no job is
running.

Nothing here is required for any of the three machines to work; all three apply
and verify clean as they are. Encryption is finished end to end, key backed up
and read back, so nothing on this page carries urgency any more. Work down it in
whatever order appeals.

## Needs you

### Rebuild the workspace environments at the new path

This is now the largest reclaimable thing left, and the numbers are bigger than
this page previously said.

`detached-environments` points at a roomy filesystem on both remotes, but pixi
neither migrates nor removes environments installed at the old path, so every
workspace that was installed before the migration still has a `.pixi/envs`
beside it on the constrained filesystem:

| Machine | Old-path environments | Where |
| --- | --- | --- |
| imrl | 12 GB | `~/Projects/vlm_toolkit/.pixi/envs` |
| imrl | 6 GB | `~/Projects/vlm-nav/.pixi/envs` |
| sicc | 1.2 GB | `~/Projects/embodied-ai/.pixi` |

```sh
cd <workspace> && pixi install     # rebuilds at the new location
rm -rf <workspace>/.pixi/envs      # then reclaim the old one
```

On sicc, do it when no job is running.

An earlier version of this page said imrl had no workspace environments. It has
18 GB of them, and that error hid a second one: deleting imrl's 31 GB cache on
2026-09-19 freed only 5 GB of the root filesystem. rattler hardlinks package
files out of the cache into each environment, so unlinking the cache copy drops
one link and the blocks stay alive through the environments that still point at
them. The space comes back when those environments are rebuilt on the other
filesystem, not before. Nothing is wrong meanwhile; the environments work, they
have simply stopped sharing blocks with any cache.

### Finish the secrets migration

Encryption works; two pieces of it are unbuilt.

- **rbw on imrl and sicc.** The key is fetchable here but neither remote has rbw
  set up, so both still run without a key and leave `~/.ssh/config` unmanaged.
  Either repeat the `rbw register` dance there, or just copy the key across,
  which takes one command per machine:

  ```sh
  ssh imrl 'mkdir -p ~/.config/chezmoi && cat > ~/.config/chezmoi/key.txt && chmod 600 ~/.config/chezmoi/key.txt' < ~/.config/chezmoi/key.txt
  ssh imrl 'chezmoi apply'
  ```

  The second line is what makes `.ssh/config` managed there; nothing else
  changes.

- **`~/.secrets/env`, the API tokens.** The SSH config went first because it was
  smaller. Note that `~/.secrets/ssh/config` has 15 hosts and the encrypted
  `~/.ssh/config` has 4; they differ, and reconciling them is its own small job.

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
loads its `template.dconf` into dconf. It is also the one external still pinned
to a single colour scheme. Either wire it up or drop it; kitty and alacritty are
what actually get used.

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
