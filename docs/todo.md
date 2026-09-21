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

## Cut the last `tput` calls from shell startup

Shell startup took 160 to 260 ms on the workstation, laptop and imrl, and about
400 ms on sicc, when measured on 2026-09-20. The largest single cost left is ten
`tput` calls in
`dot_sh_utils/lib/ui.sh`, about 15 ms locally and more on sicc, where home is on
NFS. Replace them with literal escape sequences such as `printf '\033[1m'`.

- Do not use zsh's `%F{}` escapes. The bash scripts in `setup.d/` source
  `lib/ui.sh` too.
- Measure with a terminal attached. `lib/ui.sh` skips `tput` when stdout is a
  pipe, so a piped benchmark hides exactly this cost:

  ```sh
  time ( for i in $(seq 10); do script -qec "zsh -ic exit" /dev/null >/dev/null 2>&1; done )
  ```

- Profile before changing anything else. Guessing from line counts has been
  wrong here before: sourcing all 2,776 lines of `~/.sh_utils` costs 5 ms.
  `PS4` xtrace timestamps show where the time actually goes.

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
