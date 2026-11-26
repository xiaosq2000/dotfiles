#!/usr/bin/env python3
"""Offline unit and end-to-end stub tests for `zotero-pmlr`."""

import sys

sys.dont_write_bytecode = True

import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "dot_local/bin/executable_zotero-pmlr"

loader = importlib.machinery.SourceFileLoader("zotero_pmlr", str(SCRIPT))
spec = importlib.util.spec_from_loader("zotero_pmlr", loader)
mod = importlib.util.module_from_spec(spec)
sys.modules["zotero_pmlr"] = mod
loader.exec_module(mod)

SAMPLE_HTML = """<!doctype html>
<html>
<head>
  <meta name="citation_publisher" content="PMLR"/>
  <meta name="citation_title" content="Embedding Hybrid Systems into Continuous Latent Vector Fields"/>
  <meta name="citation_language" content="en"/>
  <meta name="citation_issn" content="2640-3498"/>
  <meta name="citation_publication_date" content="2026/09/29"/>
  <meta name="citation_conference_title" content="International Conference on Machine Learning"/>
  <meta name="citation_pdf_url" content="https://raw.githubusercontent.com/mlresearch/v306/main/assets/teng26a/teng26a.pdf"/>
</head>
<body>
<code class="language-bibtex" id="bibtex">@InProceedings{pmlr-v306-teng26a,
  title = {Embedding Hybrid Systems into Continuous Latent Vector Fields},
  author = {Teng, Sangli and Liu, Hang and Sreenath, Koushil},
  booktitle = {Proceedings of the 43rd International Conference on Machine Learning},
  pages = {120039--120069},
  year = {2026},
  editor = {Zhang, Tong and Dudik, Miroslav},
  volume = {306},
  series = {Proceedings of Machine Learning Research},
  month = {06--11 Jul},
  publisher = {PMLR},
  pdf = {https://raw.githubusercontent.com/mlresearch/v306/main/assets/teng26a/teng26a.pdf},
  url = {https://proceedings.mlr.press/v306/teng26a.html},
  abstract = {Proves $m&gt;2n$ for an &lt;em&gt;intrinsically&lt;/em&gt; discontinuous system.}
}</code>
</body>
</html>
"""

SAMPLE_INDEX = """
<div class="paper">
  <p class="title">ReKep: Spatio-Temporal Reasoning of Relational Keypoint Constraints for Robotic Manipulation</p>
  <p class="links"><a href="https://proceedings.mlr.press/v270/huang25g.html">abs</a></p>
</div>
<div class="paper">
  <p class="title">Other Manipulation Paper</p>
  <p class="links"><a href="https://proceedings.mlr.press/v270/other25a.html">abs</a></p>
</div>
"""


def test_parse_pmlr_page_and_extra():
    paper = mod.parse_pmlr_page(
        "https://proceedings.mlr.press/v306/teng26a.html",
        "v306",
        "teng26a",
        SAMPLE_HTML,
    )
    assert paper.venue_abbr == "ICML"
    assert paper.date == "06–11 Jul 2026"
    assert paper.issn == "2640-3498"
    assert paper.language == "en"
    assert paper.pdf_url.endswith("teng26a.pdf")
    assert "<em>" not in paper.clean_bibtex
    assert "$m>2n$" in paper.clean_bibtex
    assert "intrinsically discontinuous" in paper.fields["abstract"]

    old = mod.OldItemInfo(
        key="OLD12345",
        title="Embedding Hybrid Systems into Continuous Latent Vector Fields",
        url="https://openreview.net/forum?id=jk66MtkUS1",
        short_title="",
        extra="Citation Key: Teng26_\narXiv:2606.10596\npdf: https://example.com/old.pdf\ntex.affiliation: UC Berkeley",
        collections=["4TE7L4AJ", "S7AYWSDP"],
        tags=[],
    )
    extra = mod.build_extra(paper.venue_abbr, old)
    lines = extra.splitlines()
    assert lines == [
        "tex.venueabbr: ICML",
        "arXiv:2606.10596",
        "tex.affiliation: UC Berkeley",
        "OpenReview: https://openreview.net/forum?id=jk66MtkUS1",
    ], lines


def test_volume_search():
    matches = mod.search_volume_html(SAMPLE_INDEX, "ReKep: Spatio-temporal reasoning")
    assert len(matches) == 1
    assert matches[0][1] == "https://proceedings.mlr.press/v270/huang25g.html"


