# Secrets

Checked on 2026-11-23.

This repository is public, so every secret in it is age ciphertext in a file
named `encrypted_*`. chezmoi decrypts those files on apply with its built-in Go
age implementation (`useBuiltinAge = true` in `.chezmoi.toml.tmpl`, so applying
never depends on `mise`'s external `age` shim) using the private key
at `~/.config/chezmoi/key.txt`, which is never committed. Bitwarden holds a
copy of the key in the item `chezmoi age identity`, so a new machine can fetch
it. The public half, the recipient, is in `.chezmoidata/secrets.toml`.

## What is encrypted

| Secret | Source path |
| --- | --- |
| `~/.ssh/config` | `private_dot_ssh/encrypted_private_config.age` |
| Machine pages of the `machines` skill | `private_dot_agents/skills/private_machines/references/encrypted_private_*.md.age` |

`.chezmoidata/machines.toml` stays in plaintext on purpose. Bundles and roles
are not secret. Its pixi cache paths do name university filesystems, and they
could move behind encryption at a cost. A machine's first apply runs before its
key arrives, so without the paths it would put the pixi cache in home, which on
sicc is an NFS quota.

## Checks before publication

| Check | Scope |
| --- | --- |
| Gitleaks pre-commit hook | Changed files from the Git index |
| Gitleaks pre-push hook | Every outgoing commit, including merge changes and commit or annotated-tag messages |
| GitHub secret scanning and push protection | GitHub-supported secret patterns |

GitHub secret scanning and push protection are enabled. Enabling secret scanning
also starts GitHub's automatic history scan. There is no separate local history
audit or Gitleaks CI scan. CI still runs the existing encryption and key guards.

The `core` bundle installs Gitleaks through `mise` (following latest;
`.github/scripts/check-secrets.py` enforces `>= 8.30.0`, checked on 2026-11-20).
`.gitleaks.toml` adds the broad age-identity pattern from the existing guard.
The hook checks account paths separately.

The local scanner reads raw Git blobs. It does not run the age diff driver or
decrypt private files. It skips ciphertext only under an `encrypted_*.age`
name with an age header. Plaintext in protected directories fails the check.
Findings show the file, line, and rule, but not the matched value.

The pre-push hook queries the destination's refs and checks commits that the
destination does not already contain. It checks new branches and every ref in
a multi-ref push. Missing tools, scan errors, shallow history, and refs that
do not resolve to commits stop the operation.

`.chezmoiscripts/run_onchange_after_08-source-repo.sh.tmpl` installs both local
hooks during apply. An unrelated pre-push hook stays unchanged, with a warning.
For a clone outside the chezmoi source path, install them explicitly:

```sh
pre-commit install
ln -s "$PWD/.github/scripts/check-secrets.py" "$(git rev-parse --git-path hooks/pre-push)"
```

Do not replace an existing pre-push hook without checking its purpose.
Local hooks can be bypassed. GitHub protection covers supported patterns only.
Gitleaks does not reliably recognize private addresses, domains, or account
names without a targeted rule. Keep private machine facts encrypted.

Run local regression tests without scanning this repository's history:

```sh
python3 tests/check_secrets_tests.py
```

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
decrypted through the `age` text-conversion driver in `.gitattributes`.
Difftastic (`git dft`) bypasses text-conversion drivers and stays opt-in.
GitHub always shows ciphertext. Checked on 2026-11-19.

## Adding an encrypted file

1. `chezmoi add --encrypt <path>`, then `git status` to confirm the new
   `encrypted_*` file landed in this repository.
2. Add the target to the no-key block at the end of `.chezmoiignore`.
3. If the file sits in a directory that held no secrets before, add that
   directory to `protected_source_dirs` in `.chezmoidata/policy.toml`.

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

Checked on 2026-11-23.

All four primary coding agents run as you, so by default they can read any file
you can. Guarded files include ssh private keys, `~/.config/chezmoi/` (except
`chezmoi.toml` and `chezmoistate.boltdb`), `~/.secrets`, vault extraction
subcommands (`rbw get`/`dump`, `secret-tool lookup`/`search`), and local CLI /
agent credential files. Agent settings live in `.chezmoidata/agents.toml`,
shared secret-masking lists live in `.chezmoidata/policy.toml`, and
`dot_local/libexec/dotfiles/executable_agent-reconcile.py` reconciles both into
each agent's native config.

| Agent | What refuses the read | Where it comes from |
| --- | --- | --- |
| Claude Code | `Read` and `Bash(gh ...)` deny/ask rules, strict/remote-control privacy env, and the `key-guard.py` hook | `private_dot_claude/modify_private_settings.json.tmpl` |
| Codex | The `key-guard` bubblewrap permissions profile (populated from `.chezmoidata/policy.toml` across terminal, desktop app, and remote SSH `app-server` proxy), `[otel]` privacy defaults, `rules/gh.rules` (including `gh api` prompt), and the `key-guard.py` hook | `private_dot_codex/modify_private_config.toml.tmpl` and `private_dot_codex/modify_private_hooks.json.tmpl` |
| Antigravity CLI (`agy`) | `PreToolUse` JSON hook delegating to `key-guard.py` (`{"decision":"deny"}` on secrets, `{"decision":"allow"}` otherwise — enforced even with `--dangerously-skip-permissions`) | `private_dot_gemini/private_config/modify_private_hooks.json.tmpl` |
| Pi | Local `dotfiles-guard.ts` extension delegating `tool_call` checks to `key-guard.py` (including foreground subagents via `defaultSubagentOnlyExtensions`) | `private_dot_pi/private_agent/extensions/dotfiles-guard.ts` and `modify_private_settings.json.tmpl` |

OS-level sandboxing (`agent-jail`) and unified security policy live in
`.chezmoidata/policy.toml` (rendered to `~/.config/dotfiles/policy.json`, also
read by `agent-reconcile.py`, `key-guard.py`, `check-encrypted.sh`, and
`check-secrets.py`).

### OS sandboxing (`agent-jail` and Codex `key-guard`)

Interactive `zsh` and `bash` shells wrap `claude`, `agy`, and `pi` in
`agent-jail --wrap <agent>` by default (help, version, login, and management
subcommands pass through directly). `codex` runs directly in interactive shells
so it uses its native `key-guard` bubblewrap sandbox and host `app-server`
daemon (matching the Codex desktop app and remote SSH `app-server` proxy); wrap
it explicitly with `dotfiles jail -- codex` or `dotfiles jail --mask-gh -- codex`
when reviewing untrusted repositories.

```sh
claude / agy / pi                      # runs inside agent-jail automatically
codex                                  # runs directly with native key-guard sandbox + app-server daemon
DOTFILES_JAIL_RW=~/datasets claude     # add extra writable directory inside agent-jail
unjail agy                             # bypass agent-jail (e.g. when running chezmoi apply)
DOTFILES_NO_JAIL=1 pi                  # bypass agent-jail for one invocation
dotfiles jail --mask-gh -- codex       # explicit outer bwrap jail (+ --no-daemon) for untrusted repos
dotfiles jail --dry-run --wrap codex   # inspect exact mounts, masked paths, and adapted command
```

- **Primary `agent-jail` backend (`bwrap`)**: mounts `/` read-only, current
  workspace RW, `.git/hooks` and `.git/config` read-only, `/etc/ssh/ssh_config.d`
  hidden, `~/.secrets` as empty `tmpfs`, and SSH private keys / age identity /
  CLI & other-agent credentials over-mounted with `/dev/null`, while passing
  through `SSH_AUTH_SOCK`, `HERDR_SOCKET_PATH`, and `XDG_RUNTIME_DIR`.
  Machine-specific `pixi` cache/environment directories from
  `.chezmoidata/machines.toml` are automatically included as writable paths.
- **Rootless HPC fallback (`landlock`)**: invokes Linux Landlock LSM (ABI v1+)
  directly via syscalls with no root or user namespaces required; blocks reads
  of masked secrets (`EACCES`) and restricts writes to the workspace, `/tmp`,
  caches, and the invoked agent's own state directory.
- **Codex & `gh` behavior**: default `codex` uses its native `key-guard`
  bubblewrap profile (which denies existing `policy.secrets.masked_dirs`,
  `policy.secrets.masked_files` except `.codex/auth.json`, `~/.ssh/id_*` globs,
  and existing custom-named `~/.ssh/` private keys) while staying connected to
  the host `app-server` daemon. When explicitly wrapped via
  `dotfiles jail -- codex` or `agent-jail --wrap codex`, `agent-jail` injects
  `-s danger-full-access` (because Linux `bwrap` cannot nest inside an outer
  `bwrap` namespace) and `--no-daemon` (unless `--no-daemon` or `--remote` is
  passed), keeping the entire Codex process inside `bwrap` (`gh.rules` approvals
  and `key-guard.py` stay active). `~/.config/gh/hosts.yml` remains readable by
  default so `gh pr` / `gh run` work out of the box while `key-guard.py`,
  `gh.rules`, and Claude `deny` rules block reading `hosts.yml` directly or
  running `gh auth token` / `gh secret` / `gh repo delete`; pass `--mask-gh` to
  mask it inside `agent-jail`.

The hook is `~/.agents/hooks/key-guard.py`. It refuses a tool call that names a
guarded file, and tells the agent to ask you instead. The exceptions are
commands that name an ssh key only to use it or to inspect its metadata:
`ssh`, `scp` or `sftp -i`, `ssh -o IdentityFile=`, `ssh-add`,
`ssh-keygen -y` or `-l`, and `ls`, `stat`, `test`, `chmod` or `mkdir`, as well
as inline text that never opens a file: `git commit -m` messages, `gh` PR and
issue `--title` and `--body` text, and `grep` or `rg` search patterns. Flags
that open a file to read message or pattern data (`git commit -F`,
`gh --body-file`, `grep -f`) remain strictly refused. The hook splits the
command into words to find those places. A command sent over ssh is checked the
same way, so `ssh sicc 'mkdir -p ~/.ssh'` passes and
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

A key with a custom name under `~/.ssh/` is covered automatically by
`agent-jail`, `key-guard.py`, and Codex's `key-guard` profile (on `chezmoi apply`,
`agent-reconcile.py` emits exact `deny` rules for existing non-public, non-`*.pub`
entries in `~/.ssh/` not matched by the `id_*` globs; re-run `chezmoi apply`
after adding or removing a custom-named key or local credential file, or name
new ssh keys `id_*` so the globs cover them immediately). Claude Code's `Read`
rules list the default names only (`id_rsa`, `id_ed25519` and the rest); to add
a custom name there, edit `[agents.claude].deny` in `.chezmoidata/agents.toml`.

