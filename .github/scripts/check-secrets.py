#!/usr/bin/env python3
"""Check raw staged files or all commits that a push would publish."""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

VERSION = "8.30.1"
PROTECTED = ("private_dot_ssh/", "dot_agents/skills/private_machines/references/")
AGE_HEADERS = (b"-----BEGIN AGE ENCRYPTED FILE-----\n", b"age-encryption.org/v1\n")
OID = re.compile(r"(?:[0-9a-f]{40}|[0-9a-f]{64})\Z")
HOME_PATH = re.compile(rb"/home/[A-Za-z0-9._-]+/")
HOME_EXCEPTIONS = {
    "private_dot_config/btop/btop.conf.tmpl",
    ".github/scripts/check-key-guard.sh",
}


class Refused(Exception):
    pass


def git(*args, check=True):
    result = subprocess.run(["git", *args], capture_output=True, check=False)
    if check and result.returncode:
        # Git errors can contain credentials from a remote URL or file content.
        raise Refused("Git could not prepare the secret check. No content was printed.")
    return result


def scanner():
    managed = Path.home() / ".local/opt/dotfiles/bin/gitleaks"
    binary = str(managed) if managed.is_file() else shutil.which("gitleaks")
    if not binary:
        raise Refused("Gitleaks is missing. Run chezmoi apply, then retry.")
    result = subprocess.run(
        [binary, "version"], capture_output=True, text=True, check=False
    )
    if result.returncode or result.stdout.strip() != VERSION:
        raise Refused(f"Gitleaks {VERSION} is required. Run chezmoi apply, then retry.")
    return binary


def changed_paths(commit=None):
    if commit is None:
        args = ("diff", "--cached", "--name-only", "--no-ext-diff", "--no-textconv")
    else:
        # Separate parent comparisons include files introduced by a merge.
        args = (
            "diff-tree",
            "--root",
            "--no-commit-id",
            "-r",
            "-m",
            "--name-only",
            commit,
        )
    output = git(*args, "--no-renames", "--diff-filter=ACMT", "-z", "--").stdout
    return sorted({os.fsdecode(path) for path in output.split(b"\0") if path})


def check_home_path(context, path, content):
    # Gitleaks globally allows filesystem paths. Enforce the repository's
    # stricter account-path policy separately, with the same narrow exceptions.
    match = HOME_PATH.search(content)
    if match and path not in HOME_EXCEPTIONS:
        line = content[: match.start()].count(b"\n") + 1
        raise Refused(f"{context}: {path!r}:{line}: home-path (value redacted).")


def scan(binary, config, context, paths=(), commit=None, message=None):
    with tempfile.TemporaryDirectory(prefix="dotfiles-secret-check-") as temporary:
        root = Path(temporary)
        files = root / "files"
        files.mkdir()
        for path in paths:
            source = f"{commit}:{path}" if commit else f":{path}"
            if git("cat-file", "-t", source).stdout.strip() != b"blob":
                raise Refused(f"{context}: cannot scan non-file {path!r}.")
            content = git("cat-file", "blob", source).stdout
            name = Path(path).name
            encrypted = name.startswith("encrypted_") and name.endswith(".age")
            if path.startswith(PROTECTED) and not encrypted:
                raise Refused(f"{context}: {path!r} must be an encrypted_*.age file.")
            if encrypted:
                if not content.startswith(AGE_HEADERS):
                    raise Refused(f"{context}: {path!r} has no age ciphertext header.")
                # Do not decrypt or scan ciphertext. Other .age files still scan.
                continue
            check_home_path(context, path, content)
            target = files / path
            if Path(path).is_absolute() or ".." in Path(path).parts:
                raise Refused("Git returned an unsafe file path.")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        if message:
            check_home_path(context, "commit or tag message", message)
            metadata = files / ".secret-check-metadata"
            if metadata.exists():
                raise Refused("The reserved .secret-check-metadata path exists.")
            metadata.mkdir()
            (metadata / "message.txt").write_bytes(message)
        if not any(files.iterdir()):
            return
        report = root / "report.json"
        result = subprocess.run(
            [
                binary,
                "dir",
                str(files),
                "--config",
                str(config),
                "--no-banner",
                "--redact=100",
                "--ignore-gitleaks-allow",
                "--exit-code=1",
                "--report-format=json",
                "--report-path",
                str(report),
                "--log-level=error",
            ],
            capture_output=True,
            check=False,
        )
        # Never print scanner output. Even an error can contain a matched line.
        findings = json.loads(report.read_text()) if report.is_file() else None
        if result.returncode:
            if result.returncode == 1 and findings:
                for finding in findings:
                    path = finding["File"]
                    path = path.removeprefix(str(files) + "/")
                    print(
                        f"{context}: {path!r}:{finding['StartLine']}: "
                        f"{finding['RuleID']} (value redacted)",
                        file=sys.stderr,
                    )
                raise Refused(
                    "Secrets detected. Remove or encrypt them before retrying."
                )
            raise Refused(
                "Gitleaks failed. The operation is blocked. No content was printed."
            )
        if findings is None or findings:
            raise Refused(
                "Gitleaks returned an inconsistent report. The operation is blocked."
            )


