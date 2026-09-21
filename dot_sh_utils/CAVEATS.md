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

## In kitty, the pixi zsh used to draw every keystroke twice

Typing `a` drew `aa`. The buffer was correct and commands ran correctly, so it
was only the repaint that doubled, but there is no way to tell that while it is
happening. Fixed by `run_onchange_after_07-terminfo.sh`, which is where the
full reasoning lives. The short version, because the shape of it generalises:

It showed up after `exec zsh`, because while kitty started the system zsh that
was the only way to reach the pixi zsh, `~/.pixi/envs/zsh/bin/zsh` from the
`core` bundle. kitty now starts the pixi zsh in every window (see the section
on the login shell below), so every window depends on this fix. `$TERM` is
`xterm-kitty`, which no system terminfo database here carries; kitty ships its
own and points `$TERMINFO` at it, and conda's ncurses ignores `$TERMINFO`. The
pixi zsh therefore resolved no terminfo at all, ZLE could not emit the cursor
movements needed to repaint a line in place, and zsh-syntax-highlighting
repaints on every keystroke.

It takes all three — the pixi zsh, `TERM=xterm-kitty`, and
zsh-syntax-highlighting — and removing any one hides it. That is what made it
hard to attribute, and it is worth knowing the quickest confirmation:

```sh
TERM=xterm-256color zsh     # clean, if terminfo is the problem
zmodload zsh/terminfo; echo ${+terminfo[cuu1]}    # 0 means no terminfo at all
```

The other half of the trap is the on-disk layout. ncurses stores an entry under
a directory named either for the first letter of the entry or for that letter's
hex value, and the two builds here disagree: Ubuntu's uses `x`, conda's uses
`78`. Neither falls back to the other, so `~/.terminfo` carries both.

Worth remembering generally: a conda-built tool may not share the system's
ncurses view of the world, and the failure will not look like terminfo.

## Every interactive shell is the pixi zsh, and the login shell is the system's

The rule is the same on every machine. The login shell recorded for the account
stays whatever the system has, and every interactive shell becomes
`~/.pixi/bin/zsh`, the zsh from the `core` bundle. Until 2026-09-21 the system
zsh started first on most machines and the pixi zsh only on sicc, and that
split caused three separate bugs: doubled keystrokes in kitty (the section
above), kitty's shell integration lost on sicc, and a `tmux.conf` that named
`/bin/zsh`, which sicc does not have. CI now fails if a rendered config names
the system zsh.

### Why the login shell stays

It is the safety net. sshd starts it before anything from this repository
runs, and the handoff below tests the pixi zsh before handing over, so a broken
pixi environment leaves you in the login shell rather than locked out of ssh.

It is also often the only choice. `chsh` fails on many shared machines for two
separate reasons. First, the account may live in a directory service such as
LDAP rather than in `/etc/passwd`, and then `chsh` has no local record it can
edit. The command below prints nothing when the account is not local.

```sh
getent -s files passwd "$(id -un)"
```

Second, `chsh` only accepts a shell listed in `/etc/shells`, and a shell
installed under your home directory is never listed there.

### How each way in reaches the pixi zsh

| Way in | What starts the pixi zsh |
| --- | --- |
| plain `ssh`, a console login, `su -` | the login shell reads `~/.zprofile` (zsh) or `~/.bash_profile` (bash), which hand over |
| a kitty window | `shell` in `kitty.conf` names the wrapper `~/.local/libexec/zsh` |
| `kitten ssh` to one of your machines | `login_shell` in `ssh.conf` names the same wrapper on the remote |
| a tmux pane | `default-shell` in `tmux.conf` |
| `:!` and `:terminal` in neovim | `shell` in `core/options.lua` |

The last four start the pixi zsh directly, so no system zsh starts first and
kitty's shell integration survives. Each of them falls back when the pixi zsh
is missing, as it is on the first apply of a machine, before `pixi global sync`
has run, or after an update that broke it.

### The handoff in the login profiles

`~/.zprofile` and `~/.bash_profile` hand over only when all of these hold. Each
condition prevents a specific failure.

- **The shell is interactive.** `scp`, `sftp` and `rsync` run a non-interactive
  shell and read its output as data, so anything an unexpected shell prints
  corrupts the transfer. A job script that starts with `#!/bin/bash -l` runs a
  login shell that is not interactive, and replacing that shell changes what
  the submitted job runs.
