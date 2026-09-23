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

## Move the laptop onto dotfiles-fetch

The laptop selects `desktop`, `fonts` and `research`, so its next apply
installs kitty, Zotero and the fonts under `~/.local/opt/dotfiles` and
`~/.local/share/fonts/dotfiles`, beside the copies installed earlier. The
earlier ones are never touched automatically.

1. Before the apply, run `chezmoi status`. A line starting with `MM` is a file
   edited by hand that the apply would overwrite; the workstation had two.
   Move each edit into the source first.
2. After the apply, run `dotfiles-fetch migrate`, then
   `dotfiles-fetch migrate --apply`, to delete the font directories
   `typefaces.sh` wrote. Until then fontconfig sees every family twice.
3. Point the dock and the default terminal at `dotfiles-kitty.desktop`: the
   `org.gnome.shell favorite-apps` setting, `~/.config/xdg-terminals.list` and
   `~/.config/ubuntu-xdg-terminals.list`. chezmoi manages none of them, and
   on the workstation all three named the old `kitty.desktop`.
4. Restart kitty from the new launcher, then delete what `migrate` reports as
   left alone: `~/.local/kitty.app` and its links in `~/.local/bin`, the old
   `kitty.desktop`, `kitty-open.desktop` and `zotero.desktop`, and a cargo
   `tre` (`cargo uninstall tre-command`). Shells in a kitty started from the
   old copy take `TERMINFO` and the shell integration from
   `~/.local/kitty.app`, so restart first.
5. If an older Zotero is installed elsewhere, as one was in `/opt/zotero` on
   the workstation, keep only one. The release dotfiles-fetch installs upgrades
   the library's database when it opens it, and an older Zotero may then
   refuse it.

## Not bugs

- Neovim's Mason installs language servers on a machine without the `lsp`
  bundle. That is the intended fallback.
