# Shared agent skills

This directory holds the personal skills managed by these dotfiles. Claude Code,
Codex, OpenCode and Antigravity CLI all read the same files, so a skill is
written once and edited in one place.

Each skill is a directory with a `SKILL.md` inside it, plus any supporting files
the skill needs.

## How each agent finds these files

| Agent | Path it reads | How it is wired |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/<name>` | symlink into this directory |
| Codex | `~/.codex/skills/<name>` | symlink into this directory |
| OpenCode | `~/.agents/skills/<name>` | read directly, no symlink needed |
| Antigravity CLI (`agy`) | `~/.gemini/config/skills/<name>` | symlink into this directory |

OpenCode looks in `~/.agents/skills` and `~/.claude/skills` on its own, which is
why it needs nothing. Codex looks in `$CODEX_HOME/skills`, Claude Code looks in
`$CLAUDE_CONFIG_DIR/skills`, and Antigravity CLI looks in
`${GEMINI_CONFIG_DIR:-$HOME/.gemini/config}/skills`, so all three get symlinks.

Codex keeps its own bundled skills in `~/.codex/skills/.system`. The setup
script never touches that directory.

Antigravity CLI discovers skills under `~/.gemini/config/skills/` and provides
them as slash commands, such as `/asd-ste100`. Checked on 2026-10-05.

## Adding a skill

Create the directory and its `SKILL.md` here, then run `chezmoi apply` to deploy
it and update the links. To repair those links separately, run the setup script:

```sh
~/.local/libexec/dotfiles/agent-skills.sh
```

The script is safe to run at any time. It creates missing links, repairs links
that point somewhere else, and leaves correct links alone. Use `--dry-run` to
see what it would do, and `--prune` to remove links whose skill has been
deleted.

If a real file or directory is sitting where a link belongs, the script reports
it and stops rather than deleting it. Move or delete that path by hand, then run
the script again.

## ASD-STE100

`asd-ste100` simplifies English technical prose and agent instructions. It includes
examples, rule references, and a Python linter. It does not certify compliance
with the official ASD-STE100 dictionary.

The files are vendored from [danyuchn/asd-ste100-skill](https://github.com/danyuchn/asd-ste100-skill)
at commit `32511c6992ecb5f1971e46a2943f2e6adceedafe` (version 0.4.0), checked on
2026-10-04. Keep the MIT license and supporting files when updating the skill.
Use `/asd-ste100` or ask the agent to apply STE100.

To test the linter:

```sh
python3 dot_agents/skills/asd-ste100/scripts/ste-lint.py --selftest
```

## A skill with encrypted files

`machines` holds facts about the user's machines, including addresses and
account names, and this repository is public. Its source directory is
`private_machines`, so it lands with mode 0700, and its pages under
`references/` are `encrypted_` files that chezmoi decrypts on apply. Its
`SKILL.md` stays plaintext, because an agent reads only its name and description
until the skill is needed, and neither holds a secret.

On a machine without the age key, `.chezmoiignore` leaves out the whole skill,
so no agent there is pointed at pages that are missing. To edit a page, change
the decrypted file under `~/.agents/skills/machines` and run `chezmoi re-add` on
it; the skill's own `SKILL.md` says the same.

## Keeping skills portable

Use `name` and `description` as the shared frontmatter fields. Anything else
needs a compatibility check, so keep it out of a shared skill unless the other
agents can safely ignore it.
