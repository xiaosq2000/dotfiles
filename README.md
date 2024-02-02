# dotfiles

## Usage

**Warning: Backup first! The Following code snippets can replace your dotfiles! **
**Warning: Backup first! The Following code snippets can replace your dotfiles! **
**Warning: Backup first! The Following code snippets can replace your dotfiles! **

Quick and wild, by making `$HOME` a git repository.
```sh
cd ~ && \
git init --initial-branch=main && \
git remote add origin https://github.com/xiaosq2000/dotfiles && \
git fetch --all && \
git reset --hard origin/main
```

Another branch.
```sh
cd ~ && \
git init --initial-branch=main && \
git checkout -b docker && \
git remote add origin https://github.com/xiaosq2000/dotfiles && \
git fetch --all && \
git reset --hard origin/docker
```