- **It was not given a command:** `$ZSH_EXECUTION_STRING` or
  `$BASH_EXECUTION_STRING` is empty. `bash -lic cmd` is interactive and a login
  shell at once, and kitty runs `$SHELL -l -i -c env` to find your editor. The
  hand-made handoff this replaced exec'd zsh there and silently dropped the
  command, which was reproduced on sicc on 2026-09-21.
- **`NO_ZSH` is unset.** It is the way to stay in the system shell on purpose.
- **`$SHELL` is not already `~/.pixi/bin/zsh`.** This is what stops an exec
  loop. The handoff exports it before the exec, tmux sets it in every pane to
  its `default-shell`, and the wrapper exports it, so a login shell that
  already is the pixi zsh never execs itself again. If the check ever misfires,
  the cost is one extra start, not a loop. It also means that `/usr/bin/zsh -l`
  typed inside the pixi zsh stays in the system zsh, as asked.
- **`~/.pixi/bin/zsh -fc :` succeeds.** A `-x` test only proves the trampoline
  exists, and it can exist while the environment behind it is gone; after an
  `exec` there is no way back to the login shell. The test run took 1.3 ms on
  the workstation and 4 ms on sicc, measured on 2026-09-21.

The files are chosen as carefully as the conditions. zsh reads `.zprofile` for
login shells only, after `.zshenv` and before `.zshrc`. `.zshenv` would also
run for scp and for every command passed over ssh. `.zlogin` runs after
`.zshrc`, so the system zsh would do its whole startup first. `.zshrc` runs
after `/etc/zsh/zshrc`, which on Ubuntu has already run `compinit`.

On the bash side it is `.bash_profile` rather than `.bashrc`, because bash
reads `.bashrc` for every interactive shell, and running `bash` on purpose
would then hand over too. Once `.bash_profile` exists, bash reads it instead of
`~/.profile`, so it sources `~/.profile` itself.

Both files are tracked and reach every machine, because the rule is the same
everywhere; each machine reads only the one that matches its login shell. They
used to be untracked, when the handoff was wanted only where `chsh` fails, and
the untracked copy on sicc is the one that dropped commands.

### The wrapper that kitty starts

kitty has no fallback of its own. A missing `shell` leaves every new window at
"Failed to launch child" (`kitty/child.c`). The ssh kitten execs a named
`login_shell` without checking that it exists; `bootstrap-utils.sh` in kitty's
shell integration only checks a shell that it looked up itself. So kitty starts
`~/.local/libexec/zsh`, which runs the pixi zsh when the same test run passes
and the recorded login shell when it does not, and exports `SHELL` either way.

It is named `zsh` because kitty chooses its shell integration from the file
name alone (`get_supported_shell_name` in `kitty/shell_integration.py`), so
whichever zsh ends up running gets the integration. It lives outside `PATH` so
that nothing else takes it for zsh. All of this was checked against kitty
0.49.0 on 2026-09-21.

`ssh.conf` names the wrapper only for the aliases listed as `sshHosts` in
`.chezmoidata/machines.toml`, never for `hostname *`, so a machine you ssh into
for a one-off task is not affected. A machine this repository never set up has
no wrapper, and the kitten would fail on it at once. A machine of yours whose
last apply predates the wrapper fails the same way; `chezmoi update` over plain
ssh fixes it. The comment in `ssh.conf` explains why the value is written with
`$HOME` and not `~`.

### Getting back to the system shell

Set `NO_ZSH=1`, or connect with the command below, which reads no profile at
all.

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

The function also decides between the kitten and plain ssh. It runs
`kitten ssh` only when stdin and stdout are both a terminal, and `command ssh`
otherwise. The kitten exists for interactive sessions, and without a terminal it
stops at once:

```
Error: The SSH kitten is meant for interactive use only, STDIN must be a terminal
```

Before 2026-09-21 the function called the kitten unconditionally, so
`ssh host cmd < file` failed, and so did ssh from every AI agent's shell, whose
stdin is `/dev/null`. Agents had to know to type `command ssh`. A piped stdout
gets plain ssh as well, because the kitten's bootstrap talks to the terminal and
its traffic ended up in the pipe when tried under a test terminal.

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
