# Outstanding work

What is left to do, most useful first. Nothing here stops a machine from
working. Delete an entry once it is done; git keeps the history.

## Trust user hooks in Codex on each machine

Codex skips a user hook until it has been trusted, so on every machine that
runs Codex, `key-guard.py` (`PreToolUse`) and `agent-notify.py` (`Stop`) stay
off until trusted (the `key-guard` sandbox profile still guards keys in the
meantime). On each machine, after `dotfiles sync`:

1. Start `codex` and open `/hooks`.
2. Trust both `~/.agents/hooks/key-guard.py` (`PreToolUse`) and
   `~/.agents/hooks/agent-notify.py` (`Stop`).

Machines still to do: laptop, imrl, sicc. Drop a name once done,
and delete this entry when none are left. See [secrets.md](secrets.md).

## Roll out the late-2026 refactor to remaining machines

Checked on 2026-11-19. `workstation` is deployed, cleaned, and verified;
remaining hosts in canary order: `laptop` → `imrl` → `sicc` → `vps`. On each host:

```sh
dotfiles sync --update      # or: env -u http_proxy -u https_proxy -u all_proxy chezmoi update
dotfiles doctor
```

On `laptop` (a host with `sudo = true` and `system/laptop/` files), run
`sudo -v && chezmoi apply` once so updated root-owned units (such as
`power-tunables.service`) install.

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
