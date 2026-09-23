#!/usr/bin/env bash
# Render scripts for each real profile before checking syntax. The rendered
# manifest hash and bundle guards are part of the executable shell program.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
python3 - <<'PYTHON'
from pathlib import Path
import json
import subprocess
import tempfile
import tomllib

root = Path.cwd()
machines = tomllib.loads((root / ".chezmoidata/machines.toml").read_text())["machines"]
with tempfile.TemporaryDirectory(prefix="chezmoi-scripts-") as temp:
    config = Path(temp) / "config.toml"
    config.write_text('[data]\nmachine = "container"\ntheme = "rose-pine"\n')
    for machine in machines:
        for source in sorted((root / ".chezmoiscripts").glob("*.tmpl")):
            result = subprocess.run(["chezmoi", "--source", str(root), "--config", str(config),
                "--override-data", json.dumps({"machine": machine}), "execute-template", "--file", str(source)],
                text=True, capture_output=True, check=True)
            if ".py." in source.name:
                compile(result.stdout, str(source), "exec")
            else:
                subprocess.run(["bash", "-n"], input=result.stdout, text=True, check=True)
                subprocess.run(["shellcheck", "--severity=warning", "-"], input=result.stdout, text=True, check=True)
        print(f"ok       {machine}: lifecycle scripts render and parse")
PYTHON
