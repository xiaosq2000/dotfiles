#!/usr/bin/env python3
"""Refuse an agent tool call that could read private keys, the age identity, or local credentials.

Claude Code and Codex run this as a PreToolUse hook, sharing one rule. The call
arrives on stdin as JSON with tool_name and tool_input. Exit 2 with the reason
on stderr refuses the call, and exit 0 lets it through.

It matches text, not files. A call that names a guarded secret is refused,
which covers the Read tool, cat, cp, find -name and the like. The exceptions
are shell commands that name an ssh key only to use it or to look at its name
and mode (ssh -i, ssh-add, ssh-keygen -y, ls, stat and restrictive chmod), or
inline text that never opens a file: git commit -m messages, gh title and body
text, and grep or rg search patterns. To find those, the command is split into
words the way a shell splits it, and a command sent over ssh is checked the
same way. A command whose effect the split cannot follow, such as one with
$(...), is refused if it names a guarded secret at all.

Text matching cannot stop a command that builds the path at run time.
docs/secrets.md lists the other layers each agent gets and what none of them
covers.
"""

import json
import os
import re
import shlex
import sys

# Relative paths under ~/.ssh that hold nothing secret. Any traversal (`..`),
# glob character, or other filename counts as a private key.
PUBLIC_SSH_REL = re.compile(
    r"(?:config|config\.d(?:/[^/*?\[{]+)*|known_hosts(?:\.old)?|authorized_keys2?|[^/*?\[{]+\.pub)"
)

# .ssh as a path component, and the remaining relative path after it, if any.
# The lookarounds keep .sshrc, foo.ssh and chezmoi's private_dot_ssh from matching.
SSH_PATH = re.compile(r"(?<![\w.-])\.ssh(?![\w.-])(?:/([^\s\"'`;|&<>()]*))?")

# A default key name without the directory, as in `find ~ -name 'id_*'`, or
# `cat id_ed25519` from inside ~/.ssh.
KEY_NAME = re.compile(r"(?<![\w.-])id_(?:(?:rsa|dsa|ecdsa|ed25519|xmss)(?:_sk)?|\*)[\w*?.-]*")

# The chezmoi age identity and its config directory (~/.config/chezmoi/).
# Loaded from ~/.config/dotfiles/policy.json (rendered from .chezmoidata/policy.toml)
# when present, with fail-closed embedded defaults when running standalone.
def _load_secrets_policy():
    policy_file = os.path.join(
        os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"),
        "dotfiles",
        "policy.json",
    )
    try:
        with open(policy_file, encoding="utf-8") as fh:
            data = json.load(fh)
        secrets = data.get("secrets") if isinstance(data, dict) else None
        if isinstance(secrets, dict):
            return secrets
    except (OSError, ValueError):
        pass
    return {}


_POLICY = _load_secrets_policy()
SAFE_CHEZMOI_FILES = set(_POLICY.get("safe_chezmoi_files") or ("chezmoi.toml", "chezmoistate.boltdb"))
CHEZMOI_CONFIG_PATH = re.compile(r"(?<![\w.-])\.config/chezmoi(?:/([^\s\"'`;|&<>()]*))?")
CHEZMOI_PATH = re.compile(r"(?<![\w.-])((?:[^\s\"'`;|&<>(),:=]*/)?chezmoi)/([^\s\"'`;|&<>(),:=]+)")
CHEZMOI_SOURCE_DIR = re.compile(r"(?:^|/)(?:\.local/)?share/chezmoi$")
GLOB_CHARS = re.compile(r"[*?\[{]")
# Basenames that look like the age identity (key, key.txt, key.*, key.t?t,
# key_backup) without flagging unrelated repo paths such as keyd, keymap.rs,
# keymaps.lua, or keyboard.conf.
AGE_KEY_BASENAME = re.compile(r"^key(?:$|[._-]|[*?\[{])")

