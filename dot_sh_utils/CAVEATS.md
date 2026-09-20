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

## Tool completions are cached on fpath, not evaluated at startup

`.zshrc` does not run `pixi completion --shell zsh` and evaluate the result. It
writes that output to `${XDG_CACHE_HOME}/zsh/completions/_pixi` and puts the
directory on `fpath` before `compinit`. codex and uv are handled the same way by
the same loop.

The reason is cost. Those scripts are big — pixi's is 11,781 lines — and `eval`
has to parse all of it before the shell can draw a prompt. Measured on the
laptop on 2026-09-20, the three of them were 516 ms of a 750 ms startup. As
files on `fpath` they cost nothing at startup: `compinit` reads the `#compdef`
tag on the first line, and zsh loads the body on the first Tab. Startup went to
216 ms.

This works because clap, which generates all three, ends each script with a
dual-mode trailer:

```zsh
if [ "$funcstack[1]" = "_pixi" ]; then
    _pixi "$@"
else
    compdef _pixi pixi
fi
```

Autoloaded, `funcstack[1]` is `_pixi` and the file calls the function it just
defined. Sourced, it falls through to `compdef`. One file is correct either way.

**This is why the old ordering constraint is gone.** Loading the completion by
`eval` meant it called `compdef`, which only exists once `compinit` has run, so
the pixi line had to sit far below the section that puts pixi on `PATH`. Ubuntu
hid the problem, because its `/etc/zsh/zshrc` runs `compinit` before your
`.zshrc` starts; a zsh installed by pixi or homebrew reads no such file and
printed `(eval):11778: command not found: compdef` on every new shell. An fpath
file never calls `compdef` at all, so the ordering that now matters is the
opposite one: the directory has to join `fpath` *before* `compinit`, not after.

Three wrinkles come with it, and all three look arbitrary without the reason.

**The dump has to be thrown away when a completion file is new.** `compinit -C`
sources its dump and never globs `fpath`, so a name that appeared for the first
time would go unregistered until the dump ages out, up to a day later. `.zshrc`
deletes the dump when any cached completion, or `.zshrc` itself, is newer than
it. `.zshrc` is in that test because a file *older* than the dump still needs a
rebuild the first time the directory joins `fpath`, and only the apply that
rewrote `.zshrc` can show that.

**Every tool has to be on `PATH` before the block that generates its
completion.** This is why pnpm's `PATH` entry sits up with pixi's rather than
with the other tool sections. `codex` is a pnpm binary, and while pnpm's entry
was below `compinit`, a shell that did not already have it inherited generated
no codex completion at all — and said nothing, because the loop skips a tool it
cannot find. It only shows up on a login shell with a clean environment:

```sh
rm ~/.cache/zsh/completions/_codex
env -i HOME=$HOME TERM=xterm PATH=/usr/bin:/bin zsh -ic exit
ls ~/.cache/zsh/completions/
```

**The cache directory and its parent must not be group-writable.** `compaudit`
rejects a group- or other-writable directory on `fpath`, *and* checks the
parent, and `compinit` then stops on an interactive prompt asking whether to
ignore it. The umask here is 002, so `mkdir` leaves both 0775. It does not bite
on this laptop, because `compaudit` exempts a group-writable directory whose
group is named after the user and has nobody else in it. That exemption does not
apply on sicc, where the group is shared, so `.zshrc` fixes the modes itself,
behind a test that costs two stats.

The check below still applies, and is still worth running after a pixi upgrade.
`noglobalrcs` tells zsh to skip `/etc/zsh`, reproducing a pixi-installed zsh on
Ubuntu without installing one. It prints `_pixi` when the completion loaded and
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
