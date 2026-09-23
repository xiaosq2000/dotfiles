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

## Not bugs

- Neovim's Mason installs language servers on a machine without the `lsp`
  bundle. That is the intended fallback.
