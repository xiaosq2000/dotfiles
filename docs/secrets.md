# Secrets

This repository is public, so every secret in it is age ciphertext in a file
named `encrypted_*`. chezmoi decrypts those files on apply with the private key
at `~/.config/chezmoi/key.txt`, which is never committed. Bitwarden holds a
copy of the key in the item `chezmoi age identity`, so a new machine can fetch
it. The public half, the recipient, is in `.chezmoidata/secrets.toml`.

## What is encrypted

| Secret | Source path |
| --- | --- |
| `~/.ssh/config` | `private_dot_ssh/encrypted_private_config.age` |
| Machine pages of the `machines` skill | `dot_agents/skills/private_machines/references/encrypted_private_*.md.age` |

`.chezmoidata/machines.toml` stays in plaintext on purpose. Bundles and roles
are not secret. Its pixi cache paths do name university filesystems, and they
could move behind encryption at a cost. A machine's first apply runs before its
key arrives, so without the paths it would put the pixi cache in home, which on
sicc is an NFS quota.

## Which machines have the key

The workstation, the laptop, imrl and sicc. The vps never gets it, because it
is internet-facing, and it applies everything except the encrypted files.

Check a machine rather than trusting this list. A claim that imrl and sicc had
no key was once copied from note to note while it was false.

```sh
age-keygen -y ~/.config/chezmoi/key.txt    # must print age1ke4rf2j…
chezmoi managed | grep '^\.ssh/config$'    # the encrypted files are managed
```

## Reading and editing

```sh
chezmoi cat ~/.ssh/config      # print the plaintext
chezmoi edit ~/.ssh/config     # decrypt, open $EDITOR, re-encrypt
```

An agent cannot drive `chezmoi edit`, which waits for an interactive editor. It
edits the decrypted file in `~` and hands it back with
`chezmoi re-add <path>`, which keeps the file encrypted.

On a machine with the key, `git diff` in this repository shows `.age` files
decrypted. GitHub always shows ciphertext.

## Adding an encrypted file

1. `chezmoi add --encrypt <path>`, then `git status` to confirm the new
   `encrypted_*` file landed in this repository.
2. Add the target to the no-key block at the end of `.chezmoiignore`.
3. If the file sits in a directory that held no secrets before, add that
   directory to `PROTECTED` in `.github/scripts/check-encrypted.sh`.

## Setting up a new machine

1. `chezmoi init --apply --promptString machine=<name> xiaosq2000`. This
   installs rbw with the `secrets` bundle and skips the encrypted files, because
   the key is not there yet.
2. Set up rbw and run `rbw unlock`; see below for the first time.
3. `chezmoi apply`. This fetches the key from Bitwarden. If it says the vault
   is locked, the fetcher will not try again by itself; install the key by
   hand as shown below.
4. `chezmoi apply` once more. An apply that starts without the key leaves the
   encrypted files out even if it fetches the key partway, so they land now.