def commit_id(oid):
    result = git("rev-parse", "--verify", oid + "^{commit}", check=False)
    return result.stdout.decode().strip() if result.returncode == 0 else None


def push(binary, config, remote):
    updates = []
    for line in sys.stdin:
        fields = line.split()
        if (
            len(fields) != 4
            or not OID.fullmatch(fields[1])
            or not OID.fullmatch(fields[3])
        ):
            raise Refused("Invalid pre-push input. The operation is blocked.")
        if set(fields[1]) != {"0"}:
            updates.append(fields)
    if not updates:
        return
    if git("rev-parse", "--is-shallow-repository").stdout.strip() != b"false":
        raise Refused(
            "A shallow clone cannot check outgoing history. Fetch full history first."
        )

    # Query this destination, not --all or refs from another remote. Those refs
    # could exclude a commit that this destination never received.
    advertised = git("ls-remote", "--refs", remote).stdout.splitlines()
    known = {fields[3] for fields in updates if set(fields[3]) != {"0"}}
    for line in advertised:
        oid = line.split()[0].decode()
        if not OID.fullmatch(oid):
            raise Refused("The remote returned an invalid object ID.")
        known.add(oid)
    excluded = {value for oid in known if (value := commit_id(oid))}
    tips = set()
    for _, oid, _, _ in updates:
        tip = commit_id(oid)
        if tip is None:
            raise Refused(
                "Only branches and tags that resolve to commits can pass this hook."
            )
        tips.add(tip)
        # Annotated tag messages are public too. Include nested annotated tags.
        while git("cat-file", "-t", oid).stdout.strip() == b"tag":
            tag = git("cat-file", "tag", oid).stdout
            scan(binary, config, f"tag {oid[:12]}", message=tag)
            oid = tag.splitlines()[0].split()[1].decode()
    args = ["rev-list", "--reverse", "--topo-order", *sorted(tips)]
    if excluded:
        args.extend(["--not", *sorted(excluded)])
    commits = git(*args, "--").stdout.decode().splitlines()
    for commit in commits:
        body = git("cat-file", "commit", commit).stdout.split(b"\n\n", 1)[1]
        scan(
            binary, config, f"commit {commit[:12]}", changed_paths(commit), commit, body
        )
    print(f"secrets: checked {len(commits)} outgoing commit(s).", file=sys.stderr)


def main():
    try:
        root = os.fsdecode(git("rev-parse", "--show-toplevel").stdout.rstrip(b"\n"))
        os.chdir(root)
        config = Path(root) / ".gitleaks.toml"
        binary = scanner()
        # The installer links this program as .git/hooks/pre-push. Git passes
        # the remote name and location, and sends every ref update on stdin.
        if Path(sys.argv[0]).name == "pre-push":
            if len(sys.argv) != 3:
                raise Refused("Git did not provide a push destination.")
            push(binary, config, sys.argv[2])
        elif sys.argv[1:] == ["staged"]:
            scan(binary, config, "staged files", changed_paths())
        else:
            raise Refused(
                "Use check-secrets.py staged, or install it as the pre-push hook."
            )
        return 0
    except (Refused, OSError, ValueError, KeyError, IndexError, TypeError) as error:
        message = (
            str(error)
            if isinstance(error, Refused)
            else "The secret check failed. No content was printed."
        )
        print(f"secrets: {message}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
