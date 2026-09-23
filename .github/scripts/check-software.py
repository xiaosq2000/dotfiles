#!/usr/bin/env python3
"""Exercise the real chezmoi lifecycle in a disposable home.

The default uses local archives shaped like the upstream downloads. --live
validates the current upstream assets separately, without installing Pixi tools
or touching a user's home. --keep retains the sandbox for inspection.
"""

import argparse
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import tomllib
import zipfile


ROOT = Path(__file__).resolve().parents[2]


def toml(data):
    # This test only serializes the catalog's scalars and arrays of tables.
    lines = []

    def table(obj, path, array=False):
        if path:
            brackets = ("[[", "]]") if array else ("[", "]")
            lines.append(brackets[0] + ".".join(json.dumps(p) for p in path) + brackets[1])
        for key, value in obj.items():
            if isinstance(value, dict) or (isinstance(value, list) and value and isinstance(value[0], dict)):
                continue
            lines.append(f"{json.dumps(key)} = {json.dumps(value, ensure_ascii=False)}")
        for key, value in obj.items():
            if isinstance(value, dict):
                table(value, path + [key])
            elif isinstance(value, list) and value and isinstance(value[0], dict):
                for item in value:
                    table(item, path + [key], True)

    table(data, [])
    return "\n".join(lines) + "\n"


