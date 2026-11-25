#!/usr/bin/env python3
"""Exercise dotfiles-fetch in a disposable home.

By default every download in .chezmoidata/downloads.toml is replaced by a small
local fixture shaped like its upstream, and GitHub's release API is served from
files, so the run needs no network and takes seconds. It covers installing,
an offline sync, updating, a catalog change, deselecting, a failed download,
an unsupported platform and the terminfo copies.

--live installs the real catalog from the real upstreams instead and checks
that the commands run and the fonts parse. It downloads a few gigabytes.
--keep leaves the sandbox in place for inspection.
"""

import argparse
import hashlib
import http.server
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import threading
import tomllib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FETCH = ROOT / "dot_local/libexec/dotfiles/executable_dotfiles-fetch"


class Releases(http.server.BaseHTTPRequestHandler):
    """Serves release assets the way GitHub does: /download/<path> redirects
    to an object URL whose name has nothing to do with the asset's."""

    def do_GET(self):
        root = self.server.root
        if self.path.startswith("/download/"):
            name = hashlib.sha256(self.path.encode()).hexdigest()
            self.server.objects[name] = root / self.path[len("/download/"):]
            self.send_response(302)
            self.send_header("Location", f"/objects/{name}?signature=fixture")
            self.end_headers()
            return
        path = self.server.objects.get(self.path.split("?")[0][len("/objects/"):])
        if path is None or not path.is_file():
            self.send_error(404)
            return
        data = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *arguments):
        pass


class Sandbox:
    def __init__(self, base, live):
        self.base = base
        self.home = base / "home"
        self.home.mkdir()
        self.stubs = base / "stubs"
        self.stubs.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), GITHUB_TOKEN=os.environ.get("GITHUB_TOKEN", "fixture"))
        if not live:
            self.env["DOTFILES_FETCH_GITHUB_API"] = (base / "api").as_uri()
            self.env["DOTFILES_FETCH_GITHUB_RAW"] = (base / "raw").as_uri()
            # Record cache refreshes instead of running them.
            for program in ["fc-cache", "update-desktop-database"]:
                stub = self.stubs / program
                stub.write_text(f'#!/bin/sh\necho {program} >> "$HOME/refreshes"\n')
                stub.chmod(0o755)
            self.env["PATH"] = f"{self.stubs}{os.pathsep}{os.environ['PATH']}"
            self.env["NO_PROXY"] = self.env["no_proxy"] = "127.0.0.1"
            server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Releases)
            server.root, server.objects = base, {}
            threading.Thread(target=server.serve_forever, daemon=True).start()
            self.releases = f"http://127.0.0.1:{server.server_address[1]}/download"

    def fetch(self, *arguments, manifest=None, check=True):
        if manifest is not None:
            path = self.home / ".config/dotfiles/downloads.json"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(manifest, indent=2))
        result = subprocess.run([sys.executable, str(FETCH), *arguments], env=self.env,
                                text=True, capture_output=True, timeout=3600)
        print(result.stdout + result.stderr, end="", flush=True)
        if check and result.returncode:
            raise AssertionError(f"dotfiles-fetch {' '.join(arguments)} exited {result.returncode}")
        return result

    def refreshes(self):
        path = self.home / "refreshes"
        calls = path.read_text().split() if path.exists() else []
        path.unlink(missing_ok=True)
        return calls

    def lock(self):
        return json.loads((self.home / ".local/state/dotfiles/downloads.lock.json").read_text())["resources"]


# --------------------------------------------------------------------------
# Fixtures


def script(text):
    return f"#!/bin/sh\necho {text}\n".encode()


def tar(path, files, compression):
    with tarfile.open(path, f"w:{compression}") as archive:
        for name, content in files.items():
            member = tarfile.TarInfo(name)
            member.size = len(content)
            member.mode = 0o755 if content.startswith(b"#!") else 0o644
            archive.addfile(member, io.BytesIO(content))


def zip_(path, files):
    with zipfile.ZipFile(path, "w") as archive:
        for name, content in files.items():
            archive.writestr(name, content)


