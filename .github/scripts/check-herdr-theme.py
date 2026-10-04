#!/usr/bin/env python3
"""Check Herdr theme switches in a disposable chezmoi destination."""

import os
from pathlib import Path
import subprocess
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[2]
MAPPING = {
    "rose-pine": "rose-pine",
    "rose-pine-moon": "rose-pine",
    "rose-pine-dawn": "rose-pine-dawn",
    "catppuccin-frappe": "catppuccin",
    "catppuccin-macchiato": "catppuccin",
    "catppuccin-mocha": "catppuccin",
    "catppuccin-latte": "catppuccin-latte",
}
FIXTURE = '''# Herdr settings must survive a theme switch.
onboarding = false
[theme]
name = "dracula"
auto_switch = true
[theme.custom]
accent = "#ffffff"
[ui]
status_indicators = "symbols"
[ui.toast]
delivery = "system"
[keys]
prefix = "ctrl+a"
[[keys.command]]
key = "prefix+t"
type = "popup"
command = "pwd"
'''
OTHER = {k: v for k, v in tomllib.loads(FIXTURE).items() if k != "theme"}

with tempfile.TemporaryDirectory(prefix="herdr-theme-") as temporary:
    base = Path(temporary)
    home = base / "home"
    target = home / ".config/herdr/config.toml"
    target.parent.mkdir(parents=True)
    config = base / "chezmoi.toml"
    command = ["chezmoi", "--source", str(ROOT), "--destination", str(home),
               "--config", str(config), "--persistent-state", str(base / "state.boltdb")]

    for variant, palette in MAPPING.items():
        config.write_text(f'[data]\nmachine = "workstation"\ntheme = "{variant}"\n')
        target.write_text(FIXTURE)
        subprocess.run(command + ["apply", "--exclude", "scripts", "--force", str(target)], check=True)
        first = target.read_text()
        settings = tomllib.loads(first)
        assert settings["theme"] == {"name": palette, "auto_switch": False}, variant
        assert {k: v for k, v in settings.items() if k != "theme"} == OTHER, variant
        subprocess.run(command + ["apply", "--exclude", "scripts", str(target)], check=True)
        assert target.read_text() == first, variant

        # Optional local validation uses the real binary without any server.
        if os.environ.get("HERDR_TEST_BIN"):
            subprocess.run([os.environ["HERDR_TEST_BIN"], "config", "check"], check=True,
                           env={**os.environ, "HERDR_CONFIG_PATH": str(target)}, capture_output=True)

    script = subprocess.check_output(command + ["execute-template", "--file",
        str(ROOT / "private_dot_config/herdr/modify_config.toml.tmpl")], text=True)
    for raw in ("", '[theme]\nname = "dracula"\n', '["theme"]\nname = "dracula"\n'):
        result = subprocess.run(["sh", "-c", script], input=raw, text=True, capture_output=True, check=True)
        assert tomllib.loads(result.stdout)["theme"] == {"name": "catppuccin-latte", "auto_switch": False}
    raw = "invalid TOML\n"
    result = subprocess.run(["sh", "-c", script], input=raw, text=True, capture_output=True, check=True)
    assert result.stdout == raw and "unchanged" in result.stderr

    machines = tomllib.loads((ROOT / ".chezmoidata/machines.toml").read_text())["machines"]
    for machine, entry in machines.items():
        config.write_text(f'[data]\nmachine = "{machine}"\ntheme = "rose-pine"\n')
        managed = subprocess.check_output(command + ["managed"], text=True).splitlines()
        assert (".config/herdr/config.toml" in managed) == ("herdr" in entry["bundles"]), machine

    # Exercise the command without contacting a user's running Herdr server.
    stubs = base / "bin"
    stubs.mkdir()
    (stubs / "chezmoi").write_text('''#!/bin/sh
while [ "$1" = "--config" ] || [ "$1" = "--config-format" ]; do
    shift 2
done
case "$1" in
execute-template) echo 'rose-pine catppuccin-mocha' ;;
apply) echo apply >> "$THEME_TEST_LOG" ;;
diff) echo diff >> "$THEME_TEST_LOG" ;;
*) exit 1 ;;
esac
''')
    (stubs / "herdr").write_text('''#!/bin/sh
test "$*" = "server reload-config" || exit 2
echo reload >> "$THEME_TEST_LOG"
exit "${THEME_TEST_RELOAD_STATUS:-0}"
''')
    for stub in stubs.iterdir():
        stub.chmod(0o755)
    log = base / "theme.log"
    environment = {**os.environ, "HOME": str(home), "CHEZMOI_CONFIG_FILE": str(config),
                   "PATH": str(stubs) + os.pathsep + os.environ["PATH"], "THEME_TEST_LOG": str(log)}
    environment.pop("KITTY_WINDOW_ID", None)
    for status in ("0", "1"):
        config.write_text('[data]\ntheme = "rose-pine"\n')
        log.write_text("")
        result = subprocess.run(["bash", str(ROOT / "dot_local/bin/executable_theme"), "catppuccin-mocha"],
                                env={**environment, "THEME_TEST_RELOAD_STATUS": status},
                                text=True, capture_output=True, check=True)
        assert log.read_text().splitlines() == ["apply", "reload"]
        assert ("reloaded herdr" in result.stdout) == (status == "0")
    config.write_text('[data]\ntheme = "rose-pine"\n')
    log.write_text("")
    subprocess.run(["bash", str(ROOT / "dot_local/bin/executable_theme"), "--dry-run", "catppuccin-mocha"],
                   env=environment, text=True, capture_output=True, check=True)
    assert log.read_text().splitlines() == ["diff"]
    assert tomllib.loads(config.read_text())["data"]["theme"] == "rose-pine"

print("Herdr mappings, config preservation, repeated applies, machine selection and theme reload checks passed.")
