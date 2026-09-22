#!/usr/bin/env python3
"""Refuse an agent tool call that could read an ssh private key or the age identity.

Claude Code and Codex run this as a PreToolUse hook, and the opencode plugin in
~/.config/opencode/plugins/key-guard.js runs it for opencode, so the three
agents share one rule. The call arrives on stdin as JSON with tool_name and
tool_input. Exit 2 with the reason on stderr refuses the call, and exit 0 lets
it through.

It matches text, not files. A call that names a key is refused, which covers
the Read tool, cat, cp, grep, find -name and the like. The one exception is a
shell command that names an ssh key only to use it, or to look at its name and
mode: ssh -i, ssh-add, ssh-keygen -y, ls, stat, chmod and a few more. To find
those, the command is split into words the way a shell splits it, and a command
sent over ssh is checked the same way. A command whose effect the split cannot
follow, such as one with $(...), is refused if it names a key at all.

Text matching cannot stop a command that builds the path at run time.
docs/secrets.md lists the other layers each agent gets and what none of them
covers.
"""

import json
import os
import re
import shlex
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
# chezmoi/x/../key.txt count too. No shell command may name it, not even ls.
AGE_IDENTITY = re.compile(r"chezmoi/(?:[^\s\"'`;|&<>()]*/)?key\.txt")

# Tools whose command is a shell script, split into words rather than matched
# whole: Bash in Claude Code and Codex, bash in opencode, and Claude Code's
# Monitor. Codex may send the command as an argv list.
SHELL_TOOLS = {"bash", "monitor"}
SHELL_FIELDS = {"command", "cmd"}

# Commands that act on a file's name or mode and never print what is in it.
# file, du and sort are left out: `file -f`, `du --files0-from` and
# `sort --files0-from` read a list of names from a file, so their errors would
# echo a key's lines.
METADATA = {"ls", "stat", "test", "[", "[[", "chmod", "mkdir", "realpath", "readlink"}

# What may read the output of a METADATA command that named a key. None of
# these opens a file named in its input, so `ls ~/.ssh | grep pub` passes and
# `ls -d ~/.ssh/* | xargs cat` does not.
FILTERS = {"grep", "egrep", "fgrep", "head", "tail", "wc", "cut", "tr", "uniq", "column", "nl", "cat"}

# For each ssh client, the options that take a value, and among them those
# whose value is a file the client opens for its own use: an identity, or
# ssh's -S control socket. -F is not one of them, because ssh echoes the
# lines of a config file it cannot parse.
CLIENTS = {
    "ssh": ("BbcDEeFIiJLlmOoPpQRSWw", "iS"),
    "scp": ("cDFiJlLoPSX", "i"),
    "sftp": ("BbcDFiJlLoPRSsX", "i"),
    "ssh-copy-id": ("Fiopt", "i"),
}
# ssh -o options whose value is a file ssh opens for its own use, and those
# whose value is a command line.
SSH_FILE_OPTIONS = {"identityfile", "certificatefile", "controlpath", "identityagent"}
SSH_COMMAND_OPTIONS = {"proxycommand", "localcommand", "knownhostscommand", "remotecommand"}
# Variables whose value is an ssh command line.
SSH_COMMAND_VARIABLES = {"GIT_SSH_COMMAND", "RSYNC_RSH"}

# Programs that run the rest of their words as a command, each with its
# options that take a value.
WRAPPERS = {
    "command": "",
    "builtin": "",
    "exec": "a",
    "nohup": "",
    "time": "fo",
    "nice": "n",
    "timeout": "ks",
    "sudo": "CDghpRrTtUu",
    "env": "CSu",
}
SHELLS = {"sh", "bash", "zsh", "dash", "ksh"}
# Words that only open or continue a compound command.
KEYWORDS = {"!", "{", "}", "if", "then", "else", "elif", "while", "until", "do"}
DECLARATIONS = {"export", "declare", "local", "readonly", "typeset"}

OPERATORS = "();<>|&\n"
ASSIGNMENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")

