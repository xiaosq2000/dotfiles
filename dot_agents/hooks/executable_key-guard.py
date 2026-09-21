#!/usr/bin/env python3
"""Refuse an agent tool call that names an ssh private key or the age identity.

Claude Code and Codex run this as a PreToolUse hook, and the opencode plugin in
~/.config/opencode/plugins/key-guard.js runs it for opencode, so the three
agents share one rule. The call arrives on stdin as JSON with tool_name and
tool_input. Exit 2 with the reason on stderr refuses the call, and exit 0 lets
it through.

It matches text, not files. It stops a call that names a key, which covers the
Read tool, cat, cp, grep, find -name and the like, but not a command that
builds the path at run time. docs/secrets.md lists the other layers each agent
gets and what none of them covers.
"""

import json
import re
import sys

# Names directly under ~/.ssh that hold nothing secret. Every other name there
# counts as a private key, so a key with a custom name is covered without being
# listed, and so are ~/.ssh itself and globs such as ~/.ssh/*.
PUBLIC = re.compile(r"config|config\.d|known_hosts(\.old)?|authorized_keys2?|[^*?\[{]+\.pub")

# .ssh as a path component, and the component after it, if any. The lookarounds
# keep .sshrc, foo.ssh and chezmoi's private_dot_ssh from matching.
SSH_PATH = re.compile(r"(?<![\w.-])\.ssh(?![\w.-])(?:/([^/\s\"'`;|&<>()]*))?")

# A default key name without the directory, as in `find ~ -name 'id_*'`, or
# `cat id_ed25519` from inside ~/.ssh.
KEY_NAME = re.compile(r"(?<![\w.-])id_(?:(?:rsa|dsa|ecdsa|ed25519|xmss)(?:_sk)?|\*)[\w*?.-]*")

# The chezmoi age identity, which decrypts every encrypted_ file in the public
# dotfiles repository. chezmoi reads it itself, so `chezmoi cat` still works.
# Anything may sit between the two within one path, so chezmoi/./key.txt and
# chezmoi/x/../key.txt count too.
AGE_IDENTITY = re.compile(r"chezmoi/(?:[^\s\"'`;|&<>()]*/)?key\.txt")


def strings(value, tool, key=None):
    """Yield every string in a tool input that could name a file."""
    if isinstance(value, str):
        # A description is prose, and Grep's pattern is a regex to search for,
        # not a path to read. Neither opens a file.
        if key == "description" or (key == "pattern" and tool == "grep"):
            return
        yield value
    elif isinstance(value, dict):
        for k, v in value.items():
            yield from strings(v, tool, k)
    elif isinstance(value, list):
        for v in value:
            yield from strings(v, tool, key)


def offence(text):
    """Return what the text names that an agent must not read, or None."""
    for m in SSH_PATH.finditer(text):
        name = m.group(1)
        if name is None or not PUBLIC.fullmatch(name):
            return "an ssh private key or the ~/.ssh directory (" + m.group(0) + ")"
    for m in KEY_NAME.finditer(text):
        if not m.group(0).endswith(".pub"):
            return "an ssh private key (" + m.group(0) + ")"
    if AGE_IDENTITY.search(text):
        return "the chezmoi age identity (~/.config/chezmoi/key.txt)"
    return None


def main():
    try:
        call = json.load(sys.stdin)
        tool = str(call.get("tool_name", "")).lower()
        tool_input = call.get("tool_input", {})
    except (ValueError, AttributeError) as e:
        # Every agent sends valid JSON, so this means a broken caller, not an
        # attack. Refusing would block every tool call until someone fixed it.
        print("key-guard: could not read the tool call, letting it through: %s" % e, file=sys.stderr)
        return 0
    for text in strings(tool_input, tool):
        found = offence(text)
        if found:
            print(
                "key-guard refused this call because it names %s. "
                "Agents must not read private keys or the age identity. "
                "Do not work around this: tell the user what you need, "
                "and let them run the command themselves." % found,
                file=sys.stderr,
            )
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