# Local credential stores and agent auth files that agents must never read.
CREDENTIAL_PATTERNS = (
    (re.compile(r"(?<![\w.-])\.secrets(?![\w.-])"), "it names the local ~/.secrets directory"),
    (re.compile(r"(?<![\w.-])\.config/gh/hosts[^\s\"'`;|&<>()]*"), "it names GitHub CLI credentials (~/.config/gh/hosts.yml)"),
    (re.compile(r"(?<![\w.-])\.aws/credentials(?![\w.-])"), "it names AWS credentials (~/.aws/credentials)"),
    (re.compile(r"(?<![\w.-])\.netrc(?![\w.-])"), "it names ~/.netrc credentials"),
    (re.compile(r"(?<![\w.-])\.git-credentials(?![\w.-])"), "it names ~/.git-credentials"),
    (re.compile(r"(?<![\w.-])(?:cache/)?\.?huggingface/token(?![\w.-])"), "it names a Hugging Face token"),
    (re.compile(r"(?<![\w.-])\.claude/\.credentials\.json(?![\w.-])"), "it names Claude Code credentials"),
    (re.compile(r"(?<![\w.-])\.codex/auth\.json(?![\w.-])"), "it names Codex credentials"),
    (re.compile(r"(?<![\w.-])\.pi/agent/auth\.json(?![\w.-])"), "it names Pi credentials"),
)

# Vault CLI subcommands that print stored secrets (including the age identity).
_raw_vault = _POLICY.get("vault_read_commands")
VAULT_READ_COMMANDS = (
    {k: set(v) for k, v in _raw_vault.items() if isinstance(v, list)}
    if isinstance(_raw_vault, dict) and _raw_vault
    else {"rbw": {"get", "dump"}, "secret-tool": {"lookup", "search"}}
)

# Modes allowed when running chmod against ~/.ssh or an ssh private key.
RESTRICTIVE_CHMOD_MODES = {
    "400", "0400", "600", "0600", "700", "0700",
    "go-rwx", "g-rwx,o-rwx", "o-rwx,g-rwx", "u=rw,go=", "u=rwx,go=", "u=r,go=",
}

# Tools whose command is a shell script, split into words rather than matched
# whole: Bash in Claude Code and Codex, Claude Code's Monitor, and Antigravity
# CLI's run_command. Codex may send the command as an argv list.
SHELL_TOOLS = {"bash", "monitor", "run_command"}
SHELL_FIELDS = {"command", "cmd", "commandline"}

# Commands that act on a file's name or mode and never print what is in it.
# chmod is handled separately so permissions cannot be loosened on private keys.
# file, du and sort are left out: `file -f`, `du --files0-from` and
# `sort --files0-from` read a list of names from a file, so their errors would
# echo a key's lines.
METADATA = {"ls", "stat", "test", "[", "[[", "mkdir", "realpath", "readlink"}

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
    key_l = key.lower() if isinstance(key, str) else ""
    if isinstance(value, str):
        # Prose labels and search regexes/queries never open a file by themselves.
        if key_l in ("description", "toolsummary"):
            return
        if (key_l == "pattern" and tool == "grep") or (key_l == "query" and tool == "grep_search"):
            return
        yield key_l, value
    elif isinstance(value, dict):
        for k, v in value.items():
            yield from fields(v, tool, k)
    elif isinstance(value, list):
        if tool in SHELL_TOOLS and key_l in SHELL_FIELDS and all(isinstance(v, str) for v in value):
            # Codex sends a command as an argv list, such as bash -lc SCRIPT.
            yield key_l, shlex.join(value)
            return
        for v in value:
            yield from fields(v, tool, key)


VAULT_HINT = re.compile(r"(?<![\w.-])(?:rbw|secret-tool)(?![\w.-])")


def ssh_key(text):
    """Return why the text names an ssh private key, or None."""
    for m in SSH_PATH.finditer(text):
        rest = m.group(1)
        if rest is None:
            return "it names an ssh private key or the ~/.ssh directory (" + m.group(0) + ")"
        rest = rest.rstrip("/")
        if not rest or ".." in rest.split("/") or not PUBLIC_SSH_REL.fullmatch(rest):
            return "it names an ssh private key or the ~/.ssh directory (" + m.group(0) + ")"
    for m in KEY_NAME.finditer(text):
        if not m.group(0).endswith(".pub"):
            return "it names an ssh private key (" + m.group(0) + ")"
    return None


