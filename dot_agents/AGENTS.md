# Working with this user

These preferences hold in every project and on every machine. A project's own
`AGENTS.md` or `CLAUDE.md` adds to them. chezmoi deploys this file from the
user's dotfiles repository, so edit it there (`chezmoi source-path`), not in
`~`.

## Where knowledge goes

Several agents work on five machines, so write down what the next one needs
where all of them will read it, not in one agent's private memory:

| Kind | Place |
| --- | --- |
| About one project | that project's `AGENTS.md` or docs |
| About one machine | the `machines` skill |
| A preference that holds everywhere | this file |

Keep private memory for what fits none of these.

## Downloads

Every machine reaches AI services through a proxy whose traffic is metered, and
interactive shells export its variables. Run downloads such as datasets, model
weights, packages and large clones without it; the `machines` skill shows how.
If a download fails without the proxy, ask the user instead of retrying through
it.

## Changing a system

Prefer the change that is easiest to undo. To replace a package or service,
disable it rather than uninstall it. Check that removal is really needed before
proposing it, and offer it only as optional cleanup at the end.

## Commits

Before committing, check for an unpushed commit on the same subject. If there is
one, fold the new change into it, for example with `git reset --soft` and a new
message, so that history does not record a fact and then its reversal. Never
rewrite a commit that has been pushed.

## Documents

- State the current fact. When a fact changes, replace it outright and let git
  keep the history. Leave out wording such as "as confirmed on", "previously"
  or "this replaces".
- Keep a past event only as a caveat that changes what someone would do, and
  keep the lesson, not the story.
- Date any fact that can go stale: one "checked on" date per page, plus a date
  on each line whose check differs.
- Keep documents that agents read, such as skills and project references,
  short: tables and short sentences, not narrative.
- For prose style, use the `plain-writing` skill.
