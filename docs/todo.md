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

## Move the typefaces installer to `.chezmoiexternal.toml`

`dot_sh_utils/setup.d/executable_typefaces.sh` is 433 lines and installs
sixteen font families, each with its own release-asset naming. chezmoi's
`gitHubLatestReleaseAssetURL` would replace most of it.

- Every machine has `typefaces = false`, so nothing runs the script today, and
  testing a rewrite means downloading about a gigabyte of fonts.
- The workstation's fonts were installed outside this repository. Nothing here
  manages or removes them.

## Not bugs

- Neovim's Mason installs language servers on a machine without the `lsp`
  bundle. That is the intended fallback.
