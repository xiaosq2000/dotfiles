---
name: git-shipping
description: Draft commit messages, commit, push, create or remove worktrees, and open or merge pull requests in any Git repository.
---

# Git shipping

A repository's `AGENTS.md` overrides these defaults, such as its base branch,
scopes, checks or worktree location.

Do only the steps the user asked for. Creating a branch does not mean pushing
it, and opening a PR does not mean merging it. A request for a message ends with
the message.

## Commits

- Check `git status`, then stage by path only the files of one logical change.
- Write `<type>(<scope>): <summary>` in Conventional Commits. Reuse a scope from
  `git log --oneline`, or leave it out for a change across the repository.
- Keep the summary imperative, 72 characters or fewer, with no period. Add a
  body only for a reason the diff does not show.
- Let hooks run, and skip them only when the user asks. If a hook fails, fix
  the cause and commit again rather than amending an older commit.

## Worktrees

| Step | Command |
| --- | --- |
| Create | `git worktree add .worktrees/<topic> -b <type>/<topic>` |
| Remove | `git worktree remove .worktrees/<topic>`, then `git branch -d <type>/<topic>` |

- Check that `.gitignore` lists `.worktrees/` before creating one.
- Before removing one, check for uncommitted and untracked files. Force the
  removal only when git refuses because a submodule was initialized and
  `git status` in the worktree is clean.
- After a squash merge, `git branch -d` refuses. Check that the PR merged and
  the branch has no later commits, then use `git branch -D`.

## Push and PR

- Push a new branch with `git push -u origin <branch>`.
- Open the PR with `gh pr create` against the base branch, which is the
  default branch unless `AGENTS.md` names another.
- Merge by squash. Never force-push a shared branch.

Report the branch, the checks and their results, and the commit, PR URL or
merge state.
