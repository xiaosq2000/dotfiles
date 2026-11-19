#!/usr/bin/env bash
# One-time migration: remove the legacy global `diff.external = difft` that the
# retired 09-git-difftastic.sh script wrote into ~/.gitconfig.
#
# Native unified diff is now the default so coding agents and `.age` textconv
# work cleanly; opt into Difftastic with `git dft` / `git dfts` / `lazygit`.
# Any other custom diff.external value in ~/.gitconfig is left untouched.

set -u

if ! command -v git >/dev/null 2>&1; then
    exit 0
fi

if git config --file "$HOME/.gitconfig" --get-all diff.external '^difft$' >/dev/null 2>&1; then
    git config --file "$HOME/.gitconfig" --unset-all diff.external '^difft$' ||
        printf 'git-difftastic-cleanup: warning: could not unset legacy diff.external=difft\n' >&2
fi

exit 0