def age_identity(text):
    """Return why the text names the age identity or ~/.config/chezmoi, or None."""
    for m in CHEZMOI_CONFIG_PATH.finditer(text):
        rest = m.group(1)
        if rest is None:
            return "it names the chezmoi config directory (~/.config/chezmoi)"
        rest = rest.rstrip("/")
        if ".." in rest.split("/") or rest not in SAFE_CHEZMOI_FILES:
            return "it names the chezmoi age identity or protected file (" + m.group(0) + ")"
    for m in CHEZMOI_PATH.finditer(text):
        prefix, rest = m.group(1), m.group(2)
        parts = [p for p in rest.split("/") if p and p != "."]
        if not parts:
            continue
        has_traversal = ".." in parts
        # ~/.local/share/chezmoi is the public dotfiles source tree, never the
        # config directory holding key.txt; still block `..` traversal out of it
        # or an explicit key.txt path.
        if CHEZMOI_SOURCE_DIR.search(prefix) and not has_traversal:
            if any(p == "key.txt" for p in parts):
                return "it names the chezmoi age identity (~/.config/chezmoi/key.txt)"
            continue
        if has_traversal and any(p.startswith("key") or GLOB_CHARS.search(p) for p in parts):
            return "it names the chezmoi age identity (~/.config/chezmoi/key.txt)"
        if len(parts) == 1 and (parts[0].startswith("key") or GLOB_CHARS.search(parts[0])):
            return "it names the chezmoi age identity (~/.config/chezmoi/key.txt)"
        if len(parts) > 1 and GLOB_CHARS.search(parts[0]):
            return "it names the chezmoi age identity (~/.config/chezmoi/key.txt)"
        if AGE_KEY_BASENAME.match(parts[-1]):
            return "it names the chezmoi age identity (~/.config/chezmoi/key.txt)"
    return None


def credential_secret(text):
    """Return why the text names a local credential store or agent auth file, or None."""
    for pattern, reason in CREDENTIAL_PATTERNS:
        if pattern.search(text):
            return reason
    return None


def non_ssh_offence(text):
    """Return why the text names a non-ssh secret (never allowed even in metadata/ssh)."""
    return age_identity(text) or credential_secret(text)


def offence(text):
    """Return why the text names something an agent must not read, or None."""
    return ssh_key(text) or non_ssh_offence(text)


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
    """Return why a shell script could read a key or credential, or None."""
    found = offence(script)
    has_vault = bool(VAULT_HINT.search(script))
    if found is None and not has_vault:
        return None
    if depth > 3 or OPAQUE.search(script):
        return found or ("it invokes a credential vault command in an opaque shell expression" if has_vault else None)
    try:
        pipelines = split(script)
    except ValueError:
        return found or ("it invokes a credential vault command in an unparseable shell expression" if has_vault else None)
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


def chmod_offence(args):
    """Allow chmod on ssh paths only when the mode is strictly restrictive."""
    found = first(non_ssh_offence, args)
    if found:
        return found
    operands = []
    options = True
    for word in args:
        if options and word == "--":
            options = False
            continue
        if options and word.startswith("-") and len(word) > 1:
            if word.startswith("--reference"):
                return "chmod --reference is not allowed on ssh private keys"
            found = offence(word)
            if found:
                return found
            continue
        operands.append(word)
    if not any(ssh_key(a) for a in operands):
        return None
    mode = operands[0] if operands else ""
    if mode not in RESTRICTIVE_CHMOD_MODES:
        return "chmod mode %r could weaken permissions on ssh private keys" % (mode,)
    return None


def vault_offence(name, args):
    """Refuse Bitwarden / libsecret subcommands that print secrets."""
    blocked = VAULT_READ_COMMANDS[name]
    for word in args:
        if word.startswith("-"):
            continue
        if word in blocked:
            return "it invokes '%s %s', which prints stored secrets" % (name, word)
        break
    return first(offence, args)


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
        rest, found = unwrap(name, args, depth)
        return (found, False) if found else command_offence(rest, depth)
    if name in METADATA:
        return first(non_ssh_offence, args), any(ssh_key(a) for a in args)
    if name == "chmod":
        return chmod_offence(args), False
    if name in VAULT_READ_COMMANDS:
        return vault_offence(name, args), False
    if name in CLIENTS:
        return client_offence(name, args, depth), False
    if name == "ssh-add":
        return first(non_ssh_offence, args), False
    if name == "ssh-keygen":
        # -y, -l and -B print a public key or a fingerprint. -p, -c, -N and -i
        # rewrite or convert the key, so they stay refused.
        flags = set("".join(a[1:] for a in args if a.startswith("-") and not a.startswith("--")))
        if flags & set("ylB") and not flags & set("pcNi"):
            return first(non_ssh_offence, args), False
    if name in SHELLS:
        return shell_c_offence(args, depth), False
    if name == "rsync":
        return rsync_offence(args, depth), False
    if name == "git":
        return git_offence(args, depth), False
    if name == "gh":
        return gh_offence(args, depth), False
    if name in ("rg", "grep", "egrep", "fgrep"):
        return search_offence(args, depth), False
    if name in DECLARATIONS:
        return first(lambda a: assignment_offence(a, depth) if ASSIGNMENT.match(a) else offence(a), args), False
    return first(offence, words), False


