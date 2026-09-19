# Outstanding work

Nothing here is required for any machine to work. What is left needs a machine
that is not to hand, or is simply worth doing.

**State:** workstation, imrl, sicc and vps are deployed; `chezmoi status` is
empty on each and CI is green. The laptop has never had chezmoi run on it.

The vps came up on 2026-09-19 with `bundles = ["core"]`. It ended with *more*
free disk than it started with, 9.1 GB against 8.3 GB, because the old
`.sh_utils` layout and a broken rustup came off as the bundle went on. It has no
age identity and is not getting one: it is internet-facing, so `.chezmoiignore`
takes the keyless path and simply does not manage `.ssh/config` there.

gnome-terminal support was removed from the repository entirely the same day —
the theme checkout, the dead `set_gnome_terminal_as_default` function and the
version probe — and `.chezmoiremove` deletes the checkout on every machine.

No machine sources `~/.cargo/env` any more. rustup is gone from imrl, sicc and
the vps; only the workstation keeps a toolchain.

## Blocked on the laptop

The laptop is being handled by hand, off this machine. Until it has run
`chezmoi init --apply`, three pieces of migration scaffolding have to stay:

- the legacy theme-name map in `.chezmoi.toml.tmpl`, translating `main`, `moon`
  and `dawn`;
- `run_onchange_before_01-stale-externals.sh`, which removes git-submodule
  remnants of chezmoi externals;
- most blocks in `.chezmoiremove`.

The first two act only on state a previous chezmoi init leaves behind, so they
are no-ops on the vps and blocked on the laptop alone. `.chezmoiremove` does
apply to the vps, which carries the old `.sh_utils` layout.

Deleting all three is one commit once the laptop is done.

## Worth doing

### Shell startup is ~510 ms locally, ~1.1 s on imrl and sicc

`~/.sh_utils/*.sh` is roughly 1300 lines sourced at every shell start, including
a 614-line network script, and `setup_texlive` globs the texlive tree every
time. Autoloaded functions would fix most of it. The remote figure is the one
that stings, and sicc's home is on NFS.

### The typefaces installer

`setup.d/typefaces.sh` is 433 lines, the largest thing left in that directory.
It installs sixteen families, each with its own release-asset naming and wanted
extensions. Every machine has `typefaces = false`, so a rewrite to
`.chezmoiexternal.toml` would be large and untestable without downloading about
a gigabyte of fonts. `gitHubLatestReleaseAssetURL` would do most of the work.

Fonts are installed on the workstation despite the flag being false; they came
from elsewhere and nothing removes them.

### Mason installs language servers per machine

On any machine without the `lsp` bundle. This is the intended fallback, not a
bug. Listed so it is not rediscovered as one.