Agents log in with the key through the ssh agent, so ssh works in Codex's
sandbox although it cannot open the key file. For ssh to run there at all, the
`key-guard` profile also hides `/etc/ssh/ssh_config.d`. In the sandbox, root's
files show as owned by nobody, and ssh refuses to read a config file it
includes that has such an owner. On Ubuntu that stopped every ssh, `git push`
and `scp` in Codex with `Bad owner or permissions`. Hidden, the directory
matches nothing, and ssh runs without its drop-ins. Checked with codex-cli
0.155.1 and OpenSSH 10.2 on 2026-09-22. Where no ssh agent holds the key, ssh
in Codex's sandbox cannot log in with it.

Codex's base `:workspace` profile marks `.git` read-only, which stops in-sandbox
`git commit`, staging (`index.lock`), and branch operations without prompting
for approval. The `key-guard` profile carves out write access for `.git` under
`:workspace_roots`, while keeping `.git/hooks` and `.git/config` read-only.
That lets git operate smoothly in the sandbox while preventing any script or
process from tampering with git hooks or repository configuration (such as
`core.fsmonitor` or `core.hooksPath`).

Routine GitHub CLI operations are managed by Codex execpolicy rules in
`~/.codex/rules/gh.rules` (deployed from `private_dot_codex/rules/gh.rules`).
It allows read-only queries and routine PR work (`gh pr view`, `list`, `diff`,
`checks`, `status`, `create`, `edit`, `comment`, `review`, `ready`), prompts
before destructive or shared state changes (`gh pr merge`, `gh pr close`,
`gh api`), and forbids credential-touching or destructive commands (`gh auth`,
`gh repo delete`, `gh secret`, `gh ssh-key`). Commands not covered by the rules
fall back to Codex's normal approval policy. Checked on 2026-11-19.

