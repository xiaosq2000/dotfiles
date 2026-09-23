# Outstanding work

What is left to do, most useful first. Nothing here stops a machine from
working. Delete an entry once it is done; git keeps the history.

## Trust the key-guard hook in Codex on each machine

Codex skips a user hook until it has been trusted, so on every machine that
runs Codex, the hook that keeps it from reading private keys is off until then.
Only the sandbox profile guards the keys in the meantime. On each machine, after
the apply that brings `~/.codex/hooks.json`:

1. Start `codex` and open `/hooks`.
2. Trust the `PreToolUse` hook that runs `~/.agents/hooks/key-guard.py`.

Machines still to do: workstation, imrl, sicc, vps. Drop a name once
it is done, and delete this entry when none are left. The background is under
"Keeping agents away from private keys" in [secrets.md](secrets.md).

## Move the workstation and laptop onto dotfiles-fetch

Both select `desktop`, `fonts` and `research`, so their next apply installs
kitty, Zotero and the fonts under `~/.local/opt/dotfiles` and
`~/.local/share/fonts/dotfiles`, beside the copies installed earlier. The
earlier ones are never touched automatically. On each machine, after that
apply:

1. `dotfiles-fetch migrate`, then `dotfiles-fetch migrate --apply`, to delete
   the font directories `typefaces.sh` wrote. Until then fontconfig sees every
   family twice.
2. Delete what `migrate` reports as left alone once the new copy works:
   `~/.local/kitty.app` and its links in `~/.local/bin`, the old
   `kitty.desktop`, `kitty-open.desktop` and `zotero.desktop`. On the
   workstation, `zotero.desktop` points at a Zotero in `/opt/zotero` (9.0.6,
   checked on 2026-09-23), which is older than the release dotfiles-fetch
   installs. The newer one upgrades the library's database when it opens it,
   and the older one may then refuse it, so keep only one.

Machines still to do: workstation, laptop.

## Not bugs

- Neovim's Mason installs language servers on a machine without the `lsp`
  bundle. That is the intended fallback.
