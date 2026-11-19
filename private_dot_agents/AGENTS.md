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

Keep private memory for what fits none of these. Keep every project repository
self-contained across machines: store all project files (including review
transcripts, check scripts, design notes, and handoffs) inside the repository
rather than user-level agent artifact or scratch directories, and use
repo-relative paths—never machine-local paths outside the repository.

## Downloads

Every machine reaches AI services through `sbc`, whose proxy traffic is metered.
Under `sbc route ai-only` or `gfw-proxy`, non-AI download hosts go direct
automatically; under `china-direct` or `global`, interactive shells still route
foreign downloads through the metered proxy. For large downloads (datasets,
model weights, packages, large clones), unset the proxy variables or confirm
`sbc route` routes them direct first; the `machines` skill shows how. If a
direct download fails, ask the user instead of retrying through the metered
proxy.

## Environments and CLIs

Invoke modern environment managers (`pixi`, `uv`, `pnpm`, and similar tools) as
bare commands from `PATH` (for example `pixi run ...`, `uv run ...`,
`pixi install`, `uv sync`), just as humans do. Never hardcode install paths
(such as `~/.pixi/bin/pixi` or `~/.local/bin/uv`) or invoke binaries directly
inside managed environment directories (`.pixi/envs/...`, `.venv/bin/...`)
unless a wrapper explicitly documents an exception.

Design clean CLIs and task entry points for repeatable project workflows—such
as `pixi` tasks, `pyproject.toml` scripts, or `package.json` scripts—so humans
and agents run the same short commands instead of long ad-hoc invocations or
internal script paths.

## Changing a system

Prefer the change that is easiest to undo. To replace a package or service,
disable it rather than uninstall it. Check that removal is really needed before
proposing it, and offer it only as optional cleanup at the end.

Keep machines, repositories and memory tidy, and offer to clean up leftovers.
Delete datasets, run directories, checkpoints and worktrees only when the user
says so; until then, move superseded outputs aside, for example to
`runs/aside-<date>/`. Keep a run's worktree and environment while an evaluation
of it may still run.

## Continuing work

Before building more on a long branch or research line, propose what you would
build from scratch and a concrete cut list, then stop for the user's decision.
A clean break from earlier exploration is fine when its useful results carry
over.

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