### Defense-in-depth boundaries

OS-level sandboxing (`agent-jail` for `claude`/`agy`/`pi` and explicit
`dotfiles jail` sessions; Codex's native `key-guard` bubblewrap profile for
`codex` CLI, desktop app, and remote `app-server` proxy) and `key-guard.py`
(tool-call hook layer) are complementary:

- **OS sandbox (`agent-jail` / Codex `key-guard`) stops**: runtime-constructed
  paths, scripts, symlinks, child processes, and local MCP servers from reading
  masked local keys/credentials (`~/.ssh/*` private keys,
  `~/.config/chezmoi/key.txt`, `~/.secrets`, AWS, Cargo, Hugging Face, other
  agents' auth) or writing outside the workspace and allowed caches (plus
  `.git/hooks` and `.git/config` under `bwrap`).
- **`key-guard.py` stops** what the OS sandbox intentionally leaves reachable:
  1. `unjail` / `DOTFILES_NO_JAIL=1` sessions (e.g. running `chezmoi apply`).
  2. Direct reads of `~/.config/gh/hosts.yml` (kept readable by default for
     `gh pr`/`gh run`) and `gh auth token` / `gh secret` / `gh repo delete`.
  3. Vault extraction commands (`rbw get`/`dump`, `secret-tool lookup`/`search`),
     whose agent/D-Bus sockets live in `$XDG_RUNTIME_DIR`.
  4. Remote SSH commands (`ssh sicc 'cat ~/.ssh/id_ed25519'`) run over the
     forwarded `SSH_AUTH_SOCK`.
  5. Direct tool reads of the invoked agent's own auth file (`~/.codex/auth.json`,
     `~/.claude/.credentials.json`, `~/.pi/agent/auth.json`).
  6. Non-shell entrypoints (IDE plugins, `agy acp`, `remote-control`).