def assignment_offence(word, depth):
    """Check NAME=value, whose value may itself be an ssh command line."""
    name, _, value = word.partition("=")
    if name in SSH_COMMAND_VARIABLES:
        return shell_offence(value, depth + 1)
    return offence(value)


def unwrap(name, args, depth):
    """Return the command a wrapper such as timeout or env runs, and why its options offend."""
    takes_value = WRAPPERS[name]
    i = 0
    while i < len(args) and args[i].startswith("-") and len(args[i]) > 1:
        word = args[i]
        i += 1
        if word == "--":
            break
        if word.startswith("--"):
            if name == "env":
                if word == "--split-string":
                    if i < len(args):
                        val = args[i]
                        i += 1
                        found = shell_offence(val, depth + 1)
                        if found:
                            return [], found
                    continue
                if word.startswith("--split-string="):
                    found = shell_offence(word.partition("=")[2], depth + 1)
                    if found:
                        return [], found
                    continue
                if word == "--chdir" and i < len(args):
                    val = args[i]
                    i += 1
                    found = offence(val)
                    if found:
                        return [], found
                    continue
                if word.startswith("--chdir="):
                    found = offence(word.partition("=")[2])
                    if found:
                        return [], found
                    continue
            found = offence(word)
            if found:
                return [], found
            continue
        for j, letter in enumerate(word[1:], 1):
            if letter in takes_value:
                value = word[j + 1 :]
                if not value and i < len(args):
                    value = args[i]
                    i += 1
                if name == "env" and letter == "S":
                    found = shell_offence(value, depth + 1)
                else:
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
                    found = non_ssh_offence(value)
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
        return non_ssh_offence(m.group(2))
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
    """Check git: options with shell commands, inline messages, and file operands."""
    i = 0
    while i < len(args):
        word = args[i]
        i += 1
        if word == "-c" and i < len(args):
            value = args[i]
            i += 1
            m = re.fullmatch(r"core\.sshcommand=(.*)", value, re.S | re.I)
            found = shell_offence(m.group(1), depth + 1) if m else offence(value)
            if found:
                return found
            continue
        if word.startswith("-c") and len(word) > 2:
            value = word[2:]
            m = re.fullmatch(r"core\.sshcommand=(.*)", value, re.S | re.I)
            found = shell_offence(m.group(1), depth + 1) if m else offence(value)
            if found:
                return found
            continue
        # Inline message options: the text is message data, not a file to read
        if word in ("-m", "--message"):
            if i < len(args):
                i += 1
            continue
        if word.startswith("--message=") or (word.startswith("-m") and len(word) > 2):
            continue
        if word.startswith("--grep="):
            continue
        if word == "--grep" and i < len(args):
            i += 1
            continue
        # Files that git opens to read commit message or template
        if word in ("-F", "--file"):
            if i < len(args):
                found = offence(args[i])
                if found:
                    return found
                i += 1
            continue
        if word.startswith("--file="):
            found = offence(word.partition("=")[2])
            if found:
                return found
            continue
        if word in ("-t", "--template"):
            if i < len(args):
                found = offence(args[i])
                if found:
                    return found
                i += 1
            continue
        if word.startswith("--template="):
            found = offence(word.partition("=")[2])
            if found:
                return found
            continue
        found = offence(word)
        if found:
            return found
    return None


def gh_offence(args, depth):
    """Check gh: inline message and title flags vs file flags and operands."""
    i = 0
    while i < len(args):
        word = args[i]
        i += 1
        # Inline title, body, message and comment text
        if word in ("-t", "--title", "-b", "--body", "-m", "--message", "--comment"):
            if i < len(args):
                i += 1
            continue
        if any(word.startswith(opt + "=") for opt in ("--title", "--body", "--message", "--comment")):
            continue
        if word.startswith(("-t", "-b", "-m")) and len(word) > 2 and not word.startswith("--"):
            continue
        # Files that gh opens to read message or template contents
        if word in ("-F", "--body-file", "--template"):
            if i < len(args):
                found = offence(args[i])
                if found:
                    return found
                i += 1
            continue
        if any(word.startswith(opt + "=") for opt in ("--body-file", "--template")):
            found = offence(word.partition("=")[2])
            if found:
                return found
            continue
        found = offence(word)
        if found:
            return found
    return None


