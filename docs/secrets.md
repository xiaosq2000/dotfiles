# Secrets

This repository is public, so anything secret in it has to be ciphertext. The
scheme is chezmoi's own: a file named `encrypted_*` is age ciphertext, chezmoi
decrypts it on apply, and the private key is never committed. Bitwarden holds
one copy of that key so a new machine can fetch it once.

Nothing is encrypted yet. `.chezmoidata/secrets.toml` has an empty
`ageRecipient`, which is the off state: the generated chezmoi config omits its
`[age]` section entirely, so every machine applies normally without a key.
[Turning it on](#turning-it-on) is a few commands, and the only one that needs
you specifically is the Bitwarden entry.

## Why bother

`~/.secrets` is a git repository with no remote. `git -C ~/.secrets remote -v`
prints nothing, so the SSH config and the API tokens in it exist on exactly one
disk and have never been anywhere else. A disk failure loses them.

Encrypted copies here get pushed to GitHub with everything else, which turns the
problem into keeping one key safe, and Bitwarden already does that.

The plaintext half of the same problem is already solved:
[.chezmoidata/machines.toml](../.chezmoidata/machines.toml) is the machine
inventory, in the clear, because roles, bundles and filesystem layout are not
secrets. What is secret is the addresses, account names and tokens.

## What goes where

| Thing | Where | Committed |
| --- | --- | --- |
| Machine inventory: bundles, roles, cache paths | `.chezmoidata/machines.toml` | yes, plaintext |
| age recipient, the public half | `.chezmoidata/secrets.toml` | yes, plaintext |
| age identity, the private half | `~/.config/chezmoi/key.txt` | never |
| A copy of the identity | Bitwarden entry `chezmoi age identity` | n/a |
| SSH config, tokens | `encrypted_*` files here | yes, as ciphertext |

A recipient can only encrypt, so publishing it costs nothing. `.chezmoiignore`
lists `.config/chezmoi/key.txt` so a stray `chezmoi add` cannot pull the
identity in.

## Turning it on

Do this on the machine you trust most. Every command was run against this
repository in a sandbox before being written down.

**1. Create the key.**

```sh
mkdir -p ~/.config/chezmoi
age-keygen -o ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt
age-keygen -y ~/.config/chezmoi/key.txt    # prints the recipient: age1...
```

`age-keygen -o` also prints the public key, to stderr, when it creates the file.

**2. Put the identity in Bitwarden.** This is the step nothing can do for you.
Create an entry named `chezmoi age identity` whose **password** is the single
`AGE-SECRET-KEY-…` line from the file. Either:

```sh
rbw config set email <your-address>    # first time on this machine
rbw login
rbw add "chezmoi age identity"
```

or paste it into the web vault. To use a custom field instead of the password,
set `bitwardenField` in `.chezmoidata/secrets.toml`.

Check it comes back:

```sh
rbw get "chezmoi age identity" | head -c 20    # AGE-SECRET-KEY-1...
```

**3. Record the recipient** in `.chezmoidata/secrets.toml`, then regenerate the
chezmoi config so it grows an `[age]` section.

Doing this before the other machines have the key is safe. They warn on apply
and carry on, because the identity fetcher never fails the run; only an
encrypted file would fail, and there are none until step 4. So the order that
matters is: recipient and key distribution before the first `encrypted_` file
is committed, not before this step.

```sh
chezmoi edit .chezmoidata/secrets.toml   # set ageRecipient = "age1..."
chezmoi init --promptString machine=workstation
chezmoi dump-config | grep -A3 age       # identity and recipient should be set
```

**4. Move a secret in.** For the SSH config:

```sh
chezmoi add --encrypt ~/.ssh/config
chezmoi cat ~/.ssh/config                # should print the plaintext back
```

Then move the entry so `~/.ssh` itself is created 0700:

```sh
cd "$(chezmoi source-path)"
mkdir -p private_dot_ssh
git mv dot_ssh/encrypted_private_config.age private_dot_ssh/
rmdir dot_ssh
```

**5. Commit and push.** The ciphertext is meant to be published. Before pushing,
confirm that is all you are publishing:

```sh
git status --short
git diff --cached --stat
head -c 34 private_dot_ssh/encrypted_private_config.age   # BEGIN AGE ENCRYPTED FILE
```

## A new machine

`run_once_before_00-age-identity.sh` fetches the identity from Bitwarden before
chezmoi writes any file, but it cannot unlock a locked vault: chezmoi runs it
without a terminal, so a passphrase prompt would have nowhere to appear. So
either unlock first, or do it by hand:

```sh
rbw unlock
chezmoi init --apply --promptString machine=<name> xiaosq2000
```

```sh
# by hand, no script involved
mkdir -p ~/.config/chezmoi
rbw get "chezmoi age identity" > ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt
```

The script verifies the key it fetched matches the repository's recipient, with
`age-keygen -y`, so pulling the wrong entry fails with a clear message instead
of an age error on some unrelated file later.

## Editing and rotating

```sh
chezmoi edit ~/.ssh/config     # decrypts, opens $EDITOR, re-encrypts
chezmoi cat ~/.ssh/config      # read without editing
```

To rotate, create a new key, re-encrypt every `encrypted_*` file to the new
recipient, update `ageRecipient`, update Bitwarden, and re-run `chezmoi init`
on every machine. Keep the old key until every machine has the new one, because
a machine with neither cannot apply at all.

## Four things worth knowing

**`encryption` has to sit above `[data]`.** A bare key after a table header
belongs to that table in TOML, so `encryption = "age"` written at the bottom of
the config becomes `data.encryption`. chezmoi then warns and carries on
unencrypted:

```
warning: 'encryption' not set, using age configuration.
```

**The attribute order is `encrypted_private_`, not `private_encrypted_`.** Only
the first is recognised. The second is not an error: chezmoi treats the file as
unmanaged and silently writes nothing, so the target never appears and there is
no message saying why.

**A missing identity fails that file, not the whole apply.** chezmoi writes
nothing for the encrypted entry, which is the behaviour you want: there is no
path where a secret lands as plaintext or an empty file. Everything else still
applies, because `run_once_before_00-age-identity.sh` warns rather than exiting
non-zero. It did exit non-zero at first, and that aborted the apply before a
single file was written, which would have left a keyless machine unable to
update anything at all.

**`chezmoi add` resolves its source directory from whichever config it finds.**
Running it with an unexpected `HOME` or `XDG_CONFIG_HOME` writes the new entry
into a different repository than you meant. It is worth a `git status` after
every `add --encrypt`.
