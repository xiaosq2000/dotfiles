# Agent guide

This repository is the [chezmoi](https://www.chezmoi.io/) source for the user's
dotfiles, applied to five machines. Its usual home is `~/.local/share/chezmoi`,
and `chezmoi source-path` prints it. [README.md](README.md) explains the layout
and daily use. This file lists what an agent has to know before changing
anything, because several mistakes here are silent or public.

## The source tree is not the home directory

chezmoi renders the files here into `~`. Editing `~/.zshrc` changes nothing in
this repository, and the next `chezmoi apply` overwrites the edit. Change the
source, then run `chezmoi diff` to see what would happen in `~`.

File names carry attributes, and the order matters:

| Prefix or suffix | Meaning |
| --- | --- |
| `dot_` | a leading `.` in the target name |
| `private_` | mode 0600 for a file, 0700 for a directory |
| `executable_` | the executable bit |
| `encrypted_` | age ciphertext, decrypted on apply; always `encrypted_private_`, because `private_encrypted_` is silently left unmanaged |
| `.tmpl` | a Go template, rendered on apply |
| `run_onchange_before_` and `run_onchange_after_` | scripts that run when their rendered text changes |

Some files have no target in `~`. `.chezmoidata/*.toml`, `.chezmoiignore`,
`.chezmoiexternal.toml` and `.chezmoi.toml.tmpl` are read by chezmoi and never
deployed, so edit them in the source tree directly. `chezmoi edit` cannot reach
them.

A file at the root that is repository infrastructure, such as `README.md`,
`docs/`, this file and `CLAUDE.md`, needs an entry in `.chezmoiignore`, or
chezmoi deploys it into `~`. Names starting with `.`, such as `.github` and
`.gitattributes`, are skipped by chezmoi on their own.

Per-machine behaviour is a lookup in `.chezmoidata/machines.toml`, keyed by the
`machine` answer given at `chezmoi init`, never by the hostname. Run `machine`
to see the current entry. Tools come from the bundles in
`.chezmoidata/tools.toml`, and a `pixi global install` by hand is undone by the
next apply.

## The repository is public

Anything secret lives in an `encrypted_*` file. That covers `~/.ssh/config` and
the machine pages of the `machines` skill. Addresses, account names, private
domains and tokens are secret, so keep them out of plaintext files, commit
messages and pull request text as well. The filesystem paths in
`machines.toml` are the one deliberate exception; `docs/secrets.md` explains
why.

`chezmoi edit` opens an interactive editor, so an agent works on encrypted files
this way instead:

```sh
chezmoi cat ~/.ssh/config                        # read the plaintext
# edit the deployed file in ~, then:
chezmoi re-add ~/.ssh/config                     # re-encrypts; keeps encrypted_
chezmoi add --encrypt ~/path/to/new-secret-file  # a new encrypted file
```

Never write plaintext into the source tree, even for a moment, and never
`chezmoi add` a secret without `--encrypt`. The `check-encrypted` pre-commit
hook refuses both under the protected directories, but only in a clone where
`pre-commit install` has run. `run_onchange_after_08-source-repo.sh` does that
on every machine with pre-commit.

A new encrypted target needs two more changes:

1. An entry in the no-key block at the end of `.chezmoiignore`. Without it, a
   machine with no key aborts its whole apply at that file. CI catches this.
2. If it sits in a new directory, that directory in `PROTECTED` in
   `.github/scripts/check-encrypted.sh`.

Agents cannot read ssh private keys or the age identity. A hook and each
agent's own read rules refuse any call that could read one, as `docs/secrets.md`
explains. A shell command may still use an ssh key by name, as in `ssh -i`, or
list it with `ls`. If a call is refused, the guard is working, not broken: ask
the user instead of finding another route to the file.

In a clone where the key is present, `git diff` shows `.age` files decrypted,
through the `age` diff driver in `.gitattributes`. On GitHub they stay
ciphertext. The vps has no key and never will.

## Checking a change

```sh
chezmoi diff                          # what apply would change in ~
chezmoi apply && chezmoi verify       # verify exits 0 once ~ matches
pre-commit run --all-files
```

To check a change without touching `~`, for example from a git worktree, point
chezmoi at the other source tree:

```sh
chezmoi --source "$PWD" diff
chezmoi --source "$PWD" cat ~/.zshrc
chezmoi --source "$PWD" managed
```

CI in `.github/workflows/ci.yml` bootstraps a clean container with no key and
asserts on the result. When a change alters what lands in `~`, add an
assertion there. Write a negated one as `! grep -q x file || exit 1`, because
`set -e` ignores a command negated with `!`; a pre-commit hook enforces it.

A run script must not fail the apply over a missing optional tool. It warns and
exits 0. This matters most for `before` scripts, where a non-zero exit stops the
apply before any file is written.

## Commits and writing

Commit messages follow Conventional Commits, and the commit-msg hook enforces
it. `git log --oneline` shows the scopes in use, such as `feat(zsh)`,
`fix(secrets)` and `docs(todo)`.

Comments and documents here explain why, in full sentences, and date any fact
that can go stale ("checked on 2026-09-21"). Match that. Say what was verified
and what was assumed.

Documents under `docs/` say what to do next. History belongs in git: keep a past
event only as a caveat that changes what someone would do, and delete a todo
entry once it is done.

## Where things are written down

| Topic | Place |
| --- | --- |
| Install, daily use, themes, bundles | [README.md](README.md) |
| Encryption design and key handling | [docs/secrets.md](docs/secrets.md) |
| Open work | [docs/todo.md](docs/todo.md) |
| Shell setup constraints | [dot_sh_utils/CAVEATS.md](dot_sh_utils/CAVEATS.md) |
| Shared agent skills | [dot_agents/skills/README.md](dot_agents/skills/README.md) |
| Facts about each machine | the `machines` skill, at `~/.agents/skills/machines` where the key is |