SEARCH_FILE_OPTIONS = {"-f", "--file", "--exclude-from", "--ignore-file"}
SEARCH_COMMAND_OPTIONS = {"--pre"}
SEARCH_PATTERN_OPTIONS = {"-e", "--regexp"}
SEARCH_VALUED_OPTIONS = {
    "-m", "-A", "-B", "-C", "-D", "-d", "-t", "-g", "--type", "--glob",
    "--max-count", "--after-context", "--before-context", "--context",
    "--exclude", "--include", "--exclude-dir", "--include-dir",
}


def search_offence(args, depth):
    """Check grep and rg: search patterns do not open files, but paths, -f and --pre do."""
    has_pattern = False
    options = True
    i = 0
    while i < len(args):
        word = args[i]
        i += 1
        if options and word == "--":
            options = False
            continue
        if options and word.startswith("-") and len(word) > 1:
            if word in SEARCH_COMMAND_OPTIONS:
                if i < len(args):
                    found = shell_offence(args[i], depth + 1)
                    if found:
                        return found
                    i += 1
                continue
            if any(word.startswith(opt + "=") for opt in SEARCH_COMMAND_OPTIONS):
                found = shell_offence(word.partition("=")[2], depth + 1)
                if found:
                    return found
                continue
            if word in SEARCH_FILE_OPTIONS:
                if i < len(args):
                    found = offence(args[i])
                    if found:
                        return found
                    i += 1
                if word in ("-f", "--file"):
                    has_pattern = True
                continue
            if any(word.startswith(opt + "=") for opt in SEARCH_FILE_OPTIONS):
                found = offence(word.partition("=")[2])
                if found:
                    return found
                if word.startswith("--file="):
                    has_pattern = True
                continue
            if word in SEARCH_PATTERN_OPTIONS:
                if i < len(args):
                    i += 1
                has_pattern = True
                continue
            if any(word.startswith(opt + "=") for opt in SEARCH_PATTERN_OPTIONS):
                has_pattern = True
                continue
            if not word.startswith("--"):
                # Parse combined short flags such as -Ff <file>, -f<file>, -Fe <pat>.
                consumed_inline = False
                for j, letter in enumerate(word[1:], 1):
                    if letter == "f":
                        value = word[j + 1 :]
                        if not value and i < len(args):
                            value = args[i]
                            i += 1
                        found = offence(value)
                        if found:
                            return found
                        has_pattern = True
                        consumed_inline = True
                        break
                    if letter == "e":
                        value = word[j + 1 :]
                        if not value and i < len(args):
                            i += 1
                        has_pattern = True
                        consumed_inline = True
                        break
                if consumed_inline:
                    continue
            if word in SEARCH_VALUED_OPTIONS:
                if i < len(args):
                    found = offence(args[i])
                    if found:
                        return found
                    i += 1
                continue
            if any(word.startswith(opt + "=") for opt in SEARCH_VALUED_OPTIONS):
                found = offence(word.partition("=")[2])
                if found:
                    return found
                continue
            found = offence(word)
            if found:
                return found
            continue
        if not has_pattern:
            has_pattern = True
            continue
        found = offence(word)
        if found:
            return found
    return None


def main():
    is_agy = False
    try:
        call = json.load(sys.stdin)
        if not isinstance(call, dict):
            raise ValueError("top-level payload must be a JSON object")
        if isinstance(call.get("toolCall"), dict):
            is_agy = True
            tool = str(call["toolCall"].get("name", "")).lower()
            tool_input = call["toolCall"].get("args", {})
        else:
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
            reason = (
                "key-guard refused this call because %s. "
                "Agents must not read private keys or the age identity. "
                "A shell command may name an ssh key only to use it or to look "
                "at its name and mode: ssh, scp or sftp -i, ssh -o IdentityFile=, "
                "ssh-add, ssh-keygen -y or -l, and ls, stat, test, chmod or mkdir. "
                "Do not work around this: tell the user what you need, "
                "and let them run the command themselves." % found
            )
            if is_agy:
                print(json.dumps({"decision": "deny", "reason": reason}))
                return 0
            print(reason, file=sys.stderr)
            return 2
    if is_agy:
        print(json.dumps({"decision": "allow"}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
