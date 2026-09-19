# Secrets

This repository is public, so anything secret in it has to be ciphertext. The
scheme is chezmoi's own: a file named `encrypted_*` is age ciphertext, chezmoi
decrypts it on apply, and the private key is never committed. Bitwarden holds
one copy of that key so a new machine can fetch it once.

## Where this stands

Encryption is on, since 2026-09-19.

| | |
| --- | --- |
| Key created | done, `~/.config/chezmoi/key.txt` |
| Recipient recorded | done, `age1ke4rf2j…` in `.chezmoidata/secrets.toml` |
| `~/.ssh/config` encrypted | done, `private_dot_ssh/encrypted_private_config.age` |
| Deployed to all three machines | done |
| Key backed up in Bitwarden | done, item `chezmoi age identity`, verified 2026-09-19 |

Verified rather than assumed: `rbw get "chezmoi age identity" | age-keygen -y`
prints `age1ke4rf2j…`, the same recipient this repository encrypts to. A backup
that has not been read back is a hope, not a backup.

imrl and sicc still carry no key, and that is fine. `.chezmoiignore` leaves the
encrypted entries unmanaged there and both apply everything else in full. They
pick up `~/.ssh/config` the moment a key arrives, with no other change.

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

## The full procedure

All five steps are done on the workstation. This is kept for a new machine, for
rotation, and because the rbw notes in step 2 are worth having written down
somewhere.

**1. Create the key.** Done.

```sh
mkdir -p ~/.config/chezmoi
age-keygen -o ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt
age-keygen -y ~/.config/chezmoi/key.txt    # prints the recipient: age1...
```

`age-keygen -o` also prints the public key, to stderr, when it creates the file.

**2. Put the identity in Bitwarden.** Done, via rbw.

The backup itself needs no tooling: an item called `chezmoi age identity` whose
password is the `AGE-SECRET-KEY-…` line from `~/.config/chezmoi/key.txt`, made
in the web vault or the app, is the whole thing.

rbw buys the second half, which is a machine fetching that item by itself, and
it is now working here. imrl and sicc do not have it set up yet.

First get rbw talking to the server. Against the official bitwarden.com this
needs `rbw register` before `rbw login`, and skipping it fails in a way that
looks like a rejected password:

```
rbw login: failed to log in to bitwarden instance: api request returned error: 400
```

That is bot detection, not a wrong password. rbw's own help for `register` says
so: the official server requires you to log in with a personal API key once,
after which ordinary logins work. Get the key from the web vault under
Settings, Security, Keys, "View API Key". It gives a `client_id` beginning
`user.` and a `client_secret`; `rbw register` prompts for both.

```sh
rbw config set email <your-address>
rbw register                            # asks for the personal API key
rbw login
rbw unlock
```

A self-hosted Vaultwarden needs `rbw config set base_url <url>` first and no
API key. If the account has two-factor authentication, rbw prompts for the code
during `rbw login`.

Then create an entry named `chezmoi age identity` whose **password** is the
single `AGE-SECRET-KEY-…` line from the key file:

```sh
rbw add "chezmoi age identity"
```

or paste it into the web vault. To use a custom field instead of the password,
set `bitwardenField` in `.chezmoidata/secrets.toml`.

Check it comes back:

```sh
rbw get "chezmoi age identity" | head -c 20    # AGE-SECRET-KEY-1...
```

> **The GNOME prompt will not let you go and fetch the secret.**
>
> rbw prompts through pinentry, and on a desktop `/usr/bin/pinentry` resolves to
> `pinentry-gnome3`, which uses GNOME's GCR system prompt. That prompt takes a
> keyboard and pointer grab for as long as it is open, deliberately, so that
> nothing else can read what you type. The effect during `rbw register` is that
> you cannot switch to the browser to copy the `client_secret`, which looks like
> the clipboard refusing to hold it. The clipboard is fine: whatever was copied
> before the dialog opened still pastes in with Ctrl+V.
>
> pinentry-gnome3 does accept `OPTION no-grab`, but rbw never sends it, so the
> grab cannot be turned off from rbw's side. Move rbw to the terminal prompt
> instead:
>
> ```sh
> rbw config set pinentry pinentry-curses
> rbw stop-agent
> rbw register
> ```
>
> `rbw stop-agent` is not optional. The running agent holds the pinentry choice,
> so without it the GNOME dialog comes back. Paste into the terminal with
> Ctrl+Shift+V in kitty, and set it back to `pinentry-gnome3` afterwards if you
> prefer a graphical prompt for day-to-day unlocking.
>
> There is no way round the prompt entirely: rbw 1.15 reads the API key from
> neither an environment variable nor a file. On Wayland, keep the browser open
> after copying, because the clipboard needs its source window alive.

Over SSH this does not arise. sicc's default is already `pinentry-curses`, and
imrl's `pinentry-gnome3` falls back to a terminal prompt with no display.

**3. Record the recipient** in `.chezmoidata/secrets.toml`, then regenerate the
chezmoi config so it grows an `[age]` section. Done.

Doing this before the other machines have the key is safe. They warn on apply
and carry on, because the identity fetcher never fails the run; only an
encrypted file would fail, and there are none until step 4. So the order that
matters is: recipient and key distribution before the first `encrypted_` file
is committed, not before this step.

```sh
# set ageRecipient = "age1..."
$EDITOR "$(chezmoi source-path)/.chezmoidata/secrets.toml"
chezmoi init --promptString machine=workstation
chezmoi dump-config | grep -A3 age       # identity and recipient should be set
```

Not `chezmoi edit`, which takes the path of a file in `~` and looks up its
source. This file has no target: it is data chezmoi reads and never deploys, so
`chezmoi edit` answers

```
chezmoi: .chezmoidata/secrets.toml: not managed
```

The same goes for `machines.toml`, `tools.toml`, the theme files,
`.chezmoiignore`, `.chezmoiexternal.toml` and `.chezmoiremove`. `chezmoi cd`
opens a shell where all of them are in front of you.

**4. Move a secret in.** Done for the SSH config:

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

**5. Commit and push.** Committed; not pushed. The ciphertext is meant to be
published. Before pushing, confirm that is all you are publishing:

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

**A missing identity aborts the apply, it does not skip the file.** This is the
one to know. chezmoi writes nothing for the encrypted entry, so no secret ever
lands as plaintext or an empty file, but it then stops where it stood: every
target sorting after the failed one is left untouched. `.ssh/config` sorts before
`.zshrc`, so a machine whose vault happened to be locked would quietly stop
updating its shell config, and the only error would name `~/.ssh/config`.

`.chezmoiignore` therefore drops the encrypted entries on a machine with no
identity, and such a machine applies everything else in full. Add an entry there
for each new `encrypted_` file. CI checks the outcome rather than the list: a
keyless apply has to verify clean and produce a target that sorts after the
encrypted one.

If you ever need to apply on a keyless machine before that gate covers a new
file:

```sh
chezmoi apply --exclude=encrypted
```

Two related failures are separate and both handled.
`run_once_before_00-age-identity.sh` warns rather than exiting non-zero, because
it runs `before` and a non-zero exit there aborts the apply before a single file
is written.

**`chezmoi add` resolves its source directory from whichever config it finds.**
Running it with an unexpected `HOME` or `XDG_CONFIG_HOME` writes the new entry
into a different repository than you meant. It is worth a `git status` after
every `add --encrypt`.
