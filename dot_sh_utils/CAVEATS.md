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

zsh is in the `core` bundle in `.chezmoidata/tools.toml`, so on a machine this
repository knows about you do not need that command at all: `chezmoi apply`
renders the pixi manifest and `pixi global sync` installs zsh along with
everything else. The bootstrap order works out because chezmoi itself is
installed standalone by `get.chezmoi.io`, and `setup.d/pixi.sh` installs pixi
before the sync runs.

Run the command by hand only to get a zsh before the first apply, on a machine
with no root and no zsh at all.

## pixi completion has to load after compinit

In `.zshrc`, the line that loads pixi completion sits far below the section that
adds pixi to `PATH`. The two lines belong together by topic, and they cannot run
at the same point in the file.

`pixi completion --shell zsh` prints code that calls `compdef`. The `compdef`
function only exists after `compinit` has run, and `.zshrc` runs `compinit`
itself in its completion section, just above the `sheldon source` line, so the
pixi completion has to load after that. This used to be oh-my-zsh's `compinit`,
called as a side effect of sourcing `oh-my-zsh.sh`; making the call explicit is
part of why the framework went away.

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

## ssh is a function so that kitty does not take over its completion

In `.zshrc`, the kitty section defines `ssh` as a shell function that calls
`kitten ssh`. The kitty documentation suggests an alias instead, and the alias
breaks host completion.

zsh expands an alias before it decides which completion function to run, so with
the alias in place the word under the cursor belongs to `kitten` rather than to
`ssh`, and zsh runs kitty's `_kitty` function instead of `_ssh`. A function
keeps the first word as `ssh`. Nothing is lost, because kitty's completion for
`kitten ssh` hands the work back to `_ssh` anyway; the only completions that go
away are kitty's own flags, such as `--kitten` and `--copy`.

There used to be a sharper reason. `_kitty` passes the current matcher to the
kitty binary, which stops with the message below.

```
Error: ZSH anchor based matching active, cannot complete. Turn it off by setting
zstyle :completion: to something that does not use anchors in your ~/.zshrc
```

That matcher came from oh-my-zsh. Because `.zshrc` set `CASE_SENSITIVE` to
false and `HYPHEN_INSENSITIVE` to true, `oh-my-zsh/lib/completion.zsh` set the
list below, and the second and third entries are anchored.

```zsh
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]-_}={[:upper:][:lower:]_-}' 'r:|=*' 'l:|=* r:|=*'
```

zsh tries the entries in order and stops at the first that matches, so the
failure only appeared once plain prefix matching found nothing, which is exactly
the moment you wanted completion. That is why the problem looked like it
belonged to host names.

Since oh-my-zsh went away, `.zshrc` sets one unanchored matcher of its own, so
that error is gone and `kitty` and `kitten` complete normally. The cost is
substring completion, which zsh has no unanchored way to express. The `ssh`
function stays regardless, for the reason in the next section.

## TERM does not tell you whether you are inside a kitty window

The `ssh` function above sits inside a block that runs when `TERM` is
`xterm-kitty`, and that test alone also passes on a machine you reached with
`kitten ssh`. The result is that a second hop fails with the message below.

```
Error: The SSH kitten is meant to run inside a kitty window
```

Two things make the outer test misleading on a remote machine.

- `kitten ssh` sets `TERM` to `xterm-kitty` on the remote machine and installs
  kitty's terminfo there, which is the whole point of the kitten.
- The `remote_kitty` option defaults to `if-needed`, so the kitten also copies a
  `kitten` program to `~/.local/share/kitty-ssh-kitten/kitty/bin` on the remote
  machine and puts that directory on `PATH`. See `install_kitty_bootstrap` in
  `shell-integration/ssh/bootstrap-utils.sh` inside the kitty installation.

What the kitten actually needs is the local kitty process, which it finds
through `KITTY_WINDOW_ID` and `KITTY_PID`. Both name objects that only exist in
the kitty instance on your own machine, so neither is sent over ssh, and the
kitten stops as soon as either one is missing. The commands below show that
either variable is enough to trigger the message.

```sh
env -u KITTY_WINDOW_ID kitten ssh somehost
env -u KITTY_PID kitten ssh somehost
```

So `.zshrc` defines the `ssh` function only when both variables are set. The
rest of the block still runs on the remote machine, which is what you want,
because the terminal there really does behave like kitty.

To reach a machine that sits behind another one, put the hop in the local
`~/.ssh/config` with `ProxyJump` and run `kitten ssh` from the local kitty
window. The kitten then bootstraps the final host itself, and that host gets
kitty's terminfo. Running plain `ssh` on the middle machine works too, but the
final host inherits `TERM=xterm-kitty` without the matching terminfo, and full
screen programs there will complain.
