#!/usr/bin/env python3
"""Upgrade managed toolchains (mise, pixi, dotfiles-fetch, sheldon).

Inherits the caller's environment unconditionally (including any proxy variables
from the shell or `sbc`), updates catalog pins & lockfiles without committing or
pushing, applies updated mise config, installs locked tools, and runs `dotfiles
doctor` at the end.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tomllib

ALL_LAYERS = ("mise", "pixi", "fetch", "sheldon")
SELF_TOOL_IDS = frozenset({"dotfiles-cli"})
PROXY_KEYS = ("https_proxy", "HTTPS_PROXY", "http_proxy", "HTTP_PROXY", "all_proxy", "ALL_PROXY")

_SECTION_RE = re.compile(r"^\[([^\]]+)\]\s*(?:#.*)?$")
_VERSION_LINE_RE = re.compile(r'^(\s*version\s*=\s*")([^"]+)(".*)$')
_CHECK_SECRETS_VERSION_RE = re.compile(r'^(VERSION\s*=\s*")([^"]+)(".*)$', re.M)
_DOTTED_MAJOR_RE = re.compile(r"^(\d+)\.\d+")


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


def version_key(version):
    """Natural ordering key for semver and calver strings (prereleases sort earlier)."""
    text = str(version).strip()
    if text.startswith("v") and len(text) > 1 and text[1].isdigit():
        text = text[1:]
    # Split off a semver prerelease tag (e.g. 1.2.3-rc.1) without splitting ISO
    # dates like 2026-02-08 whose hyphenated components are purely numeric.
    core = text
    pre = ""
    if "-" in text:
        head, tail = text.split("-", 1)
        if not re.fullmatch(r"\d+(?:-\d+)*", text):
            core, pre = head, tail
    tokens = []
    for part in re.split(r"([0-9]+)", core):
        if not part:
            continue
        if part.isdigit():
            tokens.append((0, int(part), ""))
        else:
            tokens.append((1, 0, part))
    if not pre:
        return (tuple(tokens), 1, ())
    pre_tokens = []
    for part in re.split(r"([0-9]+)", pre):
        if not part:
            continue
        if part.isdigit():
            pre_tokens.append((0, int(part), ""))
        else:
            pre_tokens.append((1, 0, part))
    return (tuple(tokens), 0, tuple(pre_tokens))


def major_version(version):
    """Return leading integer major version for dotted semver strings, else None."""
    text = str(version).strip()
    if text.startswith("v") and len(text) > 1 and text[1].isdigit():
        text = text[1:]
    match = _DOTTED_MAJOR_RE.match(text)
    return int(match.group(1)) if match else None


def format_mise_spec(spec, track_override=None):
    """Format a `.chezmoidata/mise.toml` entry for `mise latest <spec>`."""
    tool = spec["tool"]
    if spec.get("version_prefix"):
        tool = f"{tool}[version_prefix={spec['version_prefix']}]"
    track = spec.get("track") if track_override is None else track_override
    if track:
        return f"{tool}@{track}"
    return tool


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


def rewrite_mise_catalog(text, updates):
    """Update `version = "..."` lines in `.chezmoidata/mise.toml`, preserving layout."""
    if not updates:
        return text
    out_lines = []
    current_id = None
    replaced = set()
    for line in text.splitlines(keepends=True):
        sec_match = _SECTION_RE.match(line.strip())
        if sec_match:
            sec = sec_match.group(1).strip()
            if sec.startswith("mise.") and "." not in sec[5:]:
                current_id = sec[5:]
            else:
                current_id = None
            out_lines.append(line)
            continue
        if current_id in updates:
            ver_match = _VERSION_LINE_RE.match(line.rstrip("\r\n"))
            if ver_match:
                eol = line[len(line.rstrip("\r\n")):]
                new_line = f"{ver_match.group(1)}{updates[current_id]}{ver_match.group(3)}{eol}"
                out_lines.append(new_line)
                replaced.add(current_id)
                continue
        out_lines.append(line)

    missing = sorted(set(updates) - replaced)
    if missing:
        raise ValueError(f"failed to locate version line(s) in mise.toml for: {', '.join(missing)}")

    updated_text = "".join(out_lines)
    parsed = tomllib.loads(updated_text)["mise"]
    for tool_id, target_ver in updates.items():
        if parsed.get(tool_id, {}).get("version") != target_ver:
            raise ValueError(f"post-write verification failed for {tool_id}")
    return updated_text


def rewrite_check_secrets_version(text, new_version):
    """Keep `.github/scripts/check-secrets.py` VERSION in sync with gitleaks."""
    updated, count = _CHECK_SECRETS_VERSION_RE.subn(
        lambda m: f"{m.group(1)}{new_version}{m.group(3)}",
        text,
        count=1,
    )
    if count != 1:
        raise ValueError("could not locate VERSION = \"...\" in .github/scripts/check-secrets.py")
    return updated


def resolve_mise_upgrade(tool_id, spec, query_fn, no_major=False):
    """Compare a single mise catalog entry against upstream `mise latest`."""
    current = str(spec["version"])
    query_spec = format_mise_spec(spec)
    rc, latest, err = query_fn(query_spec)
    if rc != 0:
        return {
            "id": tool_id,
            "current": current,
            "status": "error",
            "detail": err or f"mise latest exited {rc}",
        }
    latest = (latest or "").strip().splitlines()[-1].strip() if (latest or "").strip() else ""
    if not latest:
        return {
            "id": tool_id,
            "current": current,
            "status": "unchanged",
            "detail": "no eligible release returned",
        }
    if version_key(latest) <= version_key(current):
        return {
            "id": tool_id,
            "current": current,
            "status": "unchanged",
        }

    if no_major and not spec.get("track"):
        cur_maj = major_version(current)
        new_maj = major_version(latest)
        if cur_maj is not None and new_maj is not None and new_maj > cur_maj:
            same_spec = format_mise_spec(spec, track_override=str(cur_maj))
            same_rc, same_latest, _ = query_fn(same_spec)
            same_latest = (
                same_latest.strip().splitlines()[-1].strip()
                if same_rc == 0 and (same_latest or "").strip()
                else ""
            )
            if same_latest and version_key(same_latest) > version_key(current):
                return {
                    "id": tool_id,
                    "current": current,
                    "new_version": same_latest,
                    "held_major": latest,
                    "status": "upgrade",
                }
            return {
                "id": tool_id,
                "current": current,
                "held_major": latest,
                "status": "held",
            }

    return {
        "id": tool_id,
        "current": current,
        "new_version": latest,
        "status": "upgrade",
    }


def locate_source_repo(env):
    """Find the chezmoi source repository containing `.chezmoidata/mise.toml`."""
    chezmoi = shutil.which("chezmoi", path=env.get("PATH"))
    if chezmoi:
        res = subprocess.run(
            [chezmoi, "source-path"],
            env=env,
            text=True,
            capture_output=True,
            timeout=10,
            check=False,
        )
        if res.returncode == 0 and res.stdout.strip():
            candidate = Path(res.stdout.strip())
            if (candidate / ".chezmoidata/mise.toml").is_file():
                return candidate
    cwd = Path.cwd()
    if (cwd / ".chezmoidata/mise.toml").is_file():
        return cwd
    return None


def _run_step(cmd, env, cwd=None):
    print(f"  $ {' '.join(cmd)}", flush=True)
    res = subprocess.run(cmd, env=env, cwd=cwd, check=False)
    return res.returncode


def upgrade_mise(args, env):
    """Check and optionally upgrade `.chezmoidata/mise.toml` + lockfile + installed tools."""
    print("\n==> [mise] Checking locked tools", flush=True)
    mise_bin = shutil.which("mise", path=env.get("PATH"))
    if not mise_bin:
        print("  mise not found on PATH; skipping.", flush=True)
        return {"status": "skipped", "upgrades": [], "held": [], "errors": []}

    root = locate_source_repo(env)
    if root is None:
        print("  error: could not locate chezmoi source repo with .chezmoidata/mise.toml", file=sys.stderr)
        return {"status": "error", "upgrades": [], "held": [], "errors": ["source repo not found"]}

    catalog_path = root / ".chezmoidata/mise.toml"
    catalog_text = catalog_path.read_text(encoding="utf-8")
    catalog = tomllib.loads(catalog_text)["mise"]

    check_items = []
    skipped_self = []
    for tool_id, spec in catalog.items():
        if tool_id in SELF_TOOL_IDS and not args.include_self:
            skipped_self.append(tool_id)
            continue
        check_items.append((tool_id, spec))

    if skipped_self:
        print(
            f"  skipping self-released tool(s): {', '.join(skipped_self)} (use --include-self to check)",
            flush=True,
        )
    print(f"  querying {len(check_items)} tools (jobs={args.jobs})...", flush=True)

    def query_latest(spec_str):
        try:
            res = subprocess.run(
                [mise_bin, "latest", spec_str],
                env=env,
                cwd=root,
                text=True,
                capture_output=True,
                timeout=45,
                check=False,
            )
            return res.returncode, res.stdout.strip(), res.stderr.strip()
        except (OSError, subprocess.SubprocessError) as exc:
            return 1, "", str(exc)

    results = {}
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        futs = {
            pool.submit(resolve_mise_upgrade, tid, spec, query_latest, args.no_major): tid
            for tid, spec in check_items
        }
        for fut in as_completed(futs):
            tid = futs[fut]
            results[tid] = fut.result()

    ordered = [results[tid] for tid, _ in check_items]
    upgrades = [r for r in ordered if r["status"] == "upgrade"]
    held = [r for r in ordered if r["status"] == "held"]
    errors = [r for r in ordered if r["status"] == "error"]

    for item in upgrades:
        extra = f"  (held major {item['held_major']})" if item.get("held_major") else ""
        track_note = f"  [track {catalog[item['id']]['track']}]" if catalog[item["id"]].get("track") else ""
        print(f"  + {item['id']:<34} {item['current']} -> {item['new_version']}{track_note}{extra}", flush=True)
    for item in held:
        print(f"  ~ {item['id']:<34} {item['current']}  (major {item['held_major']} skipped by --no-major)", flush=True)
    for item in errors:
        print(f"  ! {item['id']:<34} {item['detail']}", file=sys.stderr, flush=True)

    if not upgrades:
        print(f"  all {len(check_items)} checked mise tools are up to date.", flush=True)
        return {
            "status": "warn" if errors else "ok",
            "upgrades": upgrades,
            "held": held,
            "errors": errors,
        }

    if args.dry_run:
        print(f"  [dry-run] would update {len(upgrades)} tool(s) in .chezmoidata/mise.toml and regenerate mise.lock.", flush=True)
        return {
            "status": "dry-run",
            "upgrades": upgrades,
            "held": held,
            "errors": errors,
        }

    update_map = {item["id"]: item["new_version"] for item in upgrades}
    new_catalog_text = rewrite_mise_catalog(catalog_text, update_map)
    catalog_path.write_text(new_catalog_text, encoding="utf-8")
    print(f"  updated {catalog_path.relative_to(root)} ({len(update_map)} tool(s))", flush=True)

    if "gitleaks" in update_map:
        hook_path = root / ".github/scripts/check-secrets.py"
        if hook_path.is_file():
            new_hook = rewrite_check_secrets_version(
                hook_path.read_text(encoding="utf-8"),
                update_map["gitleaks"],
            )
            hook_path.write_text(new_hook, encoding="utf-8")
            print(f"  synced {hook_path.relative_to(root)} VERSION -> {update_map['gitleaks']}", flush=True)

    if _run_step([mise_bin, "run", "lock-tools"], env=env, cwd=root) != 0:
        print("  error: `mise run lock-tools` failed; inspect changes or revert with git checkout", file=sys.stderr)
        return {"status": "error", "upgrades": upgrades, "held": held, "errors": errors + ["lock-tools failed"]}

    chezmoi = shutil.which("chezmoi", path=env.get("PATH"))
    if chezmoi:
        xdg_cfg = Path(env.get("XDG_CONFIG_HOME") or (Path.home() / ".config"))
        if _run_step([chezmoi, "apply", str(xdg_cfg / "mise")], env=env) != 0:
            return {"status": "error", "upgrades": upgrades, "held": held, "errors": errors + ["chezmoi apply failed"]}

    install_env = {**env, "MISE_YES": "1"}
    home = Path(env.get("HOME") or Path.home())
    if _run_step([mise_bin, "install", "--locked"], env=install_env, cwd=home) != 0:
        return {"status": "error", "upgrades": upgrades, "held": held, "errors": errors + ["mise install failed"]}
    _run_step([mise_bin, "reshim"], env=install_env, cwd=home)
    _run_step([mise_bin, "prune", "--yes"], env=install_env, cwd=home)

    return {
        "status": "warn" if errors else "ok",
        "upgrades": upgrades,
        "held": held,
        "errors": errors,
    }


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
    """Upgrade unpinned dotfiles-fetch downloads and report newer pinned releases."""
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
    # Also surface any pinned items (e.g. Zotero .xpi plugins) with newer upstream tags.
    _run_step([fetch_bin, "outdated"], env=env)
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


def build_parser():
    parser = argparse.ArgumentParser(
        prog="dotfiles upgrade",
        description="Upgrade managed toolchains (mise, pixi, fetch, sheldon) using the caller's environment.",
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
        help="Limit to specific layer(s): mise, pixi, fetch, sheldon (comma-separated or repeatable)",
    )
    parser.add_argument(
        "--no-major",
        action="store_true",
        help="Skip major version jumps in mise (still upgrades within the current major)",
    )
    parser.add_argument(
        "--include-self",
        action="store_true",
        help="Also check self-released dotfiles-cli (skipped by default)",
    )
    parser.add_argument(
        "-j",
        "--jobs",
        type=int,
        default=8,
        help="Parallel upstream version queries for mise (default: 8)",
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

    had_error = False
    mise_summary = None
    for layer in layers:
        if layer == "mise":
            mise_summary = upgrade_mise(args, env)
            if mise_summary["status"] == "error":
                had_error = True
        elif layer == "pixi":
            if upgrade_pixi(args, env) == "error":
                had_error = True
        elif layer == "fetch":
            if upgrade_fetch(args, env) == "error":
                had_error = True
        elif layer == "sheldon":
            if upgrade_sheldon(args, env) == "error":
                had_error = True

    if not args.dry_run:
        dotfiles_bin = shutil.which("dotfiles", path=env.get("PATH"))
        if dotfiles_bin:
            print("\n==> [doctor] Verifying host state", flush=True)
            _run_step([dotfiles_bin, "doctor"], env=env)

    if mise_summary and mise_summary["upgrades"] and not args.dry_run:
        print(
            "\nNext steps (changes are uncommitted so you can inspect or roll back):\n"
            "  chezmoi cd && git diff              # review catalog & lockfile changes\n"
            "  dotfiles check                      # run pre-commit + full test suite\n"
            "  git commit && git push              # publish updates for other machines",
            flush=True,
        )

    return 1 if had_error else 0


if __name__ == "__main__":
    sys.exit(main())
