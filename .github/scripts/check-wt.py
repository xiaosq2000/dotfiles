#!/usr/bin/env python3
"""Check wt labels and directory changes in a disposable Git repository."""

import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
zshrc = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "dot_zshrc.tmpl"
function = re.search(r"^wt\(\) \{\n.*?^\}", zshrc.read_text(), re.MULTILINE | re.DOTALL)
assert function, f"wt is missing from {zshrc}"

with tempfile.TemporaryDirectory(prefix="check-wt-") as temporary:
    base = Path(temporary)
    home = base / "home"
    home.mkdir()
    stubs = base / "bin"
    stubs.mkdir()
    log = base / "rows"
    environment = {
        **os.environ,
        "HOME": str(home),
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": os.devnull,
        "LC_ALL": "C.UTF-8",
        "PATH": str(stubs) + os.pathsep + os.environ["PATH"],
        "WT_TEST_LOG": str(log),
    }
    fzf = stubs / "fzf"
    fzf.write_text(f"#!{sys.executable}\n" + '''import os
from pathlib import Path
import sys

assert sys.argv[1:] == [
    "--delimiter=\\t", "--with-nth=2..", "--layout=reverse", "--height=~60%",
    "--border=rounded", "--border-label= worktrees: repo [main] ", "--info=inline",
    "--prompt=switch to> ", "--header=enter: cd    esc: cancel", "--header-first",
]
rows = sys.stdin.read()
Path(os.environ["WT_TEST_LOG"]).write_text(rows)
status = int(os.environ.get("WT_TEST_STATUS", "0"))
if status:
    sys.exit(status)
for row in rows.splitlines():
    if row.split("\\t", 1)[1].startswith(os.environ["WT_TEST_LABEL"] + "  "):
        print(row)
        break
else:
    sys.exit(1)
''')
    fzf.chmod(0o755)

    def git(*arguments):
        return subprocess.check_output(
            ["git", *map(str, arguments)], env=environment, text=True, stderr=subprocess.PIPE
        ).strip()

    main = base / "repo [main]"
    git("-c", "init.defaultBranch=main", "init", "-q", main)
    git("-C", main, "-c", "user.name=wt test", "-c", "user.email=wt@example.invalid",
        "-c", "commit.gpgsign=false", "commit", "-q", "--allow-empty", "-m", "fixture")
    nested = main / ".worktrees/feature one"
    outside = base / "repo [main]-outside"
    detached = main / "worktrees/detached"
    wide = main / "worktrees/中文"
    git("-C", main, "worktree", "add", "-q", "-b", "feature", nested)
    git("-C", main, "worktree", "add", "-q", "-b", "outside", outside)
    git("-C", main, "worktree", "add", "-q", "--detach", detached)
    git("-C", main, "worktree", "add", "-q", "-b", "wide", wide)
    git("-C", main, "worktree", "lock", "--reason", "fixture", nested)
    subdirectory = main / "subdirectory"
    subdirectory.mkdir()
    linked_subdirectory = nested / "subdirectory"
    linked_subdirectory.mkdir()
    destinations = {
        ".": main,
        ".worktrees/feature one": nested,
        str(outside): outside,
        "worktrees/detached": detached,
        "worktrees/中文": wide,
    }
    head = git("-C", main, "rev-parse", "--short=7", "HEAD")
    branches = {
        ".": "[main]",
        ".worktrees/feature one": "[feature] locked",
        str(outside): "[outside]",
        "worktrees/detached": "(detached HEAD)",
        "worktrees/中文": "[wide]",
    }

    def display_width(text):
        return sum(0 if unicodedata.combining(character) else
                   2 if unicodedata.east_asian_width(character) in ("W", "F") else 1
                   for character in text)

    width = max(map(display_width, destinations))
    expected = {
        f"{label}{' ' * (width - display_width(label))}  {head}  {branch}"
        for label, branch in branches.items()
    }
    script = function.group() + '''
setopt auto_pushd pushd_ignore_dups pushd_silent
wt
result=$?
if (( result == 0 )) && [[ "$PWD" != "$WT_TEST_ORIGIN" ]]; then
    [[ "${dirstack[1]}" == "$WT_TEST_ORIGIN" ]] || exit 1
fi
printf '%s\\n%s\\n' "$result" "$PWD"
'''

    def select(cwd, label, status=0):
        return subprocess.run(
            ["zsh", "-dfc", script], cwd=cwd,
            env={**environment, "WT_TEST_LABEL": label, "WT_TEST_STATUS": str(status),
                 "WT_TEST_ORIGIN": str(cwd)},
            text=True, capture_output=True, check=True,
        )

    for cwd in (main, subdirectory, linked_subdirectory, outside):
        for label, destination in destinations.items():
            result = select(cwd, label)
            assert result.stdout.splitlines() == ["0", str(destination)], (cwd, label, result)
            assert not result.stderr, result.stderr
            labels = {row.split("\t", 1)[1] for row in log.read_text().splitlines()}
            assert labels == expected, labels

    for status in (1, 130):
        result = select(linked_subdirectory, ".", status)
        assert result.stdout.splitlines() == [str(status), str(linked_subdirectory)], result

    log.unlink()
    result = select(base, ".")
    assert result.stdout.splitlines() == ["128", str(base)], result
    assert "not a git repository" in result.stderr, result.stderr
    assert not log.exists(), "wt opened fzf after Git failed"

print("wt aligned columns, wide characters, picker layout, selection, worktree metadata and cancellation checks passed.")
