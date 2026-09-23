#!/usr/bin/env bash
# Render what each machine's bundles decide, for every machine in
# .chezmoidata/machines.toml, and check the result. CI bootstraps only the
# container, which selects nothing, so this is where a desktop's lifecycle
# scripts, download manifest, launchers and ignore list get rendered at all.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
python3 - <<'PYTHON'
from pathlib import Path
import json
import subprocess
import sys
import tempfile
import tomllib

root = Path.cwd()
machines = tomllib.loads((root / ".chezmoidata/machines.toml").read_text())["machines"]
bundles = tomllib.loads((root / ".chezmoidata/tools.toml").read_text())["bundles"]


def render(config, machine, source):
    result = subprocess.run(["chezmoi", "--source", str(root), "--config", str(config),
                             "--override-data", json.dumps({"machine": machine}),
                             "execute-template", "--file", str(source)],
                            text=True, capture_output=True)
    if result.returncode:
        sys.exit(f"{source.relative_to(root)} does not render for {machine}:\n{result.stderr}")
    return result.stdout


with tempfile.TemporaryDirectory(prefix="chezmoi-scripts-") as temp:
    config = Path(temp) / "config.toml"
    config.write_text('[data]\nmachine = "container"\ntheme = "rose-pine"\n')
    for machine, entry in machines.items():
        # The lifecycle scripts, as the shell will read them.
        for source in sorted((root / ".chezmoiscripts").glob("*.tmpl")):
            script = render(config, machine, source)
            subprocess.run(["bash", "-n"], input=script, text=True, check=True)
            subprocess.run(["shellcheck", "--severity=warning", "-"], input=script, text=True, check=True)

        # The download manifest names exactly what the bundles select.
        selected = entry["bundles"]
        wanted = {d for b in selected for d in bundles[b].get("downloads", [])}
        manifest = json.loads(render(config, machine, root / "private_dot_config/dotfiles/downloads.json.tmpl"))
        assert set(manifest["resources"]) == wanted, (machine, sorted(manifest["resources"]))

        # A launcher exists exactly where its download is selected.
        for name, download in [("kitty", "kitty"), ("kitty-open", "kitty"), ("zotero", "zotero")]:
            launcher = render(config, machine, root / f"dot_local/share/applications/dotfiles-{name}.desktop.tmpl")
            assert bool(launcher.strip()) == (download in wanted), (machine, name)

        # Unselected config is ignored, including externals fetched into it.
        ignored = render(config, machine, root / ".chezmoiignore").splitlines()
        for bundle, spec in bundles.items():
            for path in spec.get("config", []):
                assert (path in ignored and f"{path}/**" in ignored) == (bundle not in selected), (machine, path)
        print(f"ok       {machine}: scripts, download manifest, launchers and ignores render")
PYTHON
