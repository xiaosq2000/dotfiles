#!/usr/bin/env python3
"""Test secret hooks with synthetic data in temporary, local repositories."""

import contextlib
import importlib.util
import io
import random
import shutil
import string
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import tomllib

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / ".github/scripts/check-secrets.py"
# Do not leave bytecode files in the chezmoi source tree.
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("secret_check", SCRIPT)
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)
ZERO = "0" * 40
# Construct a fake provider token at run time. No credential is stored here.
TOKEN = (
    "gh"
    + "p_"
    + "".join(random.Random(42).choices(string.ascii_letters + string.digits, k=36))
)


class SecretHooks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="secret-hook-tests-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.repo = self.base / "repo"
        self.repo.mkdir()
        self.remote = self.base / "remote.git"
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Synthetic Test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "tag.gpgsign", "false")
        self.git("config", "core.hooksPath", str(self.repo / ".git/hooks"))
        shutil.copyfile(ROOT / ".gitleaks.toml", self.repo / ".gitleaks.toml")
        self.hook = self.repo / ".git/hooks/pre-push"
        self.hook.symlink_to(SCRIPT)

    def git(self, *args):
        result = subprocess.run(
            ["git", *args], cwd=self.repo, capture_output=True, check=False
        )
        if result.returncode:
            self.fail(f"Fixture git command {args[0]} failed.")
        return result.stdout.decode().strip()

    def write(self, path, content):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)

    def commit(self, message="test(secrets): add synthetic fixture"):
        self.git("commit", "-q", "-m", message)
        return self.git("rev-parse", "HEAD")

    def seed_remote(self):
        self.write("clean.txt", "ordinary text\n")
        self.git("add", "clean.txt")
        self.seed = self.commit()
        # A tiny local clone supplies realistic advertised refs, without a push.
        self.git("clone", "--bare", "--quiet", str(self.repo), str(self.remote))
        return self.seed

    def run_staged(self):
        return subprocess.run(
            ["python3", str(SCRIPT), "staged"],
            cwd=self.repo,
            capture_output=True,
            text=True,
            check=False,
        )

    def run_push(self, updates=None, remote=None):
        if updates is None:
            updates = f"refs/heads/main {self.git('rev-parse', 'HEAD')} refs/heads/main {self.seed}\n"
        return subprocess.run(
            [str(self.hook), "origin", str(remote or self.remote)],
            input=updates,
            cwd=self.repo,
            capture_output=True,
            text=True,
            check=False,
        )

    def assert_blocked(self, result, reason=None):
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(TOKEN, result.stdout + result.stderr)
        if reason:
            self.assertIn(reason, result.stderr)

    def test_staged_index_not_working_tree(self):
        self.write("config.txt", TOKEN + "\n")
        self.git("add", "config.txt")
        self.write("config.txt", "safe working copy\n")
        self.assert_blocked(self.run_staged(), "github-pat")

    def test_unstaged_secret_is_not_committed(self):
        self.write("config.txt", "safe staged copy\n")
        self.git("add", "config.txt")
        self.write("config.txt", TOKEN + "\n")
        self.assertEqual(self.run_staged().returncode, 0)

    def test_arbitrary_age_suffix_is_not_an_exclusion(self):
        self.write("notes.age", TOKEN + "\n")
        self.git("add", "notes.age")
        self.assert_blocked(self.run_staged(), "github-pat")

    def test_protected_plaintext_and_mislabeled_ciphertext(self):
        path = "private_dot_ssh/private_config"
        self.write(path, "Host example\n")
        self.git("add", path)
        self.assert_blocked(self.run_staged(), "must be an encrypted_")
        self.git("rm", "--cached", path)
        path = "private_dot_ssh/encrypted_private_config.age"
        self.write(path, "Host example\n")
        self.git("add", path)
        self.assert_blocked(self.run_staged(), "no age ciphertext header")

    def test_age_identity_and_home_path(self):
        self.write("notes.txt", "AGE-SECRET-KEY-1" + "Q" * 58 + "\n")
        self.git("add", "notes.txt")
        self.assert_blocked(self.run_staged(), "age-identity")
        self.write("notes.txt", "/" + "home/" + "private-account/" + "project\n")
        self.git("add", "notes.txt")
        self.assert_blocked(self.run_staged(), "home-path")

    def test_home_path_exception_is_narrow(self):
        path = "private_dot_config/btop/btop.conf.tmpl"
        self.write(path, "/" + "home/" + "placeholder/" + "project\n")
        self.git("add", path)
        self.assertEqual(self.run_staged().returncode, 0)
        self.write(path, TOKEN + "\n")
        self.git("add", path)
        self.assert_blocked(self.run_staged(), "github-pat")

    def test_removed_secret_in_outgoing_history(self):
        self.seed_remote()
        self.write("config.txt", TOKEN + "\n")
        self.git("add", "config.txt")
        self.commit()
        self.git("rm", "config.txt")
        self.commit("test(secrets): remove synthetic fixture")
        self.assert_blocked(self.run_push(), "github-pat")

    def test_new_branch_and_multiple_refs(self):
        self.seed_remote()
        self.git("checkout", "-q", "-b", "private-branch")
        self.write("config.txt", TOKEN + "\n")
        self.git("add", "config.txt")
        dirty = self.commit()
        updates = (
            f"refs/heads/main {self.seed} refs/heads/main {self.seed}\n"
            f"refs/heads/private-branch {dirty} refs/heads/private-branch {ZERO}\n"
        )
        self.assert_blocked(self.run_push(updates), "github-pat")

    def test_git_push_invokes_hook(self):
        self.seed_remote()
        self.write("config.txt", TOKEN + "\n")
        self.git("add", "config.txt")
        self.commit()
        result = subprocess.run(
            ["git", "push", str(self.remote), "HEAD:refs/heads/main"],
            cwd=self.repo,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assert_blocked(result, "github-pat")
        published = self.git("ls-remote", str(self.remote), "refs/heads/main")
        self.assertTrue(published.startswith(self.seed))

    def test_already_published_history_is_not_a_local_audit(self):
        self.write("published.txt", TOKEN + "\n")
        self.git("add", "published.txt")
        self.commit()
        self.seed_remote()
        self.write("new.txt", "ordinary new content\n")
        self.git("add", "new.txt")
        self.commit()
        result = self.run_push()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("checked 1 outgoing commit", result.stderr)

    def test_commit_and_annotated_tag_messages(self):
        self.seed_remote()
        self.write("new.txt", "ordinary text\n")
        self.git("add", "new.txt")
        self.commit("test(secrets): " + TOKEN)
        self.assert_blocked(self.run_push(), "github-pat")
        self.git("tag", "-a", "synthetic-tag", self.seed, "-m", TOKEN)
        oid = self.git("rev-parse", "synthetic-tag")
        updates = f"refs/tags/synthetic-tag {oid} refs/tags/synthetic-tag {ZERO}\n"
        self.assert_blocked(self.run_push(updates), "github-pat")

    def test_merge_resolution_is_scanned(self):
        self.seed_remote()
        self.git("checkout", "-q", "-b", "side")
        self.write("side.txt", "side change\n")
        self.git("add", "side.txt")
        self.commit()
        self.git("checkout", "-q", "main")
        self.write("main.txt", "main change\n")
        self.git("add", "main.txt")
        self.commit()
        self.git("merge", "--no-ff", "--no-commit", "side")
        self.write("merge.txt", TOKEN + "\n")
        self.git("add", "merge.txt")
        self.commit("test(secrets): add synthetic merge resolution")
        self.assert_blocked(self.run_push(), "github-pat")

    def test_ciphertext_does_not_invoke_textconv(self):
        self.seed_remote()
        marker = self.base / "textconv-ran"
        driver = self.base / "textconv.py"
        driver.write_text(
            "from pathlib import Path\n" + f"Path({str(marker)!r}).touch()\n"
        )
        self.git("config", "diff.age.textconv", f"python3 {driver}")
        self.write(".gitattributes", "*.age diff=age\n")
        path = "private_dot_ssh/encrypted_private_config.age"
        self.write(
            path,
            "-----BEGIN AGE ENCRYPTED FILE-----\n"
            + "Y2lwaGVydGV4dA==\n"
            + "-----END AGE ENCRYPTED FILE-----\n",
        )
        self.git("add", ".gitattributes", path)
        self.assertEqual(self.run_staged().returncode, 0)
        self.commit()
        self.assertEqual(self.run_push().returncode, 0)
        self.assertFalse(marker.exists())

    def test_deleted_refs_do_not_scan_history(self):
        updates = f"refs/heads/main {ZERO} refs/heads/main {'a' * 40}\n"
        self.assertEqual(self.run_push(updates).returncode, 0)

    def test_shallow_and_unreachable_remote_fail_closed(self):
        self.seed_remote()
        self.assert_blocked(
            self.run_push(remote=self.base / "absent.git"), "Git could not prepare"
        )
        (self.repo / ".git/shallow").write_text(self.seed + "\n")
        self.assert_blocked(self.run_push(), "shallow clone")

    def test_non_commit_tag_fails_closed(self):
        self.seed_remote()
        blob = self.git("rev-parse", "HEAD:clean.txt")
        updates = f"refs/tags/blob-tag {blob} refs/tags/blob-tag {ZERO}\n"
        self.assert_blocked(self.run_push(updates), "resolve to commits")

    def test_missing_scanner_and_error_output_fail_closed(self):
        with (
            patch.object(check.Path, "home", return_value=self.base),
            patch.object(check.shutil, "which", return_value=None),
            self.assertRaisesRegex(check.Refused, "Gitleaks is missing"),
        ):
            check.scanner()
        fake = self.base / "broken-scanner"
        fake.write_text(
            "#!/usr/bin/env python3\nimport sys\n"
            + f"print({TOKEN!r}, file=sys.stderr)\nsys.exit(1)\n"
        )
        fake.chmod(0o755)
        output = io.StringIO()
        with (
            contextlib.redirect_stderr(output),
            self.assertRaisesRegex(check.Refused, "Gitleaks failed"),
        ):
            check.scan(
                str(fake), ROOT / ".gitleaks.toml", "synthetic error", message=b"test"
            )
        self.assertNotIn(TOKEN, output.getvalue())

    def test_catalog_pin_matches_hook(self):
        catalog = tomllib.loads((ROOT / ".chezmoidata/downloads.toml").read_text())
        self.assertEqual(catalog["downloads"]["gitleaks"]["tag"], "v" + check.VERSION)


if __name__ == "__main__":
    unittest.main(verbosity=2)