5. Check with the two commands under
   [Which machines have the key](#which-machines-have-the-key).

The fetcher cannot unlock the vault itself, because chezmoi runs it without a
terminal. Instead of steps 3 and 4, you can install the key by hand and apply
once:

```sh
mkdir -p ~/.config/chezmoi
rbw get "chezmoi age identity" > ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt
chezmoi apply
```

### First-time rbw setup

```sh
rbw config set email <your-address>
rbw register    # once, with the personal API key; bitwarden.com only
rbw login
rbw unlock
```

- Against bitwarden.com, skipping `rbw register` makes `rbw login` fail with
  `api request returned error: 400`. That is bot detection, not a wrong
  password. The API key is in the web vault under Settings, Security, Keys,
  "View API Key". A self-hosted Vaultwarden instead needs
  `rbw config set base_url <url>` and no API key.
- On a GNOME desktop, rbw's password prompt grabs the keyboard and pointer, so
  you cannot switch to the browser to copy the API key. Use the terminal prompt
  instead, and paste with Ctrl+Shift+V in kitty:

  ```sh
  rbw config set pinentry pinentry-curses
  rbw stop-agent    # required; the running agent keeps the old prompt
  ```

- Over SSH the prompt is a terminal prompt already.

## Rotating the key

1. Create a new key with `age-keygen -o`.
2. Re-encrypt every `encrypted_*` file to the new recipient.
3. Update `ageRecipient` in `.chezmoidata/secrets.toml` and the Bitwarden item.
4. Run `chezmoi init` on every machine.

Keep the old key until every machine has the new one. A machine with neither
cannot apply at all.

## Keeping agents away from private keys

Claude Code, Codex and opencode run as you, so by default they can read any
file you can. Two kinds of file are kept from them: ssh private keys, and the
age identity, which decrypts every `encrypted_*` file in this repository. If an
agent read either one, the key would go to the model provider, and an agent
misled by a web page or a file it read could send the key anywhere.

The guarded files:

- every name in `~/.ssh` except `config`, `config.d`, `known_hosts`,
  `authorized_keys` and `*.pub`, which covers a key with a custom name without
  listing it;
- `~/.config/chezmoi/key.txt`.

| Agent | What refuses the read | Where it comes from |
| --- | --- | --- |
| Claude Code | `Read` deny rules for the default key names and the age identity, and the key-guard hook | `dot_claude/modify_settings.json` merges both into `~/.claude/settings.json` |
| Codex | The `key-guard` permissions profile, whose bubblewrap sandbox cannot open any `~/.ssh/id_*` file except a `.pub`, and the key-guard hook | `dot_codex/modify_private_config.toml` and `dot_codex/hooks.json` |
| opencode | `read` rules in `opencode.json`, and a plugin that runs the key-guard hook | `private_dot_config/opencode/` |

The hook is `~/.agents/hooks/key-guard.py`. It refuses a tool call that names a
guarded file, and tells the agent to ask you instead. The one exception is a
shell command that names an ssh key only to use it or to look at its name and
mode: `ssh`, `scp` or `sftp -i`, `ssh -o IdentityFile=`, `ssh-add`,
`ssh-keygen -y` or `-l`, and `ls`, `stat`, `test`, `chmod` or `mkdir`. The hook
splits the command into words to find those places. A command sent over ssh is
checked the same way, so `ssh sicc 'mkdir -p ~/.ssh'` passes and
`ssh sicc 'cat ~/.ssh/id_ed25519'` does not. A command the split cannot follow,
such as one with `$(...)`, is refused if it names a key at all, and no command
may name the age identity. The calls it must refuse and the ones it must let
through are listed in `.github/scripts/check-key-guard.sh`, which both
pre-commit and CI run.

In Claude Code, its own `Read` rules still refuse `ls` or `stat` on a default
key name, because Claude Code counts those commands as reading the file.
`ls -la ~/.ssh` shows the same and passes. Checked with Claude Code 2.1.276 on
2026-09-22.

The settings files of Claude Code and Codex are rewritten by the agents
themselves, so chezmoi does not own them. The modify scripts add the guard and
leave every other key alone. The Claude Code script only ever adds rules, so
deleting one from it does not delete it from `~`. The Codex script rewrites its
whole profile on every apply.

**Codex skips the hook until you trust it.** On each machine, after the first
apply that brings `~/.codex/hooks.json`, open Codex and trust the hook in
`/hooks`. Do it again whenever `hooks.json` changes. Until then only the sandbox
profile guards the keys in Codex.

A key with a custom name is already covered by the hook and by opencode's rules.
Codex's sandbox covers any name that starts with `id_` and does not end in
`.pub`, so name a new key `id_*`. Claude Code's `Read` rules list the default
names only (`id_rsa`, `id_ed25519` and the rest). To cover another name there,
add it to the list in `dot_claude/modify_settings.json`.

What none of this stops:

- **A command that builds the path at run time.** The hook matches text, so a
  command that decodes a key path from base64 gets past it. For an `id_*` key,
  Codex's sandbox still refuses the read. In Claude Code and opencode
  nothing else does. Claude Code's own sandbox would, but it was turned down on
  2026-09-21: it also puts every Bash command behind a network allowlist, and it
  needs bubblewrap and socat installed on each machine.
- **A key path passed on through a file.** The hook lets `ls -d ~/.ssh/*` print
  key paths and refuses piping them into `xargs cat`, but a command that saves
  them to a file for a later command to open gets past it. That is the same
  gap as a path built at run time.
- **A Codex command you approve to run outside the sandbox.** Only the hook
  sees it.
- **A command you type yourself** with `!` in Claude Code. No hook sees it.
- **What an MCP server does in its own process.** The hooks see the arguments of
  an MCP call, not the files the server opens.

A passphrase on the key is the one guard that no agent gets around:
`ssh-keygen -p -f ~/.ssh/id_ed25519`. An agent that reads the file then gets
ciphertext. A hardware key made with `ssh-keygen -t ed25519-sk` goes further:
the file on disk is only a handle to the device.

## Caveats

- **A missing key aborts the whole apply, not just the file.** Every target
  sorting after the encrypted one is left untouched. That is why every
  encrypted target needs its entry in the no-key block of `.chezmoiignore`. CI
  checks this with a keyless apply. As a one-off escape hatch,
  `chezmoi apply --exclude=encrypted` works.
- **The attribute order is `encrypted_private_`.** `private_encrypted_` is not
  an error: chezmoi leaves the file unmanaged and writes nothing, with no
  message.
- **`encryption = "age"` has to sit above `[data]` in `.chezmoi.toml.tmpl`.**
  Below it, TOML makes it `data.encryption`, and chezmoi carries on unencrypted
  with only a warning. CI checks the order.
- **The key fetcher, `run_onchange_before_00-age-identity.sh`, must never exit
  non-zero.** It runs before any file is written, so a failure there would stop
  every file from applying. It must also stay `run_onchange_` with its
  rbw-present marker line. As `run_once_` it never retries after the first
  apply fails for lack of rbw, and as a plain `run_` it makes `chezmoi verify`
  fail for good.
- **The plaintext guards work only where the hooks are installed.** Three
  pre-commit hooks refuse a commit:
  - `check-encrypted` refuses plaintext under the protected directories;
  - `detect-private-key` refuses an ssh or TLS private key under any name;
  - `no-age-identity` refuses an age identity.

  `run_onchange_after_08-source-repo.sh` installs the hooks on every machine
  that has pre-commit. In a clone without them, nothing stops such a commit
  before the push, and CI runs only after the push has published it.
  `.gitignore` names the usual key files too, but it stops only `git add .`;
  `git add -f` gets past it.
- **`chezmoi add` writes into whichever source tree its config names.** With
  an unexpected `HOME` or `XDG_CONFIG_HOME`, a new encrypted file can land in
  another repository. Run `git status` after every `add --encrypt`.
- **Codex's deny list takes globs, never an exact path.** For an exact path
  that does not exist, Codex creates an empty 0444 file there while each
  sandboxed command runs, and a command that dies leaves the file behind. ssh
  then warns about it as an unprotected private key. Checked with codex-cli
  0.155.1 on 2026-09-22. To delete such files, which touches empty files only:

  ```sh
  find ~/.ssh -maxdepth 1 -name 'id_*' -type f -empty -delete
  ```
