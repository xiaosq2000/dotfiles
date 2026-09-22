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

Machines still to do: workstation, laptop, imrl, sicc, vps. Drop a name once
it is done, and delete this entry when none are left. The background is under
"Keeping agents away from private keys" in [secrets.md](secrets.md).

## Delete the empty key files Codex left in `~/.ssh`

Until the `key-guard` profile switched to globs, Codex could leave empty 0444
files at the default key names, such as `id_rsa`, and ssh warns about each
one. On each machine that has run Codex:

1. `chezmoi update`, so Codex stops making them.
2. `find ~/.ssh -maxdepth 1 -name 'id_*' -type f -empty -delete`. Only empty
   files match, so a real key is never touched.

Machine still to do: the laptop. Delete this entry once it is done. The caveat
about Codex's deny list in [secrets.md](secrets.md) explains the cause.

## Apply the latest changes on the laptop

The laptop is the only machine that has not applied the `machines` skill, the
source-repo hooks and the `ssh` fallback, because it was unreachable when the
others did. On the laptop:

1. Run `chezmoi update`. If it asks about a file, that file was edited on the
   laptop since its last apply; `chezmoi diff <file>` shows what would change.
2. Open a new terminal, so the shell picks up the new `ssh` function.
3. Run `chezmoi verify && machine | grep docs`. The docs line should show the
   page path with no "(absent)" note after it.

Then delete this entry.

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
