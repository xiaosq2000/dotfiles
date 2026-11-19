#!/usr/bin/env python3
"""Unified completion notification hook for Claude Code, Codex, agy, and Pi.

Speaks both the Antigravity CLI Stop JSON contract (must print `{}` on stdout)
and the Claude Code / Codex Stop hook contract, plus direct CLI invocation from
Pi's dotfiles-guard.ts extension.

Suppressed automatically when DOTFILES_AGENT_NOTIFY=0, inside Herdr (which
provides native pane badges/notifications), on user cancellation, or on
headless hosts without a display. Never fails or blocks an agent loop.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def detect_payload(stdin_text):
    if not stdin_text.strip():
        return {}, False
    try:
        data = json.loads(stdin_text)
    except ValueError:
        return {}, False
    if not isinstance(data, dict):
        return {}, False
    is_agy = "conversationId" in data or "hookEventName" in data or "terminationReason" in data
    return data, is_agy


def send_notification(title, body):
    if os.environ.get("DOTFILES_AGENT_NOTIFY") == "0":
        return
    if os.environ.get("HERDR_ENV") == "1":
        return
    if (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")) and shutil.which("notify-send"):
        try:
            subprocess.run(
                [
                    "notify-send",
                    "--app-name",
                    title,
                    "--urgency=low",
                    "--expire-time=5000",
                    title,
                    body,
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=1.5,
                check=False,
            )
            return
        except (OSError, subprocess.SubprocessError):
            pass

    if os.environ.get("KITTY_WINDOW_ID"):
        try:
            with open("/dev/tty", "w", encoding="utf-8") as tty:
                tty.write(f"\x1b]99;i=dotfiles-agent:d=0;{title}\x1b\\")
                tty.write(f"\x1b]99;i=dotfiles-agent:p=body;{body}\x1b\\")
        except OSError:
            pass


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--agent", default="")
    parser.add_argument("--title", default="")
    parser.add_argument("--body", default="")
    args, _ = parser.parse_known_args()

    stdin_text = "" if sys.stdin.isatty() else sys.stdin.read()
    payload, is_agy = detect_payload(stdin_text)

    should_notify = True
    title = args.title or args.agent or "Coding Agent"
    body = args.body or "Ready for input"

    if is_agy:
        reason = str(payload.get("terminationReason") or "")
        if reason == "USER_CANCELED" or payload.get("fullyIdle") is False:
            should_notify = False
        else:
            title = args.title or "Antigravity"
            cwd = payload.get("cwd")
            project = Path(cwd).name if isinstance(cwd, str) and cwd else ""
            if reason == "ERROR":
                body = f"Stopped with error ({project})" if project else "Stopped with error"
            else:
                body = f"Ready in {project}" if project else "Ready for input"
    elif payload:
        if payload.get("stop_hook_active"):
            should_notify = False
        cwd = payload.get("cwd")
        project = Path(cwd).name if isinstance(cwd, str) and cwd else ""
        if not args.title:
            if "transcript_path" in payload and ".claude" in str(payload["transcript_path"]):
                title = "Claude Code"
            elif "session_id" in payload or "turn_id" in payload:
                title = "Codex"
        if not args.body and project:
            body = f"Ready in {project}"

    if should_notify:
        send_notification(title, body)

    if is_agy:
        sys.stdout.write("{}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
