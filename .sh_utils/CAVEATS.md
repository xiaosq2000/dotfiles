# Shell setup caveats

The notes here explain a few parts of this repository that look wrong until you
know why they are written the way they are. Each section names the file it
applies to.

## zsh does not have to come from the system package manager

On a shared machine such as a university cluster you often have no root account,
so you cannot install zsh with apt. You can still install it into your own home
directory with pixi, because conda-forge publishes a zsh package.

```sh
pixi global install zsh
```

The command records zsh in `~/.pixi/manifests/pixi-global.toml`, so you can
reinstall the same set of tools later. Note that `.sh_utils/setup.d/zsh.sh`
installs oh-my-zsh and the plugins but not the zsh program itself, so run the
pixi command first on a machine that has no zsh.

## pixi completion has to load after compinit

In `.zshrc`, the line that loads pixi completion sits far below the section that
adds pixi to `PATH`. The two lines belong together by topic, and they cannot run
at the same point in the file.

`pixi completion --shell zsh` prints code that calls `compdef`. The `compdef`
function only exists after `compinit` has run, and oh-my-zsh runs `compinit`
when `.zshrc` sources `oh-my-zsh.sh`, so the completion has to load after that
line.

Ubuntu hides the problem, because its `/etc/zsh/zshrc` runs `compinit` before
your `.zshrc` starts, so an early call works by accident. A zsh installed by
pixi or by homebrew reads no such file, and zsh then prints the following
warning on every new shell.

```
(eval):11778: command not found: compdef
```

You can reproduce the same condition on Ubuntu without installing anything,
because the `noglobalrcs` option tells zsh to skip the files under `/etc/zsh`.
The command below prints `_pixi` when the completion loaded correctly, and
`missing` when it did not.

```sh
zsh -o noglobalrcs -i -c 'echo "${_comps[pixi]:-missing}"'
```

## The oh-my-zsh installer needs zsh on PATH

`.sh_utils/setup.d/zsh.sh` adds `~/.pixi/bin` to `PATH` before it runs the
oh-my-zsh installer. The installer stops with an error when it cannot find a zsh
program, and a non-interactive bash shell does not always have `~/.pixi/bin` on
`PATH` already, so without the extra lines the script fails on exactly the
machines that need pixi.

## Changing the login shell is not always possible

`chsh` fails on many shared machines for two separate reasons. First, the
account may live in a directory service such as LDAP rather than in
`/etc/passwd`, and then `chsh` has no local record it can edit. The command
below prints nothing when the account is not local.

```sh
getent -s files passwd "$(id -un)"
```

Second, `chsh` only accepts a shell listed in `/etc/shells`, and a shell
installed under your home directory is never listed there.

The way around it is to leave the recorded login shell as bash and to start zsh
from `~/.bash_profile`. Use `~/.bash_profile` rather than `~/.bashrc`, and guard
the handoff so that it only runs for interactive shells. Each part prevents a
specific failure.

- bash reads `~/.bash_profile` for login shells and `~/.bashrc` for other
  shells, so a handoff in `~/.bashrc` also replaces the shell when you run
  `bash` on purpose.
- `scp`, `sftp` and `rsync` run a non-interactive shell and read its output as
  data, so anything an unexpected shell prints will corrupt the transfer.
- A job script that starts with `#!/bin/bash -l` runs a login shell that is not
  interactive, and replacing that shell changes what the submitted job runs.

Once `~/.bash_profile` exists, bash reads it instead of `~/.profile`, so the
fallback path in it has to source `~/.profile` itself.

`~/.bash_profile` is not tracked in this repository, because the handoff is only
wanted on a machine where you cannot change the login shell. A working version
is below.

```sh
case $- in
    *i*)
        for _zsh in "$HOME/.pixi/bin/zsh" /usr/bin/zsh /bin/zsh; do
            if [ -z "${NO_ZSH:-}" ] && [ -x "$_zsh" ]; then
                export SHELL="$_zsh"
                unset _zsh
                exec "$SHELL" -l
            fi
        done
        unset _zsh
        ;;
esac

[ -f "$HOME/.profile" ] && . "$HOME/.profile"
```

To get back to bash on a machine set up this way, set `NO_ZSH=1`, or connect
with the command below.

```sh
ssh -t <host> "bash --noprofile --norc"
```
