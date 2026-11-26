---
name: zotero-pmlr
description: Import or replace Zotero entries directly from official PMLR proceedings (CoRL, ICML, L4DC, AISTATS, COLT, UAI) using the `zotero-pmlr` command. Use whenever adding a PMLR conference paper or upgrading an OpenReview/arXiv Zotero item to its published PMLR proceeding record.
---

# Importing PMLR proceedings into Zotero

Use `zotero-pmlr` instead of `zotero-cli add url` or manually writing BibTeX for papers hosted on `proceedings.mlr.press` (CoRL, ICML, L4DC, AISTATS, COLT, UAI, etc.).

Why: `zotero-cli add url` misclassifies PMLR pages as `journalArticle` and drops editors, series, volume, abstract, and PDF. `zotero-pmlr` programmatically combines each PMLR page's official `<code id="bibtex">` and `<meta name="citation_*">` tags, sets `tex.venueabbr` for Better BibTeX citekeys, attaches the official PMLR PDF, and safely handles `--replace`.

## Common commands

```bash
# Import directly by PMLR URL (or vNNN/slug)
zotero-pmlr https://proceedings.mlr.press/v306/teng26a.html -c "Neuro-Symbolic and TAMP"

# Search a PMLR volume and preview first
zotero-pmlr --volume v270 --query "ReKep" --dry-run

# Upgrade/replace an existing OpenReview or arXiv item in Zotero
zotero-pmlr https://proceedings.mlr.press/v270/huang25g.html --replace WLWSK9PA --short-title ReKep

# Search a PMLR volume using the existing item's title automatically
zotero-pmlr --volume v306 --replace ZFVECSLE --json
```

## Safety and behavior

- Always pass `--json` when parsing output, and use `--dry-run` before batch or uncertain replacements.
- `--replace <ITEM_KEY>` inherits collections, tags, `shortTitle`, and `Extra` provenance (`OpenReview:`, `arXiv:`, etc.) from the old item.
- If the old item has any notes or PDF annotations, `zotero-pmlr` refuses to trash it and leaves both items in the library for manual merge (override only with explicit user approval via `--force-trash`, or pass `--keep-old`).
- Run `zotero-pmlr --help` for all flags (`--venue-abbr`, `--no-pdf`, `--keep-old`).
