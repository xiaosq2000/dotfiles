#!/usr/bin/env python3
"""Upgrade managed toolchains locally (mise, pixi, fetch, sheldon, pi).

Inherits the caller's environment unconditionally (including any proxy variables
from the shell or `sbc`), upgrades each selected layer directly on this host
without modifying git-tracked dotfiles, and runs `dotfiles doctor` at the end.
"""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ALL_LAYERS = ("mise", "pixi", "fetch", "sheldon", "pi")
PROXY_KEYS = ("https_proxy", "HTTPS_PROXY", "http_proxy", "HTTP_PROXY", "all_proxy", "ALL_PROXY")


def parse_only(raw_values):
    """Parse repeatable / comma-separated --only values into canonical layer order."""
    if not raw_values:
        return list(ALL_LAYERS)
    chosen = set()
    for item in raw_values:
        for part in item.split(","):
            name = part.strip().lower()
            if not name:
                continue
            if name not in ALL_LAYERS:
                valid = ", ".join(ALL_LAYERS)
                raise ValueError(f"unknown layer {name!r} (expected one of: {valid})")
            chosen.add(name)
    if not chosen:
        return list(ALL_LAYERS)
    return [layer for layer in ALL_LAYERS if layer in chosen]


def active_proxy_summary(env):
    """Describe active proxy env vars without modifying `env`."""
    found = []
    seen = set()
    for key in PROXY_KEYS:
        val = env.get(key)
        if val and key.lower() not in seen:
            seen.add(key.lower())
            found.append(f"{key}={val}")
    return ", ".join(found) if found else None


def build_env(base_env=None):
    """Build subprocess env inheriting caller env (including proxy vars) verbatim."""
    env = dict(os.environ if base_env is None else base_env)
    home = Path(env.get("HOME") or Path.home())
    extra_bins = [
        str(home / ".local/opt/dotfiles/bin"),
        str(home / ".local/share/mise/shims"),
        str(home / ".pixi/bin"),
        str(home / ".local/bin"),
    ]
    current_path = env.get("PATH", "").split(os.pathsep) if env.get("PATH") else []
    prefix = [p for p in extra_bins if p not in current_path]
    if prefix:
        env["PATH"] = os.pathsep.join(prefix + current_path)

    if not env.get("GITHUB_TOKEN") and not env.get("GH_TOKEN"):
        gh = shutil.which("gh", path=env.get("PATH"))
        if gh:
            token = subprocess.run(
                [gh, "auth", "token"],
                env=env,
                text=True,
                capture_output=True,
                timeout=5,
                check=False,
            )
            if token.returncode == 0 and token.stdout.strip():
                env["GITHUB_TOKEN"] = token.stdout.strip()
    return env


def _run_step(cmd, env, cwd=None):
    print(f"  $ {' '.join(cmd)}", flush=True)
    res = subprocess.run(cmd, env=env, cwd=cwd, check=False)
    return res.returncode


def upgrade_mise(args, env):
    """Check or upgrade global mise tools (latest / configured tracks)."""
    print("\n==> [mise] CLIs, runtimes, LSPs, and agents", flush=True)
    mise_bin = shutil.which("mise", path=env.get("PATH"))
    if not mise_bin:
        print("  mise not found on PATH; skipping.", flush=True)
        return "skipped"
    home = Path(env.get("HOME") or Path.home())
    if args.dry_run:
        rc = _run_step([mise_bin, "outdated"], env=env, cwd=home)
        return "dry-run" if rc == 0 else "warn"
    upgrade_env = {**env, "MISE_YES": "1"}
    rc = _run_step([mise_bin, "upgrade"], env=upgrade_env, cwd=home)
    if rc != 0:
        return "error"
    _run_step([mise_bin, "reshim"], env=upgrade_env, cwd=home)
    return "ok"