def asset(directory, name, spec, version):
    script = f"#!/bin/sh\necho fixture-{version}\n".encode()
    if name == "kitty":
        files = {"bin/kitty": script, "bin/kitten": script,
                 "share/icons/hicolor/256x256/apps/kitty.png": b"icon"}
    elif name == "zotero":
        files = {"Zotero/zotero": script, "Zotero/icons/icon128.png": b"icon"}
    elif name == "tre":
        files = {"tre": script}
    elif spec["entries"][0]["type"] == "file":
        path = directory / (name + ".bin")
        path.write_bytes(f"fixture-{version}".encode())
        return path.as_uri()
    else:
        paths = {
            "fira": "Fira-master/otf/Fixture.otf",
            "libertinus": "Libertinus-version/static/OTF/Fixture.otf",
            "source-serif": "source-serif-version/OTF/Fixture.otf",
            "source-han-sans-sc": "OTF/SimplifiedChinese/Fixture.otf",
            "source-han-serif-cn": "SubsetOTF/CN/Fixture.otf",
            "san-francisco-pro": "Repo/Fixture.otf",
            "san-francisco-mono": "Repo/Fixture.otf",
            "new-york": "Repo/Fixture.otf", "pingfang": "Repo/Fixture.otf",
        }
        extension = "ttf" if name in {"maplemono-nf-cn-unhinted", "nerd-font-fira-code"} else "otf"
        files = {paths.get(name, "Fixture." + extension): f"fixture-{version}".encode(),
                 "README.md": b"not a font", "web/font.woff2": b"not a desktop font"}
    if name in {"kitty", "zotero", "tre"}:
        path = directory / (name + ".tar.xz")
        with tarfile.open(path, "w:xz") as archive:
            for filename, content in files.items():
                entry = tarfile.TarInfo(filename)
                entry.size = len(content)
                entry.mode = 0o755 if content.startswith(b"#!") else 0o644
                archive.addfile(entry, io.BytesIO(content))
    else:
        path = directory / (name + ".zip")
        with zipfile.ZipFile(path, "w") as archive:
            directories = sorted({str(parent) + "/" for name in files for parent in Path(name).parents if str(parent) != "."})
            for directory in directories:
                # Source Han archives omit the top-level parent directory.
                if name.startswith("source-han-") and directory.count("/") == 1:
                    continue
                archive.writestr(directory, b"")
            for filename, content in files.items():
                archive.writestr(filename, content)
    return path.as_uri()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--cache", type=Path, help="reuse downloads and release metadata across serial live checks")
    args = parser.parse_args()
    base = Path(tempfile.mkdtemp(prefix="chezmoi-software-"))
    print(f"Software test sandbox: {base}", flush=True)
    src, home = base / "source", base / "home"
    src.mkdir()
    home.mkdir()
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
               XDG_DATA_HOME=str(home / ".local/share"), XDG_STATE_HOME=str(home / ".local/state"),
               XDG_CACHE_HOME=str(base / "cache"))
    chezmoi = shutil.which("chezmoi")
    if not chezmoi:
        raise SystemExit("chezmoi is required")
    for name in [".chezmoidata", ".chezmoitemplates", ".chezmoiexternals", "dot_local", "dot_pixi", "private_dot_config"]:
        shutil.copytree(ROOT / name, src / name)
    for name in [".chezmoiignore", ".chezmoiremove"]:
        shutil.copy2(ROOT / name, src / name)
    (src / ".chezmoiscripts").mkdir()
    for name in ["run_before_01-adopt-downloads.py.tmpl", "run_after_90-downloads.py.tmpl"]:
        shutil.copy2(ROOT / ".chezmoiscripts" / name, src / ".chezmoiscripts" / name)
    # Render theme URLs separately so lifecycle fixtures need no network.
    theme_template = base / "themes.toml.tmpl"
    (src / ".chezmoiexternals/themes-and-plugins.toml.tmpl").rename(theme_template)
    config = base / "config.toml"
    config.write_text('umask = 0o022\n[gitHub]\nrefreshPeriod = "24h"\n[data]\nmachine = "container"\ntheme = "rose-pine"\n')
    state = args.cache / "software-check.boltdb" if args.cache else base / "state.boltdb"
    command = [chezmoi, "--source", str(src), "--destination", str(home), "--config", str(config),
               "--cache", str(args.cache or base / "cache"), "--persistent-state", str(state), "--no-tty"]
    catalog = tomllib.loads((src / ".chezmoidata/downloads.toml").read_text())
    downloads = catalog["downloads"]
    tools = tomllib.loads((src / ".chezmoidata/tools.toml").read_text())
    assets = base / "assets"
    assets.mkdir()
    if not args.live:
        for name, spec in downloads.items():
            spec.pop("repo", None)
            spec.pop("asset", None)
            spec.pop("releaseFile", None)
            spec["url"] = asset(assets, name, spec, 1)
        (src / ".chezmoidata/downloads.toml").write_text(toml(catalog))
        stubs = base / "bin"
        stubs.mkdir()
        for binary in ["fc-cache", "update-desktop-database"]:
            path = stubs / binary
            path.write_text('#!/bin/sh\nprintf "%s\\n" "$0" >> "$HOME/cache-calls"\n')
            path.chmod(0o755)
        env["PATH"] = str(stubs) + os.pathsep + env["PATH"]

    def run(*arguments, bundles=(), check=True):
        override = json.dumps({"machines": {"container": {"bundles": list(bundles)}}})
        result = subprocess.run(command + ["--override-data", override, *arguments], env=env,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                timeout=600 if args.live else 60)
        if check and result.returncode:
            raise RuntimeError(" ".join(arguments) + "\n" + result.stdout + result.stderr)
        return result

    def apply(bundles, refresh=False):
        if args.live:
            print("Applying live resources: " + ", ".join(bundles), flush=True)
        result = run("apply", "--force", *(["--refresh-externals"] if refresh else []), bundles=bundles)
        if result.stdout:
            print(result.stdout, end="", flush=True)
        run("verify", "--exclude", "scripts", bundles=bundles)

    try:
        # Resolve all seven real profiles, independently of download endpoints.
        machines = tomllib.loads((src / ".chezmoidata/machines.toml").read_text())["machines"]
        for machine in machines:
            result = subprocess.run(command + ["--override-data", json.dumps({"machine": machine}),
                                    "execute-template", '{{ includeTemplate "software-selection" . }}'],
                                    env=env, text=True, capture_output=True, check=True)
            resolved = json.loads(result.stdout)
            assert ("kitty" in resolved["externals"]) == (machine in {"laptop", "workstation"})
        assert run("execute-template", '{{ includeTemplate "software-selection" . }}',
                   bundles=["missing"], check=False).returncode != 0
        unsupported = run("execute-template", '{{ $_ := set .chezmoi "arch" "arm64" }}{{ includeTemplate "software-selection" . }}',
                          bundles=["desktop"], check=False)
        assert unsupported.returncode and "does not support linux-arm64" in unsupported.stderr
        # An inactive resource must leave a manual install alone.
        manual = home / ".local/bin/kitty"
        manual.parent.mkdir(parents=True)
        manual.write_text("unmanaged kitty\n")
        unrelated = home / ".local/share/fonts/unrelated/font.ttf"
        unrelated.parent.mkdir(parents=True)
        unrelated.write_text("unmanaged font\n")
        alternate = home / ".local/share/fonts/noto-color-emoji/NotoColorEmoji_WindowsCompatible.ttf"
        alternate.parent.mkdir(parents=True)
        alternate.write_text("old alternate build\n")
        apply([])
        assert manual.read_text() == "unmanaged kitty\n"
        assert not (home / ".config/kitty").exists()
        assert not (home / ".local/kitty.app").exists()
        bundles = ["core", "extras", "desktop", "fonts", "research"]
        if not args.live:
            original_url = downloads["fira"]["url"]
            downloads["fira"]["url"] = (base / "missing.zip").as_uri()
            (src / ".chezmoidata/downloads.toml").write_text(toml(catalog))
            assert run("apply", "--force", bundles=bundles, check=False).returncode
            assert manual.read_text() == "unmanaged kitty\n"
            assert not (home / ".local/state/dotfiles/downloads/kitty.json").exists()
            downloads["fira"]["url"] = original_url
            (src / ".chezmoidata/downloads.toml").write_text(toml(catalog))
        apply(bundles)
        assert manual.is_symlink()
        assert not alternate.exists()
        assert (home / ".local/state/dotfiles/backups/noto-color-emoji/.local/share/fonts/noto-color-emoji/NotoColorEmoji_WindowsCompatible.ttf").read_text() == "old alternate build\n"
        assert (home / ".local/state/dotfiles/backups/kitty/.local/bin/kitty").read_text() == "unmanaged kitty\n"
        config_text = (home / ".config/kitty/kitty.conf").read_text()
        assert 'family="Maple Mono NF CN"' in config_text
        assert 'family = "Maple Mono NF CN"' in (home / ".config/alacritty/alacritty.toml").read_text()
        assert "cursor_trail 1" in config_text
        assert "custom_shaders cursor-trail-blaze focus-highlight-only" in config_text
        assert f"exe_search_path {home}/.local/bin" in config_text
        pipeline = (home / ".config/kitty/shaders/focus-highlight-only.pipeline").read_text()
        for setting in ["    var float INACTIVE_DIM = 1.0", "    animation_start window-focus-in", "    animation_stop 750"]:
            assert setting in pipeline.splitlines()
        ssh_config = (home / ".config/kitty/ssh.conf").read_text()
        assert "hostname sicc" in ssh_config.splitlines()
        assert "login_shell $HOME/.pixi/bin/zsh" in ssh_config
        assert "env SHELL=$HOME/.pixi/bin/zsh" in ssh_config
        assert "/home/" not in ssh_config
        policy = json.loads((home / ".local/zotero/distribution/policies.json").read_text())
        assert policy["policies"]["DisableAppUpdate"] is True
        for name, spec in downloads.items():
            for entry in spec["entries"]:
                target = home / entry["target"]
                assert target.exists(), (name, target)
                if spec["kind"] == "font":
                    fonts = [target] if target.is_file() else [p for p in target.rglob("*") if p.is_file()]
                    assert fonts and all(p.suffix.lower() in {".ttf", ".otf"} for p in fonts), (name, fonts)
                    if args.live:
                        for font in fonts:
                            subprocess.run(["fc-scan", "--format", "%{family}\n", str(font)],
                                           env=env, stdout=subprocess.DEVNULL, check=True)
        for name in ["kitty", "zotero"]:
            if shutil.which("desktop-file-validate"):
                subprocess.run(["desktop-file-validate", str(home / f".local/share/applications/{name}.desktop")], check=True)
        if args.live:
            for name in ["kitty", "kitten", "tre", "zotero"]:
                result = subprocess.run([str(home / ".local/bin" / name), "--version"], env=dict(env, MOZ_HEADLESS="1"),
                                        text=True, capture_output=True, check=True)
                print(result.stdout.strip())
            match = subprocess.check_output(["fc-match", "-f", "%{family}\n%{file}\n", "Maple Mono NF CN"],
                                            env=env, text=True).splitlines()
            assert match[0] == "Maple Mono NF CN" and match[1].startswith(str(home)), match
            for zsh in {shutil.which("zsh"), "/usr/bin/zsh"}:
                if zsh and Path(zsh).exists():
                    subprocess.run([zsh, "-fc", "zmodload zsh/terminfo; (( ${+terminfo[cuu1]} ))"],
                                   env=dict(env, TERM="xterm-kitty"), check=True)
        # A second apply preserves both payloads and the original adoption backup.
        apply(bundles)
        if not args.live:
            # Cache tools are optional even when font payloads are selected.
            old_path = env["PATH"]
            (stubs / "python3").symlink_to(shutil.which("python3"))
            (stubs / "fc-cache").unlink()
            env["PATH"] = str(stubs)
            apply(bundles)
            env["PATH"] = old_path
            policy_source = src / ".chezmoitemplates/zotero-policy.json"
            policy_source.write_text(policy_source.read_text() + "\n")
            apply(bundles)
            assert (home / ".local/zotero/distribution/policies.json").read_text() == policy_source.read_text()
            stale = home / ".local/share/fonts/fira/obsolete.otf"
            stale.write_text("old")
            downloads["fira"]["url"] = asset(assets, "fira", downloads["fira"], 2)
            apply(bundles, refresh=True)
            assert not stale.exists()
            assert (home / ".local/share/fonts/fira/Fixture.otf").read_text() == "fixture-2"
        # Removing fonts leaves the terminal font; removing desktop leaves terminfo.
        library = home / "Zotero/storage/keep.pdf"
        library.parent.mkdir(parents=True)
        library.write_text("user document")
        apply(["core", "desktop", "extras", "research"])
        assert not (home / ".local/share/fonts/fira").exists()
        assert (home / ".local/share/fonts/maplemono-nf-cn-unhinted").exists()
        apply(["core"])
        assert not os.path.lexists(manual)
        assert not (home / ".local/kitty.app").exists()
        assert not (home / ".local/zotero").exists()
        assert not (home / ".local/bin/tre").exists()
        assert (home / ".terminfo/78/xterm-kitty").exists()
        assert (home / ".terminfo/x/xterm-kitty").exists()
        assert unrelated.read_text() == "unmanaged font\n"
        assert library.read_text() == "user document"
        # User configuration survives removal, while launchers and fonts do not.
        assert (home / ".config/kitty/kitty.conf").exists()
        assert not (home / ".local/share/applications/kitty.desktop").exists()
        apply(bundles)
        assert manual.is_symlink()
        assert library.exists()
        # GUI templates still render every theme when desktop is enabled.
        for theme in ["rose-pine", "rose-pine-dawn", "catppuccin-mocha"]:
            override = {"machine": "workstation", "theme": theme}
            result = subprocess.run(command + ["--override-data", json.dumps(override), "execute-template",
                                    "--file", str(src / "private_dot_config/zathura/zathurarc.tmpl")],
                                    env=env, text=True, capture_output=True, check=True)
            assert f"include {theme}" in result.stdout
            for machine in ["workstation", "container"]:
                result = subprocess.run(command + ["--override-data", json.dumps({"machine": machine, "theme": theme}),
                                        "execute-template", "--file", str(theme_template)],
                                        env=env, text=True, capture_output=True, check=True)
                externals = tomllib.loads(result.stdout)
                for target in [".config/kitty/current-theme.conf", ".config/alacritty/current-theme.toml"]:
                    assert (target in externals) == (machine == "workstation")
                assert ".config/btop/themes/current.theme" in externals
        print("Software lifecycle checks passed.")
    except BaseException:
        print(f"Failure sandbox retained at {base}", flush=True)
        raise
    else:
        if not args.keep:
            shutil.rmtree(base)


if __name__ == "__main__":
    main()