- **What neither layer stops**:
  - Commands you run explicitly outside the jail (`unjail`) if an agent computes
    a secret path dynamically at runtime, or an MCP server process running in an
    unjailed session.
  - A command you type yourself with `!` in Claude Code (no hook sees it).
  - A remote host's filesystem if a command runs a script remotely over `ssh`
    that constructs a key path dynamically.

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
  with only a warning. CI does not check this order separately (checked on 2026-10-18).
- **The key fetcher,
  `.chezmoiscripts/run_onchange_before_00-age-identity.sh.tmpl`, must never
  exit non-zero.** It runs before any file is written, so a failure there would
  stop every file from applying. It must also stay `run_onchange_` with its
  rbw-present marker line. As `run_once_` it never retries after the first
  apply fails for lack of rbw, and as a plain `run_` it makes `chezmoi verify`
  fail for good.
- **Local guards work only where the hooks are installed.** Gitleaks checks
  staged files and outgoing commits. The existing `check-encrypted`,
  `detect-private-key`, `no-age-identity`, and `no-home-paths` commit hooks
  remain active. GitHub push protection rejects supported secret patterns even
  without local hooks. CI runs after publication and cannot prevent a leak.
  `.gitignore` names the usual key files too, but it stops only `git add .`.
  `git add -f` gets past it.
- **`chezmoi add` writes into whichever source tree its config names.** With
  an unexpected `HOME` or `XDG_CONFIG_HOME`, a new encrypted file can land in
  another repository. Run `git status` after every `add --encrypt`.
- **Codex exact `deny` paths must exist on disk.** For an exact `deny` path
  that does not exist under `~`, Codex creates an empty 0444 placeholder file
  there while each sandboxed command runs, and a command that dies leaves the
  file behind (under `~/.ssh`, `ssh` then warns about an unprotected private
  key). For that reason, `agent-reconcile.py` keeps the four `~/.ssh/id_*`
  globs and emits exact `deny` paths from `.chezmoidata/policy.toml`
  (`masked_dirs`, `masked_files` excluding `.codex/auth.json`, and custom-named
  `~/.ssh/` private keys) only for entries that currently exist under `$HOME`.
  Re-run `chezmoi apply` after adding or removing a secret file so Codex neither
  misses new files nor creates placeholders for removed ones. Exact paths in
  `/etc`, such as `/etc/ssh/ssh_config.d`, are safe because Codex runs
  unprivileged and cannot create anything there. Checked on 2026-11-23. To
  delete leftover empty placeholders under `~/.ssh`, which touches empty files
  only:

  ```sh
  find ~/.ssh -maxdepth 1 -name 'id_*' -type f -empty -delete
  ```
- **Never bind `/tmp/codex-daemon-*` into `agent-jail`.** Inside `agent-jail`,
  `codex` runs with `-s danger-full-access` because `bwrap` cannot nest;
  connecting that session to an unjailed host `app-server` daemon would execute
  commands outside both sandboxes. `agent-jail` injects `--no-daemon` instead
  (unless `--no-daemon` or `--remote` is already passed).