# Shell text whose effect the split cannot follow: command and process
# substitution, here-documents, eval, source, and $_, which repeats the last
# word of the command before it.
OPAQUE = re.compile(
    r"`|\$\(|[<>]\(|<<|\$_(?!\w)|\$\{_\}|(?<![\w.-])(?:eval|source)(?![\w.-])|(?:^|[\s;&|(])\.\s"
)


def fields(value, tool, key=None):
    """Yield (field, text) for every string in a tool input that could name a file."""
    if isinstance(value, str):
        # A description is prose, and Grep's pattern is a regex to search for,
        # not a path to read. Neither opens a file.
        if key == "description" or (key == "pattern" and tool == "grep"):
            return
        yield key, value
    elif isinstance(value, dict):
        for k, v in value.items():
            yield from fields(v, tool, k)
    elif isinstance(value, list):
        if tool in SHELL_TOOLS and key in SHELL_FIELDS and all(isinstance(v, str) for v in value):
            # Codex sends a command as an argv list, such as bash -lc SCRIPT.
            yield key, shlex.join(value)
            return
        for v in value:
            yield from fields(v, tool, key)


def ssh_key(text):
    """Return why the text names an ssh private key, or None."""
    for m in SSH_PATH.finditer(text):
        name = m.group(1)
        if name is None or not PUBLIC.fullmatch(name):
            return "it names an ssh private key or the ~/.ssh directory (" + m.group(0) + ")"
    for m in KEY_NAME.finditer(text):
        if not m.group(0).endswith(".pub"):
            return "it names an ssh private key (" + m.group(0) + ")"
    return None


def age_identity(text):
    """Return why the text names the age identity, or None."""
    if AGE_IDENTITY.search(text):
        return "it names the chezmoi age identity (~/.config/chezmoi/key.txt)"
    return None


def offence(text):
    """Return why the text names something an agent must not read, or None."""
    return ssh_key(text) or age_identity(text)


def first(check, items):
    """Return the first reason check gives for any item, or None."""
    for item in items:
        found = check(item)
        if found:
            return found
    return None


def tokens(script):
    """Yield the words and operators of a shell script.

    A word comes out as a str with its quoting removed. An operator such as
    ;, && or > comes out as a one-item tuple, so a quoted ';' stays a word.
    Raises ValueError on an unterminated quote.
    """
    word, in_word, i, n = [], False, 0, len(script)
    while i < n:
        c = script[i]
        if c == "\\":
            if script[i + 1 : i + 2] != "\n":  # a backslash-newline joins lines
                word.append(script[i + 1 : i + 2])
                in_word = True
            i += 2
        elif c == "'":
            end = script.find("'", i + 1)
            if end < 0:
                raise ValueError("unterminated '")
            word.append(script[i + 1 : end])
            in_word, i = True, end + 1
        elif c == '"':
            i += 1
            while i < n and script[i] != '"':
                if script[i] == "\\" and script[i + 1 : i + 2] in ('"', "\\", "$", "`", "\n"):
                    i += 1
                word.append(script[i : i + 1])
                i += 1
            if i >= n:
                raise ValueError('unterminated "')
            in_word, i = True, i + 1
        elif c in " \t\r" or c in OPERATORS:
            if in_word:
                yield "".join(word)
                word, in_word = [], False
            end = i + 1
            if c in OPERATORS:
                while end < n and script[end] in OPERATORS:
                    end += 1
                yield (script[i:end],)
            i = end
        else:
            word.append(c)
            in_word, i = True, i + 1
    if in_word:
        yield "".join(word)


def split(script):
    """Split a shell script into pipelines of simple commands.

    A simple command is a pair: its words, and the words its redirections
    name, such as the file in `< file`.
    """
    pipelines, stages, words, targets = [], [], [], []
    redirect = False
    for token in tokens(script):
        if isinstance(token, str):
            (targets if redirect else words).append(token)
            redirect = False
            continue
        op = token[0]
        redirect = "<" in op or ">" in op
        if redirect and set(op) <= set("<>&"):
            continue  # >, >>, <, 2>&1 and the like: the next word is a target
        if words or targets:
            stages.append((words, targets))
            words, targets = [], []
        if "|" in op and op != "||":
            continue  # a pipe: the next command reads this one's output
        if stages:
            pipelines.append(stages)
            stages = []
    if words or targets:
        stages.append((words, targets))
    if stages:
        pipelines.append(stages)
    return pipelines


