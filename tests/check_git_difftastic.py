#!/usr/bin/env python3
"""Check managed ~/.config/git/config defaults, native diff, git dft, and local overrides."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
git = shutil.which("git")
assert git, "git is required"
git_config_src = ROOT / "private_dot_config/git/config"

with tempfile.TemporaryDirectory(prefix="git-config-check-") as directory:
    home = Path(directory)
    xdg_git = home / ".config/git"
    xdg_git.mkdir(parents=True)
    shutil.copyfile(git_config_src, xdg_git / "config")
    shutil.copyfile(ROOT / "private_dot_config/git/ignore", xdg_git / "ignore")

    binaries = home / "bin"
    binaries.mkdir()
    (binaries / "git").symlink_to(git)
    difft = binaries / "difft"
    difft.write_text('#!/bin/sh\nprintf "difft-fixture\\n"\n')
    difft.chmod(0o755)

    env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    env.update(
        HOME=str(home),
        XDG_CONFIG_HOME=str(home / ".config"),
        PATH=f"{binaries}{os.pathsep}{os.environ['PATH']}",
        GIT_CONFIG_NOSYSTEM="1",
    )

    def git_cmd(*args, cwd=home, check=True):
        return subprocess.run(
            [git, *args], cwd=cwd, env=env, text=True, capture_output=True, check=check
        )

    assert git_cmd("config", "--get", "diff.algorithm").stdout.strip() == "histogram"
    assert git_cmd("config", "--get", "merge.conflictStyle").stdout.strip() == "zdiff3"
    assert git_cmd("config", "--get", "pull.rebase").stdout.strip() == "true"
    assert git_cmd("config", "--get", "fetch.prune").stdout.strip() == "true"
    assert git_cmd("config", "--get", "push.autoSetupRemote").stdout.strip() == "true"
    assert git_cmd("config", "--get", "diff.external", check=False).returncode != 0

    # Native `git diff` stays unified; `git dft` invokes difft.
    old, new = home / "old.txt", home / "new.txt"
    old.write_text("old\n")
    new.write_text("new\n")
    native = git_cmd("--no-pager", "diff", "--no-index", str(old), str(new), check=False)
    assert native.returncode == 1 and "@@" in native.stdout, native
    ext = git_cmd("--no-pager", "dft", "--no-index", str(old), str(new), check=False)
    assert ext.stdout == "difft-fixture\n", ext

    # ~/.gitconfig overrides ~/.config/git/config (Git XDG precedence).
    gitconfig = home / ".gitconfig"
    git_cmd("config", "--file", str(gitconfig), "pull.rebase", "false")
    assert git_cmd("config", "--get", "pull.rebase").stdout.strip() == "false"

print("ok       Git config: XDG defaults, native diff, git dft alias, and local override")
