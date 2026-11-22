"""Unified test suite runnable via `python3 -m unittest discover -s tests -v` or `pytest`.

Split into three test classes so CI jobs can run the matching subset cleanly:
  - UnitChecks:       pure offline checks (no chezmoi or gitleaks required)
  - ChezmoiChecks:    template rendering and chezmoi-backed behavioral checks
  - SecretHookChecks: local Gitleaks pre-commit/pre-push hook tests
"""

import os
from pathlib import Path
import subprocess
import sys
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "tests"


def _run_script(argv):
    env = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1"}
    result = subprocess.run(argv, cwd=ROOT, env=env, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        detail = "\n".join(part for part in (result.stdout.strip(), result.stderr.strip()) if part)
        raise AssertionError(f"Command {' '.join(argv)} failed (exit {result.returncode}):\n{detail}")


class UnitChecks(unittest.TestCase):
    def test_mise_catalog_schema(self):
        catalog = tomllib.loads((ROOT / ".chezmoidata/mise.toml").read_text(encoding="utf-8"))["mise"]
        bundles = tomllib.loads((ROOT / ".chezmoidata/tools.toml").read_text(encoding="utf-8"))["bundles"]
        self.assertTrue(catalog)
        for tool_id, spec in catalog.items():
            self.assertIsInstance(spec.get("tool"), str, f"{tool_id} missing tool string")
            self.assertTrue(spec["tool"].strip(), f"{tool_id} has empty tool string")
        for bundle_name, bundle in bundles.items():
            for tool_id in bundle.get("mise", []):
                self.assertIn(tool_id, catalog, f"bundle {bundle_name} selects unknown mise tool {tool_id}")

    def test_system_packages_schema(self):
        tools = tomllib.loads((ROOT / ".chezmoidata/tools.toml").read_text(encoding="utf-8"))
        sys_pkgs = tools.get("system_packages", {})
        bundles = tools["bundles"]
        self.assertTrue(sys_pkgs)
        for pkg_id, spec in sys_pkgs.items():
            probes = spec.get("probe")
            self.assertIsInstance(probes, list, f"{pkg_id} missing probe list")
            self.assertTrue(probes, f"{pkg_id} probe list is empty")
            for p in probes:
                self.assertTrue(isinstance(p, str) and p.startswith("/"), f"{pkg_id} invalid probe {p!r}")
            has_distro = any(isinstance(spec.get(k), list) and spec[k] for k in ("apt", "dnf", "pacman", "zypper"))
            self.assertTrue(has_distro, f"{pkg_id} must declare at least one distro package list")
        for bundle_name, bundle in bundles.items():
            for pkg_id in bundle.get("system_packages", []):
                self.assertIn(pkg_id, sys_pkgs, f"bundle {bundle_name} selects unknown system_package {pkg_id}")

    def test_fetch_offline(self):
        _run_script([sys.executable, str(TESTS / "check_fetch.py")])

    def test_upgrade_toolchain(self):
        _run_script([sys.executable, str(TESTS / "check_upgrade.py")])

    def test_gpu_fans(self):
        _run_script([sys.executable, str(TESTS / "check_gpu_fans.py")])

    def test_ui_library(self):
        _run_script([sys.executable, str(TESTS / "check_ui.py")])

    def test_zsh_worktree_picker(self):
        _run_script([sys.executable, str(TESTS / "check_wt.py")])

    def test_texlive_path_selection(self):
        _run_script([sys.executable, str(TESTS / "check_texlive_path.py")])

    def test_agent_reconcile_and_notify(self):
        _run_script([sys.executable, str(TESTS / "check_agent_reconcile.py")])

    def test_agent_jail_and_policy(self):
        _run_script([sys.executable, str(TESTS / "check_agent_jail.py")])

    def test_key_guard_cases(self):
        _run_script(["bash", str(ROOT / ".github/scripts/check-key-guard.sh")])

    def test_ste_lint_selftest(self):
        _run_script([
            sys.executable,
            str(ROOT / "private_dot_agents/skills/asd-ste100/scripts/executable_ste-lint.py"),
            "--selftest",
        ])


class ChezmoiChecks(unittest.TestCase):
    def test_render_all_machines_and_themes(self):
        _run_script([sys.executable, str(TESTS / "check_render.py")])

    def test_git_xdg_config(self):
        _run_script([sys.executable, str(TESTS / "check_git_difftastic.py")])

    def test_herdr_theme_preservation(self):
        _run_script([sys.executable, str(TESTS / "check_herdr_theme.py")])

    def test_pi_settings_and_packages(self):
        _run_script([sys.executable, str(TESTS / "check_pi.py")])

    def test_zotero_profile_setup(self):
        _run_script([sys.executable, str(TESTS / "check_zotero_profile.py")])

    @unittest.skipIf(os.environ.get("SKIP_RUST_CLI") == "1", "Rust CLI binary tested in CI cli job")
    def test_dotfiles_cli(self):
        _run_script([sys.executable, str(TESTS / "check_dotfiles_cli.py")])


class SecretHookChecks(unittest.TestCase):
    @unittest.skipIf(os.environ.get("SKIP_GITLEAKS") == "1", "Gitleaks binary skipped in CI checks job")
    def test_secret_hooks(self):
        _run_script([sys.executable, str(TESTS / "check_secrets_tests.py")])


if __name__ == "__main__":
    unittest.main(verbosity=2)
