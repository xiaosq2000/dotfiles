#!/usr/bin/env python3
"""Check optional Difftastic setup without changing the real Git config."""

from pathlib import Path
import os
import shutil
import subprocess
import tempfile


root = Path(__file__).resolve().parents[2]
git = shutil.which("git")
bash = shutil.which("bash")
chezmoi = shutil.which("chezmoi")
assert git and bash and chezmoi, "git, bash and chezmoi are required"
template = root / ".chezmoiscripts/run_onchange_after_09-git-difftastic.sh.tmpl"

with tempfile.TemporaryDirectory(prefix="git-difftastic-") as directory:
    home = Path(directory)
    config = home / "chezmoi.toml"
    config.write_text('[data]\nmachine = "container"\ntheme = "rose-pine"\n')
    script = home / "setup.sh"
    script.write_text(subprocess.check_output([
        chezmoi, "--source", str(root), "--config", str(config),
        "execute-template", "--file", str(template),
    ], text=True))

    binaries = home / "bin"
    binaries.mkdir()
    (binaries / "git").symlink_to(git)
    pixi_bin = home / "pixi/bin"
    pixi_bin.mkdir(parents=True)
    env = {key: value for key, value in os.environ.items()
           if not key.startswith("GIT_")}
    env.update(HOME=str(home), XDG_CONFIG_HOME=str(home / "config"),
               PIXI_HOME=str(home / "pixi"), PATH=str(binaries),
               GIT_CONFIG_GLOBAL=str(home / ".gitconfig"),
               GIT_CONFIG_NOSYSTEM="1")

    def setup():
        return subprocess.run([bash, str(script)], env=env, check=True,
                              text=True, capture_output=True)

    def git_config(*args):
        return subprocess.run([git, "config", "--global", *args], env=env,
                              text=True, capture_output=True)

    def get(key):
        return git_config("--get", key).stdout.strip()

    git_config("user.name", "Fixture User").check_returncode()
    git_config("core.pager", "less -R").check_returncode()
    original = (home / ".gitconfig").read_bytes()
    setup()
    assert (home / ".gitconfig").read_bytes() == original

    # A first apply can install difft into pixi without it on the inherited PATH.
    difft = pixi_bin / "difft"
    difft.write_text('#!/bin/sh\nprintf "difft-fixture\\n"\n')
    difft.chmod(0o755)
    setup()
    assert get("diff.external") == "difft"
    assert get("user.name") == "Fixture User"
    assert get("core.pager") == "less -R"
    enabled = (home / ".gitconfig").read_bytes()
    setup()
    assert (home / ".gitconfig").read_bytes() == enabled

    # Git actually invokes the external renderer, while the native override works.
    old, new = home / "old.txt", home / "new.txt"
    old.write_text("old\n")
    new.write_text("new\n")
    diff_env = dict(env, PATH=f"{pixi_bin}:{binaries}")
    diff_args = [git, "--no-pager", "diff", "--no-index"]
    output = subprocess.run([*diff_args, str(old), str(new)], env=diff_env,
                            text=True, capture_output=True)
    assert output.stdout == "difft-fixture\n", output
    native = subprocess.run([*diff_args, "--no-ext-diff", str(old), str(new)],
                            env=diff_env, text=True, capture_output=True)
    assert native.returncode == 1 and "@@" in native.stdout, native

    difft.unlink()
    setup()
    assert not get("diff.external")
    assert get("core.pager") == "less -R"
    git_config("diff.external", "another-diff").check_returncode()
    setup()
    assert get("diff.external") == "another-diff"
    git_config("--add", "diff.external", "difft").check_returncode()
    setup()
    assert git_config("--get-all", "diff.external").stdout == "another-diff\n"

    # A difft installed outside pixi also becomes the default.
    path_difft = binaries / "difft"
    path_difft.write_text("#!/bin/sh\nexit 0\n")
    path_difft.chmod(0o755)
    git_config("--add", "diff.external", "extra-diff").check_returncode()
    setup()
    assert git_config("--get-all", "diff.external").stdout == "difft\n"
    path_difft.unlink()
    setup()
    assert not get("diff.external")

    # An optional tool or a config write failure must not abort chezmoi apply.
    (binaries / "git").unlink()
    assert "git not found" in setup().stderr
    (binaries / "git").write_text("#!/bin/sh\nexit 1\n")
    (binaries / "git").chmod(0o755)
    difft.write_text("#!/bin/sh\nexit 0\n")
    difft.chmod(0o755)
    assert "could not enable difft" in setup().stderr

    # Exercise the actual chezmoi lifecycle, including verify after each apply.
    (binaries / "git").unlink()
    (binaries / "git").symlink_to(git)
    (binaries / "bash").symlink_to(bash)
    difft.unlink()
    source = home / "source"
    scripts = source / ".chezmoiscripts"
    scripts.mkdir(parents=True)
    shutil.copyfile(template, scripts / template.name)
    chezmoi_args = [chezmoi, "--source", str(source), "--destination", str(home),
                    "--config", str(config), "--cache", str(home / "cache"),
                    "--persistent-state", str(home / "state.boltdb"), "--no-tty"]

    def apply_and_verify():
        for command in ("apply", "verify"):
            result = subprocess.run(chezmoi_args + [command], env=env,
                                    text=True, capture_output=True)
            assert result.returncode == 0, (command, result.stdout, result.stderr)

    apply_and_verify()
    assert not get("diff.external")
    difft.write_text("#!/bin/sh\nexit 0\n")
    difft.chmod(0o755)
    apply_and_verify()
    assert get("diff.external") == "difft"
    difft.unlink()
    apply_and_verify()
    assert not get("diff.external")

print("ok       Difftastic setup: available, absent, native override, idempotent, non-fatal and verified")