# Font archives whose layout the catalog's globs depend on. The first member of
# each is the only one the catalog installs; the rest are upstream's other
# formats, which must stay out.
FONT_ARCHIVES = {
    "inter": ["extras/otf/Inter-Regular.otf", "extras/ttf/Inter-Regular.ttf", "InterVariable.ttf"],
    "jetbrains-mono": ["fonts/ttf/JetBrainsMono-Regular.ttf", "fonts/ttf/JetBrainsMonoNL-Regular.ttf",
                       "fonts/variable/JetBrainsMono[wght].ttf"],
    "newsreader": ["Newsreader-master/fonts/static/ttf/Newsreader72pt-Regular.ttf",
                   "Newsreader-master/fonts/variable/ttf/Newsreader[opsz,wght].ttf"],
    "noto-sans-math": ["NotoSansMath/hinted/ttf/NotoSansMath-Regular.ttf",
                       "NotoSansMath/unhinted/ttf/NotoSansMath-Regular.ttf",
                       "NotoSansMath/full/otf/NotoSansMath-Regular.otf"],
}


def payload(identifier, spec, version, directory):
    """Write a download shaped like identifier's upstream, named the way the
    catalog's asset pattern expects, and return its path. A URL download gets
    no extension at all, as Zotero's redirect does, so the format has to come
    from the bytes."""
    directory.mkdir(parents=True, exist_ok=True)
    pattern = spec.get("asset") or spec.get("file")
    if isinstance(pattern, dict):
        pattern = pattern["linux-amd64"]
    path = directory / (Path(pattern).name.replace("*", version) if pattern else f"{identifier}-{version}")
    if identifier == "kitty":
        tar(path, {"bin/kitty": script(f"kitty {version}"), "bin/kitten": script(f"kitten {version}"),
                   "lib/kitty/terminfo/x/xterm-kitty": f"terminfo {version}".encode(),
                   "share/icons/hicolor/256x256/apps/kitty.png": b"icon"}, "xz")
    elif identifier == "zotero":
        tar(path, {"Zotero_linux-x86_64/zotero": script(f"zotero {version}"),
                   "Zotero_linux-x86_64/icons/icon128.png": b"icon"}, "xz")
    elif identifier == "agy":
        tar(path, {"antigravity": script(f"agy {version}")}, "gz")
    elif spec.get("extract") is False:
        zip_(path, {"manifest.json": json.dumps({"version": version}).encode()})
    elif path.suffix == ".ttf":
        path.write_bytes(f"{identifier} {version}".encode())
    elif identifier in FONT_ARCHIVES:
        zip_(path, {name: f"{identifier} {version}".encode() for name in FONT_ARCHIVES[identifier]})
    else:
        zip_(path, {"Family/otf/Fixture.otf": f"{identifier} {version}".encode(),
                    "Family/ttf/Fixture.ttf": f"{identifier} {version}".encode(),
                    "Family/README.md": b"not a font", "Family/woff2/Fixture.woff2": b"web"})
    return path


def publish(box, identifier, spec, version):
    """Serve version of identifier where its spec will look for it. Returns
    the spec to put in the manifest: a URL download points at the fixture, and
    a GitHub one is unchanged, since the fixture API answers for it."""
    base = box.base
    spec = dict(spec)
    path = payload(identifier, spec, version, base / "assets" / identifier / version)
    if "manifest" in spec:
        sha512 = hashlib.sha512(path.read_bytes()).hexdigest()
        url = f"{box.releases}/{path.relative_to(base).as_posix()}"
        manifest = base / "manifests" / identifier / "latest.json"
        manifest.parent.mkdir(parents=True, exist_ok=True)
        manifest.write_text(json.dumps({"version": version, "url": url, "sha512": sha512}))
        spec["manifest"] = {platform: manifest.as_uri() for platform in spec["manifest"]}
        return spec
    if "github" not in spec:
        spec["url"] = path.as_uri()
        return spec
    tag = f"v{version}"
    release = base / "api/repos" / spec["github"] / "releases/latest"
    release.parent.mkdir(parents=True, exist_ok=True)
    assets = []
    if "file" in spec:
        raw = base / "raw" / spec["github"] / tag / spec["file"]
        raw.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, raw)
    else:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        url = f"{box.releases}/{path.relative_to(base).as_posix()}"
        assets.append({"name": path.name, "browser_download_url": url, "digest": f"sha256:{digest}"})
        if "sha256" in spec:
            spec["sha256"] = digest
    data = json.dumps({"tag_name": tag, "assets": assets})
    release.write_text(data)
    tagged = release.parent / "tags" / tag
    tagged.parent.mkdir(parents=True, exist_ok=True)
    tagged.write_text(data)
    return spec


