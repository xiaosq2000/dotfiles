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

`sbc` proxy traffic is metered. Before large downloads (datasets, weights,
packages, large clones), unset proxy variables or confirm `sbc route` sends
them direct (`ai-only` or `gfw-proxy`, not `china-direct` or `global`; see the
`machines` skill). If a direct download fails, ask the user; never retry
through the metered proxy.

## Environments and CLIs

Invoke environment managers (`pixi`, `uv`, `pnpm`, etc.) as bare commands from
`PATH` (`pixi run ...`, `uv run ...`), never via hardcoded install paths
(`~/.pixi/bin/pixi`) or managed environment binaries (`.pixi/envs/...`,
`.venv/bin/...`) unless a wrapper documents an exception.

Expose repeatable project workflows as clean CLI or task entry points (`pixi`
tasks, `pyproject.toml` or `package.json` scripts) rather than long ad-hoc
invocations or internal script paths.

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
- Use standard technical terms and explicit parameter names; never coin
  internal shorthand or lab slang in chat, docs, or comments.
- Keep a past event only as a caveat that changes what someone would do, and
  keep the lesson, not the story.
- Date any fact that can go stale: one "checked on" date per page, plus a date
  on each line whose check differs.
- Keep documents that agents read, such as skills and project references,
  short: tables and short sentences, not narrative.

## Research and academic writing

- Scientific integrity and fairness come first. Never rely on weakened or buggy
  baselines to inflate benchmark margins; actively strengthen and tune baselines
  under equalized budgets so genuine innovation and failure regimes stand out.
- Aim first AI manuscript drafts at roughly 70% comprehension for a junior PhD
  student in the area, using minimal faithful formalization without decorative
  jargon. During human-in-the-loop refinement, adopt higher-level mathematical
  abstraction whenever it communicates the core idea more concisely and
  powerfully, accepting the trade-off in introductory readability.
- Report negative results, parity regimes, stronger baselines, and failure
  boundaries honestly. Never post-filter metrics with oracle labels, mix
  variance definitions, or add result-gating assertions to benchmark scripts.
- Stamp result artifacts with `git_sha`, `git_dirty`, and hyperparameters, and
  keep generating scripts in git while their numbers remain cited.
- Load the `academic-research` skill when designing experiments, auditing
  baselines, or drafting and shipping manuscripts.
