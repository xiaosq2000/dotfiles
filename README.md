# dotfiles

**Warning: Backup first! All your dotfiles will be REPLACED.**

Quick and wild: make `$HOME` a git repository.

```sh
cd ~ && \
git init --initial-branch=main && \
git remote add origin https://github.com/xiaosq2000/dotfiles && \
git fetch --all && \
git reset --hard origin/main
git submodule update --init
```