def shell_offence(script, depth=0):
    """Return why a shell script could read a key, or None."""
    found = offence(script)
    if found is None or depth > 3 or OPAQUE.search(script):
        return found
    try:
        pipelines = split(script)
    except ValueError:
        return found
    for stages in pipelines:
        for i, (words, targets) in enumerate(stages):
            found = first(offence, targets)
            if found:
                return found
            found, lists = command_offence(words, depth)
            if found:
                return found
            readers = [name_of(w) for w, _ in stages[i + 1 :]]
            for reader in readers:
                if lists and reader not in FILTERS:
                    return "it pipes the names of ssh keys into %s, which could open them" % (reader or "a command")
    return None


def name_of(words):
    """Return the name of the program a simple command runs."""
    for word in words:
        if word not in KEYWORDS and not ASSIGNMENT.match(word):
            return os.path.basename(word)
    return ""


def command_offence(words, depth):
    """Return why one simple command could read a key, or None.

    The second value is whether the command prints the names of keys, so that
    what reads its output matters.
    """
    words = list(words)
    while words and (words[0] in KEYWORDS or ASSIGNMENT.match(words[0])):
        word = words.pop(0)
        found = None if word in KEYWORDS else assignment_offence(word, depth)
        if found:
            return found, False
    if not words:
        return None, False
    name, args = os.path.basename(words[0]), words[1:]
    if name in WRAPPERS:
        rest, found = unwrap(name, args)
        return (found, False) if found else command_offence(rest, depth)
    if name in METADATA:
        return first(age_identity, args), any(ssh_key(a) for a in args)
    if name in CLIENTS:
        return client_offence(name, args, depth), False
    if name == "ssh-add":
        return first(age_identity, args), False
    if name == "ssh-keygen":
        # -y, -l and -B print a public key or a fingerprint. -p, -c, -N and -i
        # rewrite or convert the key, so they stay refused.
        flags = set("".join(a[1:] for a in args if a.startswith("-") and not a.startswith("--")))
        if flags & set("ylB") and not flags & set("pcNi"):
            return first(age_identity, args), False
    if name in SHELLS:
        return shell_c_offence(args, depth), False
    if name == "rsync":
        return rsync_offence(args, depth), False
    if name == "git":
        return git_offence(args, depth), False
    if name in DECLARATIONS:
        return first(lambda a: assignment_offence(a, depth) if ASSIGNMENT.match(a) else offence(a), args), False
    return first(offence, words), False


def assignment_offence(word, depth):
    """Check NAME=value, whose value may itself be an ssh command line."""
    name, _, value = word.partition("=")
    if name in SSH_COMMAND_VARIABLES:
        return shell_offence(value, depth + 1)
    return offence(value)


def unwrap(name, args):
    """Return the command a wrapper such as timeout runs, and why its options offend."""
    takes_value = WRAPPERS[name]
    i = 0
    while i < len(args) and args[i].startswith("-") and len(args[i]) > 1:
        word = args[i]
        i += 1
        if word == "--":
            break
        if word.startswith("--"):
            continue
        for j, letter in enumerate(word[1:], 1):
            if letter in takes_value:
                value = word[j + 1 :]
                if not value and i < len(args):
                    value = args[i]
                    i += 1
                found = offence(value)
                if found:
                    return [], found
                break
    rest = args[i:]
    if name == "timeout":
        rest = rest[1:]  # the duration
    return rest, None


