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
- **The plaintext guard works only where the hooks are installed.** The
  `check-encrypted` pre-commit hook refuses plaintext under the protected
  directories. `run_onchange_after_08-source-repo.sh` installs the hooks on
  every machine that has pre-commit. In a clone without them, nothing stops a
  plaintext commit before the push, and CI runs only after the push has
  published it.
- **`chezmoi add` writes into whichever source tree its config names.** With
  an unexpected `HOME` or `XDG_CONFIG_HOME`, a new encrypted file can land in
  another repository. Run `git status` after every `add --encrypt`.
