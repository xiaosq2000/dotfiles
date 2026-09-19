# Outstanding work

Written 2026-09-18, after the machine-layer, bundles, theme, shell and secrets
refactors were deployed to the workstation, imrl and sicc. Everything here needs
a decision, a credential, or a moment when no job is running.

Nothing here is required for any of the three machines to work; all three apply
and verify clean as they are.

## Needs you

### Turn on encryption

The whole mechanism is in place and tested, but off: `.chezmoidata/secrets.toml`
has an empty `ageRecipient`, so no `[age]` section is generated and there are no
`encrypted_*` files yet. It stays off until someone creates a key, and creating
the Bitwarden entry is the one step nothing can automate.

[docs/secrets.md](secrets.md) has the commands. About ten minutes, of which the
fiddly part is that bitwarden.com needs `rbw register` with a personal API key
before `rbw login` will work at all. The reason to
bother: `~/.secrets` has no git remote, so the SSH config and the API tokens in
it exist on exactly one disk.

Afterwards, two things move into the repository as ciphertext:

- `~/.ssh/config`, whose 15 hosts currently live in `~/.secrets/ssh/config`
  while a 4-host copy sits at `~/.ssh/config`. They differ. Worth reconciling
  before encrypting either.
- `~/.secrets/env`, the API tokens.

### Reclaim the old package caches

Both remotes now keep their rattler cache off the constrained filesystem, via a
symbolic link. The previous cache was renamed aside rather than deleted, so the
space is not back yet.

| Machine | Old cache, safe to delete | Size |
| --- | --- | --- |
| imrl | `~/.cache/rattler.premigration-20260918233443` | 31 GB |
| sicc | `~/.cache/rattler.premigration-20260918153555` | 18 GB |

```sh
rm -rf ~/.cache/rattler.premigration-*
```

imrl's contents were copied to the new location first, so deleting costs
nothing. sicc's were not: the copy was running at about 1.5 MB/s over NFS, which
put 18 GB at several hours, and only 1.5 GB had moved when it was stopped. The
cache is regenerable, so deleting the rest costs re-downloading packages the
next time an environment wants them, from a login node that reaches conda-forge
directly. That was the cheaper trade than an hours-long copy; the eight packages
sicc actually needed installed fine.

### Rebuild sicc's workspace environments

`detached-environments` now points at `/data/huikong/shuqixiao/pixi/envs`, and
pixi neither migrates nor removes environments installed at the old path. On
sicc that is 1.2 GB under `~/Projects/embodied-ai/.pixi`:

```sh
cd ~/Projects/embodied-ai && pixi install     # rebuilds at the new location
rm -rf ~/Projects/embodied-ai/.pixi/envs      # then reclaim the old one
```

Do it when no job is running. imrl had no workspace environments at all, so
there is nothing to redo there.

### Decide whether imrl and sicc still need a Rust toolchain

Both carry a full rustup: 1.8 GB on imrl, 2.0 GB on sicc. Their machine entries
say `rust = false`, meaning this repository will not install or maintain one,
and after the cleanup the only cargo-installed tool left on either is
`tre-command`, which conda-forge does not package.

So the toolchain is being kept for one small CLI tool and whatever Rust you
might write there. If neither, `rustup self uninstall` reclaims about 2 GB per
machine, and `tre` goes with it.

### Decide whether the university paths should stay in the clear

`.chezmoidata/machines.toml` names `/data/huikong/shuqixiao` and imrl's mount
UUID, in a public repository. They are there because a relocated cache is a
property of the machine and has to be readable before any key exists. Plaintext
inventory was the explicit decision, and this is the one part of it that names
infrastructure rather than roles.

If you would rather not publish them: move the two `[machines.*.pixi]` tables
into an encrypted file and read it with `include`, which costs the ability to
relocate a cache on a machine that has no key yet.

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