def client_offence(name, args, depth):
    """Check ssh, scp, sftp or ssh-copy-id: options, operands and a remote command."""
    takes_value, own_file = CLIENTS[name]
    operands, options, i = [], True, 0
    while i < len(args):
        word = args[i]
        i += 1
        if options and word == "--":
            options = False
        elif not (options and word.startswith("-") and len(word) > 1):
            operands.append(word)
            # ssh reads options once more after the destination, as in
            # `ssh host -p 22`. After that, every word is the remote command.
            if name != "ssh" or len(operands) > 1:
                options = False
        else:
            for j, letter in enumerate(word[1:], 1):
                if letter not in takes_value:
                    continue
                value = word[j + 1 :]
                if not value and i < len(args):
                    value = args[i]
                    i += 1
                if letter in own_file:
                    found = age_identity(value)
                elif letter == "o":
                    found = ssh_option_offence(value, depth)
                else:
                    found = offence(value)
                if found:
                    return found
                break
    if name == "ssh":
        # ssh joins the command's words with spaces and hands them to the
        # remote shell, so they are checked as one script.
        return first(offence, operands[:1]) or (
            shell_offence(" ".join(operands[1:]), depth + 1) if operands[1:] else None
        )
    return first(offence, operands)


def ssh_option_offence(value, depth):
    """Check the value of ssh -o, as in -o IdentityFile=~/.ssh/id_work."""
    m = re.match(r"\s*([A-Za-z]+)\s*(?:=\s*|\s+)(.*)", value, re.S)
    if m and m.group(1).lower() in SSH_FILE_OPTIONS:
        return age_identity(m.group(2))
    if m and m.group(1).lower() in SSH_COMMAND_OPTIONS:
        return shell_offence(m.group(2), depth + 1)
    return offence(value)


def shell_c_offence(args, depth):
    """Check sh -c SCRIPT: the script as a script, and every other word strictly."""
    has_c, i = False, 0
    while i < len(args) and len(args[i]) > 1 and args[i][0] in "-+" and args[i] != "--":
        word = args[i]
        i += 1
        if word in ("-o", "+o", "-O", "+O"):
            i += 1  # its value, the name of a shell option
        elif word[0] == "-" and not word.startswith("--") and "c" in word:
            has_c = True
    if i < len(args) and args[i] == "--":
        i += 1
    if has_c and i < len(args):
        return shell_offence(args[i], depth + 1) or first(offence, args[i + 1 :])
    return first(offence, args)


def rsync_offence(args, depth):
    """Check rsync, whose -e or --rsh value is an ssh command line."""
    i = 0
    while i < len(args):
        word = args[i]
        i += 1
        m = re.fullmatch(r"--rsh(?:=(.*))?|-[A-Za-z0-9]*e(.*)", word, re.S)
        if m:
            value = m.group(1) or m.group(2)
            if not value and i < len(args):
                value = args[i]
                i += 1
            found = shell_offence(value or "", depth + 1)
        else:
            found = offence(word)
        if found:
            return found
    return None


def git_offence(args, depth):
    """Check git, whose -c core.sshCommand value is an ssh command line."""
    i = 0
    while i < len(args):
        word = args[i]
        i += 1
        if word == "-c" and i < len(args):
            value = args[i]
            i += 1
            m = re.fullmatch(r"core\.sshcommand=(.*)", value, re.S | re.I)
            found = shell_offence(m.group(1), depth + 1) if m else offence(value)
        else:
            found = offence(word)
        if found:
            return found
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
    for key, text in fields(tool_input, tool):
        if tool in SHELL_TOOLS and key in SHELL_FIELDS:
            found = shell_offence(text)
        else:
            found = offence(text)
        if found:
            print(
                "key-guard refused this call because %s. "
                "Agents must not read private keys or the age identity. "
                "A shell command may name an ssh key only to use it or to look "
                "at its name and mode: ssh, scp or sftp -i, ssh -o IdentityFile=, "
                "ssh-add, ssh-keygen -y or -l, and ls, stat, test, chmod or mkdir. "
                "Do not work around this: tell the user what you need, "
                "and let them run the command themselves." % found,
                file=sys.stderr,
            )
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