def upgrade_pixi(args, env):
    """Upgrade global pixi environments via `pixi global update`."""
    print("\n==> [pixi] Global environments", flush=True)
    pixi_bin = shutil.which("pixi", path=env.get("PATH"))
    if not pixi_bin:
        print("  pixi not found on PATH; skipping.", flush=True)
        return "skipped"
    if args.dry_run:
        print("  [dry-run] would run: pixi global update", flush=True)
        return "dry-run"
    rc = _run_step([pixi_bin, "global", "update"], env=env)
    return "ok" if rc == 0 else "error"


def upgrade_fetch(args, env):
    """Upgrade dotfiles-fetch downloads (GUI apps, fonts, Zotero plugins, agy)."""
    print("\n==> [fetch] Managed apps, fonts, and plugins", flush=True)
    home = Path(env.get("HOME") or Path.home())
    fetch_path = home / ".local/libexec/dotfiles/dotfiles-fetch"
    if not fetch_path.is_file():
        print(f"  {fetch_path} not found; skipping.", flush=True)
        return "skipped"
    fetch_bin = str(fetch_path)
    if args.dry_run:
        rc = _run_step([fetch_bin, "outdated"], env=env)
        return "dry-run" if rc == 0 else "warn"
    rc = _run_step([fetch_bin, "update"], env=env)
    return "ok" if rc == 0 else "error"


def upgrade_sheldon(args, env):
    """Upgrade Zsh plugins via `sheldon --non-interactive lock --update`."""
    print("\n==> [sheldon] Zsh plugins", flush=True)
    sheldon_bin = shutil.which("sheldon", path=env.get("PATH"))
    if not sheldon_bin:
        print("  sheldon not found on PATH; skipping.", flush=True)
        return "skipped"
    if args.dry_run:
        print("  [dry-run] would run: sheldon --non-interactive lock --update", flush=True)
        return "dry-run"
    rc = _run_step([sheldon_bin, "--non-interactive", "lock", "--update"], env=env)
    return "ok" if rc == 0 else "error"


def upgrade_pi(args, env):
    """Upgrade Pi npm extensions via `pi update --extensions` (mise owns pi itself)."""
    print("\n==> [pi] Pi extensions", flush=True)
    pi_bin = shutil.which("pi", path=env.get("PATH"))
    if not pi_bin:
        print("  pi not found on PATH; skipping.", flush=True)
        return "skipped"
    if args.dry_run:
        print("  [dry-run] would run: pi update --extensions", flush=True)
        return "dry-run"
    home = Path(env.get("HOME") or Path.home())
    pi_env = {
        **env,
        "PI_CODING_AGENT_DIR": str(home / ".pi/agent"),
        "PI_TELEMETRY": "0",
    }
    rc = _run_step([pi_bin, "update", "--extensions"], env=pi_env, cwd=home)
    return "ok" if rc == 0 else "error"


def build_parser():
    parser = argparse.ArgumentParser(
        prog="dotfiles upgrade",
        description="Upgrade managed toolchains locally (mise, pixi, fetch, sheldon, pi) using the caller's environment.",
    )
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="Check upstream versions and print planned actions without modifying anything",
    )
    parser.add_argument(
        "--only",
        action="append",
        metavar="LAYER",
        help="Limit to specific layer(s): mise, pixi, fetch, sheldon, pi (comma-separated or repeatable)",
    )
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        layers = parse_only(args.only)
    except ValueError as exc:
        parser.error(str(exc))

    env = build_env()
    proxy_note = active_proxy_summary(env)
    if proxy_note:
        print(
            f"note: inheriting shell proxy ({proxy_note}) — unset proxy vars to run direct",
            flush=True,
        )

    runners = {
        "mise": upgrade_mise,
        "pixi": upgrade_pixi,
        "fetch": upgrade_fetch,
        "sheldon": upgrade_sheldon,
        "pi": upgrade_pi,
    }
    had_error = False
    for layer in layers:
        if runners[layer](args, env) == "error":
            had_error = True

    if not args.dry_run:
        dotfiles_bin = shutil.which("dotfiles", path=env.get("PATH"))
        if dotfiles_bin:
            print("\n==> [doctor] Verifying host state", flush=True)
            _run_step([dotfiles_bin, "doctor"], env=env)

    return 1 if had_error else 0


if __name__ == "__main__":
    sys.exit(main())
