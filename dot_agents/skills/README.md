# Shared agent skills

This directory holds the only real copy of every user level skill. Claude Code,
Codex and OpenCode all read the same files, so a skill is written once and
edited in one place.

Each skill is a directory with a `SKILL.md` inside it, plus any supporting files
the skill needs.

## How each agent finds these files

| Agent | Path it reads | How it is wired |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/<name>` | symlink into this directory |
| Codex | `~/.codex/skills/<name>` | symlink into this directory |
| OpenCode | `~/.agents/skills/<name>` | read directly, no symlink needed |

OpenCode looks in `~/.agents/skills` and `~/.claude/skills` on its own, which is
why it needs nothing. Codex only looks in `$CODEX_HOME/skills`, and Claude Code
only looks in `$CLAUDE_CONFIG_DIR/skills`, so both get a symlink.

Codex keeps its own bundled skills in `~/.codex/skills/.system`. The setup
script never touches that directory.

## Adding a skill

Create the directory and its `SKILL.md` here, then run the setup script:

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

Only the `name` and `description` keys in the frontmatter are understood by all
three agents. Anything else is agent specific, so keep it out of a shared skill
unless the other agents can safely ignore it.
