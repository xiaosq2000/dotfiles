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

## Finish the laptop's move to dotfiles-fetch

The laptop runs the dotfiles-fetch copies of kitty, Zotero, `tre` and the
fonts, and its dock, default terminal and `zotero://` handler name the
`dotfiles-*.desktop` launchers. Three things are left:

1. Quit every window of the old kitty, start kitty from the dock, then delete
   `~/.local/kitty.app`, its links `~/.local/bin/kitty` and
   `~/.local/bin/kitten`, and `kitty.desktop` and `kitty-open.desktop` in
   `~/.local/share/applications`. Run
   `update-desktop-database ~/.local/share/applications` afterwards. Shells in
   a kitty started from the old copy take `TERMINFO` and the shell integration
   from `~/.local/kitty.app`, so restart before deleting it.
2. Run `sudo rmdir /opt/zotero`. Zotero 9.0.6 was there; its files are gone,
   but the empty directory needs root to remove.
3. Once Zotero 10.0.3 has opened the library and works, delete
   `~/Zotero/zotero.sqlite.before-zotero-10`. It is the database as 9.0.6 left
   it, kept because opening the library upgrades the database and 9.0.6 may
   not read it afterwards.

## Not bugs

- Neovim's Mason installs language servers on a machine without the `lsp`
  bundle. That is the intended fallback.
