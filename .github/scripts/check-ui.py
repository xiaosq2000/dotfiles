"""Check the shared UI library with and without a terminal in bash and zsh."""

import errno
import os
from pathlib import Path
import pty
import subprocess
import sys
import tempfile


library = Path(sys.argv[1] if len(sys.argv) > 1 else "dot_sh_utils/lib/ui.sh").resolve()
styles = b"|".join(b"\x1b[" + code + b"m" for code in
                   (b"1", b"2", b"30", b"4", b"31", b"32", b"33", b"34", b"35", b"0"))
plain = b"|" * 9
payload = r'''
set -eu
tput() { printf 'called\n' >> "$UI_TPUT_LOG"; return 1; }
source "$1"
if [ "$2" = resource ]; then
    TERM=dumb
    source "$1"
fi
printf '%s|' "$INTERACTIVE" "$BOLD" "$DIM" "$GREY" "$UNDERLINE" "$RED" \
    "$GREEN" "$YELLOW" "$BLUE" "$MAGENTA"
printf '%s' "$RESET"
'''


def run(command, env, terminal):
    if not terminal:
        result = subprocess.run(command, env=env, stdin=subprocess.DEVNULL,
                                capture_output=True, timeout=10, check=True)
        assert not result.stderr, result.stderr
        return result.stdout
    master, slave = pty.openpty()
    try:
        result = subprocess.run(command, env=env, stdin=slave, stdout=slave,
                                stderr=slave, timeout=10, check=True)
    finally:
        os.close(slave)
    output = bytearray()
    try:
        while True:
            try:
                chunk = os.read(master, 4096)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                break
            if not chunk:
                break
            output.extend(chunk)
    finally:
        os.close(master)
    return bytes(output)


with tempfile.TemporaryDirectory(prefix="check-ui-") as directory:
    calls = Path(directory) / "tput-calls"
    env = os.environ.copy()
    for name in ("TERM", "DOCKER_CONTAINER", "NO_COLOR", "BASH_ENV", "ENV"):
        env.pop(name, None)
    env.update(UI_TPUT_LOG=str(calls))
    cases = [
        (term, True, {"TERM": term}, "once", True, True)
        for term in ("ansi", "linux", "xterm", "xterm-256color", "xterm-kitty",
                     "rxvt-unicode-256color", "screen-256color", "tmux-256color",
                     "alacritty", "foot", "wezterm", "kitty")
    ] + [
        ("unset TERM", True, {}, "once", False, True),
        ("empty TERM", True, {"TERM": ""}, "once", False, True),
        ("dumb TERM", True, {"TERM": "dumb"}, "once", False, True),
        ("unknown TERM", True, {"TERM": "unknown"}, "once", False, True),
        ("non-ANSI TERM", True, {"TERM": "vt52"}, "once", False, True),
        ("pipe", False, {"TERM": "xterm-256color"}, "once", False, False),
        ("container", True, {"TERM": "xterm-256color", "DOCKER_CONTAINER": "1"},
         "once", False, False),
        ("NO_COLOR", True, {"TERM": "xterm-256color", "NO_COLOR": "1"},
         "once", False, True),
        ("empty NO_COLOR", True, {"TERM": "xterm-256color", "NO_COLOR": ""},
         "once", True, True),
        ("source again", True, {"TERM": "xterm-256color"}, "resource", False, True),
    ]
    for shell, flags in (("bash", ["--noprofile", "--norc"]), ("zsh", ["-df"])):
        for name, terminal, extra, mode, colored, interactive in cases:
            command = [shell, *flags, "-c", payload, "check-ui", str(library), mode]
            actual = run(command, env | extra, terminal)
            expected = (b"true|" if interactive else b"false|") + (styles if colored else plain)
            assert actual == expected, (shell, name, actual, expected)
            assert not calls.exists(), (shell, name, "tput was called")
        print(f"{shell}: {len(cases)} UI checks passed")
