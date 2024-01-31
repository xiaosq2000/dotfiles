# dotfiles

## Usage

By making `$HOME' a git repository. 

Warning: This would replace your dotfiles!

```sh
cd ~ && \
git init --initial-branch=main && \
git remote add origin https://github.com/xiaosq2000/dotfiles && \
git fetch --all && \
git reset --hard origin/main
```