# --------------------------------------------------------------------------
# Checks


def fixtures(box, catalog):
    home = box.home
    store, fonts = home / ".local/opt/dotfiles", home / ".local/share/fonts/dotfiles"
    resources = {i: publish(box, i, dict(s, tag="v1") if "tag" in s else s, "1")
                 for i, s in catalog.items()}
    # Standard proxy env inheritance: NO_PROXY=127.0.0.1 bypasses HTTP_PROXY for
    # the local fixture server while keeping proxy handling standard.
    box.env["NO_PROXY"] = box.env["no_proxy"] = "127.0.0.1"
    for key in ("HTTP_PROXY", "HTTPS_PROXY", "http_proxy", "https_proxy"):
        box.env[key] = "http://127.0.0.1:1"
    everything = {"platform": "linux-amd64", "resources": resources}

    # Installations made some other way, which must never be touched.
    manual = {
        home / ".local/bin/kitty": "manual kitty\n",
        home / ".local/bin/pi": "manual pi\n",
        home / ".local/bin/rtk": "manual rtk\n",
        home / ".local/bin/agy": "manual agy\n",
        home / ".pi/agent/settings.json": '{"theme":"custom"}\n',
        home / ".pi/agent/sessions/fixture.jsonl": "local session\n",
        home / ".local/share/fonts/fira/Fira.otf": "manual font\n",
        home / ".local/share/applications/kitty.desktop": "manual launcher\n",
        home / ".terminfo/x/xterm-kitty": "terminfo written by kitten ssh\n",
    }
    for path, content in manual.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    # What an interrupted run leaves behind is cleared by the next one.
    for leftover in [store / ".scratch-interrupted/download-x", fonts / ".fira.new/Fixture.otf"]:
        leftover.parent.mkdir(parents=True)
        leftover.write_text("partial")

    # A failed download installs the rest and exits 1 for a retry.
    broken = dict(everything, resources=dict(resources, fira=dict(resources["fira"], url=(box.base / "missing.zip").as_uri())))
    assert box.fetch("sync", manifest=broken, check=False).returncode == 1
    assert "fira" not in box.lock() and "kitty" in box.lock()
    assert not (store / ".scratch-interrupted").exists() and not (fonts / ".fira.new").exists()

    box.fetch("sync", manifest=everything)
    lock = box.lock()
    assert set(lock) == set(catalog), set(catalog) ^ set(lock)
    # Existing unpinned locks retain their source fingerprints after this change.
    for identifier, spec in resources.items():
        if "tag" not in spec and "manifest" not in spec:
            legacy = hashlib.sha256(json.dumps([spec.get(k) for k in ("github", "asset", "file", "url")],
                                               sort_keys=True).encode()).hexdigest()
            assert lock[identifier]["source"] == legacy, identifier
    for command in ["kitty", "kitten", "zotero", "agy"]:
        output = subprocess.run([str(store / "bin" / command)], capture_output=True, text=True, check=True).stdout
        assert output == f"{command} 1\n", (command, output)
    assert json.loads((store / "zotero/current/distribution/policies.json").read_text()) == {"policies": {"DisableAppUpdate": True}}
    # XPI is a zip package, but Zotero needs the archive itself.
    for xpi_id, spec in catalog.items():
        if spec.get("extract") is False and spec.get("filename", "").endswith(".xpi"):
            filename = spec["filename"]
            plugin = store / xpi_id / "current" / filename
            with zipfile.ZipFile(plugin) as package:
                assert json.loads(package.read("manifest.json"))["version"] == "1"
            assert sorted(path.name for path in plugin.parent.iterdir()) == [filename]
    plugin = store / "better-bibtex/current/better-bibtex.xpi"
    for identifier, spec in catalog.items():
        if "fonts" in spec:
            installed = sorted(p.name for p in (fonts / identifier).iterdir())
            assert len(installed) == 1 and installed[0].endswith((".otf", ".ttf")), (identifier, installed)
    assert (home / ".terminfo/78/xterm-kitty").read_text() == "terminfo 1"
    assert "fc-cache" in box.refreshes()

    # Offline, a sync of what is installed needs nothing, and only puts back
    # a terminfo copy that was deleted.
    shutil.move(box.base / "api", box.base / "api-offline")
    shutil.move(box.base / "assets", box.base / "assets-offline")
    (home / ".terminfo/78/xterm-kitty").unlink()
    box.fetch("sync")
    assert box.refreshes() == []
    assert (home / ".terminfo/78/xterm-kitty").read_text() == "terminfo 1"
    box.fetch("status")

    # A catalog change reinstalls from the locked download, still offline for
    # the API: a release asset is immutable, so the lock is enough.
    shutil.move(box.base / "assets-offline", box.base / "assets")
    # A corrupted raw package is detected and restored from the locked asset.
    plugin.write_bytes(b"damaged")
    assert "missing files" in box.fetch("status").stdout
    box.fetch("sync")
    with zipfile.ZipFile(plugin) as package:
        assert json.loads(package.read("manifest.json"))["version"] == "1"
    changed = dict(everything, resources=dict(resources, **{"maple-mono": dict(resources["maple-mono"], fonts=["*"])}))
    box.fetch("sync", manifest=changed)
    assert (fonts / "maple-mono/Fixture.ttf").exists() and (fonts / "maple-mono/README.md").exists()
    shutil.move(box.base / "api-offline", box.base / "api")
    box.fetch("sync", manifest=everything)

    # The slide typefaces install their static files and nothing else.
    for identifier, members in FONT_ARCHIVES.items():
        assert sorted(p.name for p in (fonts / identifier).iterdir()) == [Path(members[0]).name], identifier

    # Update moves kitty to a new release and keeps one previous version. The
    # terminfo copy follows it into 78, which it wrote, but not into x, which
    # kitten ssh wrote before it.
    for version in ["2", "3"]:
        resources["kitty"] = publish(box, "kitty", catalog["kitty"], version)
        assert "kitty" in box.fetch("outdated").stdout
        box.fetch("update", "kitty", manifest=everything)
        assert subprocess.run([str(store / "bin/kitty")], capture_output=True, text=True).stdout == f"kitty {version}\n"
    assert sorted(p.name for p in (store / "kitty").iterdir()) == ["current", "v2", "v3"]
    assert (home / ".terminfo/78/xterm-kitty").read_text() == "terminfo 3"

    # A rolling URL whose bytes did not change is left alone by update; one
    # whose bytes did is reinstalled without the files it no longer has.
    box.refreshes()
    box.fetch("update", "pingfang")
    assert box.refreshes() == [], "an unchanged download was reinstalled"
    (fonts / "fira/Stale.otf").write_text("stale")
    zip_(Path(resources["fira"]["url"][len("file://"):]), {"Family/otf/New.otf": b"fira 2"})
    box.fetch("update", "fira")
    assert sorted(p.name for p in (fonts / "fira").iterdir()) == ["New.otf"]

    # A manifest-backed release follows outdated/update and verifies sha512.
    resources["agy"] = publish(box, "agy", catalog["agy"], "2")
    assert "agy" in box.fetch("outdated").stdout
    box.fetch("update", "agy", manifest=everything)
    assert box.lock()["agy"]["version"] == "2"
    assert subprocess.run([str(store / "bin/agy")], capture_output=True, text=True, check=True).stdout == "agy 2\n"

    # Catalog pins win over the latest release, including explicit update.
    pinned_ids = ("better-bibtex", "extra-meta")
    v1_specs = {i: publish(box, i, dict(catalog[i], tag="v1"), "1") for i in pinned_ids}
    pinned_v1 = dict(everything, resources=dict(resources, **v1_specs))
    box.fetch("sync", manifest=pinned_v1)
    v2_specs = {i: publish(box, i, dict(catalog[i], tag="v2"), "2") for i in pinned_ids}
    newer = box.fetch("outdated", manifest=pinned_v1).stdout
    assert "catalog pin: v1" in newer
    box.fetch("update", *pinned_ids)
    assert all(box.lock()[i]["version"] == "v1" for i in pinned_ids)
    plugin.unlink()
    box.fetch("sync")
    assert plugin.is_file() and box.lock()["better-bibtex"]["version"] == "v1"

    # Changing a catalog pin upgrades on sync. Restoring it rolls back.
    for tag, specs in (("v2", v2_specs), ("v1", v1_specs)):
        pinned = dict(everything, resources=dict(resources, **specs))
        assert "catalog changed" in box.fetch("status", manifest=pinned).stdout
        box.fetch("sync")
        assert all(box.lock()[i]["version"] == tag for i in pinned_ids)
        assert (store / "better-bibtex/v1").exists() and (store / "better-bibtex/v2").exists()

    # A nonexistent pin fails without moving or deleting the installed version.
    missing = dict(everything, resources=dict(resources, **{"better-bibtex": dict(v1_specs["better-bibtex"], tag="v404")}))
    assert box.fetch("sync", manifest=missing, check=False).returncode == 1
    assert box.lock()["better-bibtex"]["version"] == "v1" and plugin.is_file()

    # A tag endpoint that answers with another release is refused.
    tagged = box.base / "api/repos" / resources["better-bibtex"]["github"] / "releases/tags/v404"
    tagged.write_text((tagged.parent / "v2").read_text())
    assert "requested tag" in box.fetch("sync", check=False).stderr
    assert box.lock()["better-bibtex"]["version"] == "v1"

    # Empty font directories are treated as missing files and reinstalled.
    for font_file in (fonts / "fira").iterdir():
        font_file.unlink()
    assert "missing files" in box.fetch("status", manifest=pinned_v1).stdout
    box.fetch("sync")
    assert any((fonts / "fira").iterdir())

    # Interrupted swap recovery restores a surviving .old directory when the target is absent.
    shutil.move(store / "better-bibtex/v1", store / "better-bibtex/.v1.old")
    assert not (store / "better-bibtex/v1").exists()
    box.fetch("sync")
    assert (store / "better-bibtex/v1").is_dir() and not (store / "better-bibtex/.v1.old").exists()

    # Deselecting removes everything a download installed, and nothing else.
    core = dict(everything, resources={"zotero": resources["zotero"]})
    box.fetch("sync", manifest=core)
    assert sorted(p.name for p in store.iterdir() if not p.name.startswith(".")) == ["bin", "zotero"]
    assert sorted(p.name for p in (store / "bin").iterdir()) == ["zotero"]
    assert not fonts.exists() or not any(fonts.iterdir())
    assert not (home / ".terminfo/78/xterm-kitty").exists()
    for path, content in manual.items():
        assert path.read_text() == content, path
    assert "fc-cache" in box.refreshes()

    # An entry with no download for this platform is skipped, not an error.
    assert "no download for darwin-arm64" in box.fetch(
        "sync", manifest=dict(core, platform="darwin-arm64", resources={"kitty": resources["kitty"]})
    ).stderr
    assert not (store / "kitty").exists() and not (store / "zotero").exists()

    # A release asset whose bytes differ from its published digest is refused.
    tampered = publish(box, "kitty", catalog["kitty"], "4")
    (box.base / "assets/kitty/4/kitty-4-x86_64.txz").write_bytes(b"tampered")
    assert box.fetch("sync", manifest=dict(core, resources={"kitty": tampered}), check=False).returncode == 1

    # A committed catalog sha256 mismatch is refused even when the GitHub API digest matches.
    wrong_pin = dict(v2_specs["better-bibtex"], sha256="0" * 64)
    result = box.fetch("sync", manifest=dict(core, resources={"better-bibtex": wrong_pin}), check=False)
    assert result.returncode == 1 and "expected catalog" in result.stderr

    # A pinned release with no catalog or API digest fails closed.
    no_digest_spec = {k: v for k, v in v2_specs["extra-meta"].items() if k != "sha256"}
    tag_file = box.base / "api/repos" / no_digest_spec["github"] / "releases/tags/v2"
    tag_payload = json.loads(tag_file.read_text())
    tag_payload["assets"][0].pop("digest", None)
    tag_file.write_text(json.dumps(tag_payload))
    result = box.fetch("sync", manifest=dict(core, resources={"extra-meta": no_digest_spec}), check=False)
    assert result.returncode == 1 and "no digest to verify" in result.stderr

    # A manifest release whose sha512 differs from the downloaded archive is refused.
    bad_manifest = publish(box, "agy", catalog["agy"], "3")
    (box.base / "assets/agy/3/agy-3").write_bytes(b"tampered")
    assert box.fetch("sync", manifest=dict(core, resources={"agy": bad_manifest}), check=False).returncode == 1

    # Unsafe version names from a release manifest are refused before touching the store.
    for bad_version in ("..", "current", ".hidden"):
        evil = publish(box, "agy", catalog["agy"], "9")
        manifest_path = Path(evil["manifest"]["linux-amd64"][len("file://"):])
        manifest_data = json.loads(manifest_path.read_text())
        manifest_data["version"] = bad_version
        manifest_path.write_text(json.dumps(manifest_data))
        result = box.fetch("sync", manifest=dict(core, resources={"agy": evil}), check=False)
        assert result.returncode == 1 and "unsafe version name" in result.stderr, bad_version