def test_fix_misparsed_creators():
    creators = [
        {"creatorType": "author", "firstName": "Wenlong", "lastName": "Huang"},
        {"creatorType": "editor", "name": "Agrawal, Pulkit"},
        {"creatorType": "editor", "firstName": "Wolfram", "lastName": "Burgard"},
    ]
    fixed = mod.fix_misparsed_creators(creators)
    assert fixed == [
        {"creatorType": "author", "firstName": "Wenlong", "lastName": "Huang"},
        {"creatorType": "editor", "firstName": "Pulkit", "lastName": "Agrawal"},
        {"creatorType": "editor", "firstName": "Wolfram", "lastName": "Burgard"},
    ], fixed
    assert mod.fix_misparsed_creators(fixed) is None


def test_end_to_end_replace_and_user_work_guard():
    with tempfile.TemporaryDirectory(prefix="zotero-pmlr-test-") as tmp:
        base = Path(tmp)
        stubs = base / "stubs"
        stubs.mkdir()
        log_file = base / "calls.jsonl"

        stub_code = f"""#!/usr/bin/env python3
import json, os, sys
from pathlib import Path

args = sys.argv[1:]
if args and args[0] == "--json":
    args = args[1:]
with Path(os.environ["ZOTERO_TEST_LOG"]).open("a") as fh:
    fh.write(json.dumps(args) + "\\n")

mode = os.environ.get("ZOTERO_TEST_MODE", "clean")
if args[:2] == ["get", "metadata"]:
    if len(args) >= 3 and args[2] == "NEW99999":
        out = {{"data": {{"creators": [{{"creatorType": "editor", "name": "Agarwal, Alekh"}}]}}}}
    else:
        out = {{"data": {{"title": "Old Title", "url": "https://openreview.net/forum?id=abc",
                         "shortTitle": "OldShort", "extra": "arXiv:2606.10596",
                         "collections": ["COLL1"], "tags": [{{"tag": "robotics"}}]}}}}
elif args[:2] == ["get", "children"]:
    items = [{{"key": "NOTE1111", "itemType": "note"}}] if mode == "annotated" else []
    out = {{"items": items}}
elif args[:2] == ["notes", "list"]:
    out = {{"count": 1 if mode == "annotated" else 0, "notes": []}}
elif args[:2] == ["annotations", "list"]:
    out = [{{"key": "ANN11111"}}] if mode == "annotated" else []
elif args[:2] == ["add", "bibtex"]:
    out = {{"text": "Successfully added\\nItem key: `NEW99999`"}}
elif args[:1] == ["edit"]:
    out = {{"text": "Updated"}}
elif args[:1] == ["attach"]:
    out = {{"text": "Attached"}}
elif args[:2] == ["delete", "item"]:
    out = {{"text": "Trashed"}}
else:
    raise SystemExit(f"Unexpected args: {{args}}")
print(json.dumps({{"ok": True, "command": " ".join(args[:2]), "schema": 1, "data": out}}))
"""
        stub = stubs / "zotero-cli"
        stub.write_text(stub_code, encoding="utf-8")
        stub.chmod(0o755)

        orig_fetch = mod.fetch_text
        orig_dl = mod.download_pdf
        orig_path = os.environ["PATH"]
        try:
            mod.fetch_text = lambda _url, timeout=25: SAMPLE_HTML

            def fake_dl(_url, dest, timeout=60):
                dest.write_bytes(b"%PDF-1.7\n" + b"0" * 2048)
                return 2057

            mod.download_pdf = fake_dl
            os.environ["PATH"] = f"{stubs}{os.pathsep}{orig_path}"
            os.environ["ZOTERO_TEST_LOG"] = str(log_file)

            # 1. Clean old item is replaced and trashed.
            os.environ["ZOTERO_TEST_MODE"] = "clean"
            rc = mod.main(["https://proceedings.mlr.press/v306/teng26a.html", "--replace", "OLD12345", "--json"])
            assert rc == 0
            calls = [json.loads(line) for line in log_file.read_text(encoding="utf-8").splitlines()]
            assert ["delete", "item", "OLD12345"] in calls, calls
            assert any(c[:2] == ["attach", "NEW99999"] for c in calls), calls
            log_file.unlink()

            # 2. Item with notes/annotations is NOT trashed automatically.
            os.environ["ZOTERO_TEST_MODE"] = "annotated"
            rc = mod.main(["https://proceedings.mlr.press/v306/teng26a.html", "--replace", "OLD12345", "--json"])
            assert rc == 0
            calls2 = [json.loads(line) for line in log_file.read_text(encoding="utf-8").splitlines()]
            assert ["delete", "item", "OLD12345"] not in calls2, calls2
        finally:
            mod.fetch_text = orig_fetch
            mod.download_pdf = orig_dl
            os.environ["PATH"] = orig_path


if __name__ == "__main__":
    test_parse_pmlr_page_and_extra()
    test_volume_search()
    test_fix_misparsed_creators()
    test_end_to_end_replace_and_user_work_guard()
    print("ok       zotero-pmlr: dual-source parsing, Extra merging, and safe replace guard pass")
