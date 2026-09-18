# Outstanding work

Written 2026-09-18, after the machine-layer, bundles, theme, shell and secrets
refactors. Everything here needs a decision or a credential that the repository
cannot supply for itself.

## Needs you

### Turn on encryption

The whole mechanism is in place and tested, but off: `.chezmoidata/secrets.toml`
has an empty `ageRecipient`, so no `[age]` section is generated and there are no
`encrypted_*` files yet. It stays off until someone creates a key, and creating
the Bitwarden entry is the one step nothing can automate.

[docs/secrets.md](secrets.md) has the commands. About ten minutes. The reason to
bother: `~/.secrets` has no git remote, so the SSH config and the API tokens in
it exist on exactly one disk.

Afterwards, two things move into the repository as ciphertext:

- `~/.ssh/config`, whose 15 hosts currently live in `~/.secrets/ssh/config`
  while a 4-host copy sits at `~/.ssh/config`. They differ. Worth reconciling
  before encrypting either.
- `~/.secrets/env`, the API tokens.

### Relocate the package caches on imrl and sicc

Both machines have `pixi.cacheDir` and `pixi.detachedEnvironments` set, and the
cache was relocated during the deploy. Two follow-ups:

- The previous cache directory was renamed aside rather than copied, because
  copying tens of gigabytes over NFS during an apply is not reasonable. The
  apply printed the exact `rsync` command to keep its contents, and the `rm -rf`
  to discard them. Discarding only costs re-downloading packages.
- `detached-environments` orphans environments installed at the old path. pixi
  neither migrates nor removes them. On sicc that is 1.2 GB under
  `~/Projects/embodied-ai/.pixi`; run `pixi install` in the workspace to rebuild
  at the new location, then delete the old directory. imrl had no workspace
  environments at all, so there is nothing to redo there.

Do the sicc one when no job is running.

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

Workstation, imrl and sicc are done. Laptop and vps are not, and the vps has no
`hostnamePattern`, so its machine name has to be given by hand at init.

### One duplicate left

`pre-commit` is installed twice: once from the `core` bundle and once as a uv
tool at `~/.local/share/uv/tools/pre-commit`. The pixi copy wins on PATH.
`uv tool uninstall pre-commit` settles it.