def live(box, catalog):
    store, fonts = box.home / ".local/opt/dotfiles", box.home / ".local/share/fonts/dotfiles"
    box.fetch("sync", manifest={"platform": "linux-amd64", "resources": catalog})
    box.fetch("status")
    for command in ["kitty", "kitten", "zotero", "agy"]:
        result = subprocess.run([str(store / "bin" / command), "--version"], env=dict(box.env, MOZ_HEADLESS="1"),
                                capture_output=True, text=True, check=True)
        print(result.stdout.strip())
    for identifier, spec in catalog.items():
        if "fonts" in spec:
            files = list((fonts / identifier).iterdir())
            assert files, identifier
            if shutil.which("fc-scan"):
                for font in files:
                    subprocess.run(["fc-scan", "--format", "%{family}\n", str(font)], env=box.env,
                                   stdout=subprocess.DEVNULL, check=True)
    if shutil.which("fc-match"):
        family = tomllib.loads((ROOT / ".chezmoidata/downloads.toml").read_text())["typography"]["terminalFamily"]
        match = subprocess.check_output(["fc-match", "-f", "%{family}\n%{file}\n", family], env=box.env, text=True).splitlines()
        assert match[0] == family and match[1].startswith(str(fonts)), match
    if shutil.which("zsh"):
        subprocess.run(["zsh", "-fc", "zmodload zsh/terminfo; (( ${+terminfo[cuu1]} ))"],
                       env=dict(box.env, TERM="xterm-kitty"), check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--keep", action="store_true")
    arguments = parser.parse_args()
    catalog = tomllib.loads((ROOT / ".chezmoidata/downloads.toml").read_text())["downloads"]
    base = Path(tempfile.mkdtemp(prefix="dotfiles-fetch-"))
    print(f"sandbox: {base}", flush=True)
    try:
        (live if arguments.live else fixtures)(Sandbox(base, arguments.live), catalog)
    except BaseException:
        print(f"failed; sandbox kept at {base}", flush=True)
        raise
    if not arguments.keep:
        shutil.rmtree(base)
    print("dotfiles-fetch checks passed")


if __name__ == "__main__":
    main()
