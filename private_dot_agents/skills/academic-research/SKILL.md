---
name: academic-research
description: >-
  Design and audit empirical ML/robotics experiments, reproduce and verify
  baselines fairly, and draft, refine, or ship academic manuscripts in LaTeX
  with Overleaf-invisible Git sync. Use when implementing baselines, designing
  ablations, auditing metrics or results, structuring papers, editing prose, or
  preparing submissions.
---

# Academic Research Workflow

Checked on 2026-11-23.

Real innovation is never demonstrated by weakening baselines to inflate benchmark
margins. Scientific integrity and fairness come first: strengthen and verify
baselines under controlled budgets so genuine contributions and failure
boundaries stand out clearly.

## 1. Experimental rigor and fair baselines

### Baseline faithfulness gate

Never treat a baseline as complete merely because it runs without crashing.
Before multi-seed sweeps, verify each baseline with non-tautological sanity
tests:

| Check | Requirement |
| --- | --- |
| **Input sensitivity** | In deterministic eval mode, perturb task-critical inputs (observations, goals, obstacles, visual frames) and verify nonzero output sensitivity. |
| **Output scale fidelity** | Confirm action magnitude, speed, and distribution match the baseline's base prior or reference specification without spurious collapse. |
| **Known-solution & gradient check** | On an analytic test case, verify the training objective achieves expected error and any analytic Jacobian/gradient matches `autograd` or finite differences. |
| **Symmetric upper bound** | Run oracle or privileged upper bounds with the exact same RL backbone, observations (including auxiliary anchors/priors), critic inputs, and eval wrapper as the proposed method. |

### Controlled variables and ablations

- **Equalized budgets**: Match hidden width, input feature encodings, and total
  training updates (`batch_size * steps`) across compared learned baselines;
  document any unavoidable structural difference explicitly.
- **Single-variable ablations**: Change one factor per row. Verify via
  assertions or logs that distinct arm names execute distinct code paths rather
  than silently aliasing.
- **Symmetric tuning**: Sweep sensitive baseline hyperparameters over a compact
  declared grid instead of tuning only the proposed method.
- **A priori round grids and uniform protocols**: Pick speed ratios, sweep
  grids, and task thresholds from clean, human-canonical numbers before running
  experiments (e.g., `1.0x, 1.5x, 2.0x, 2.5x, 3.0x`; `{0.2, 0.5, 1.0}`),
  avoiding odd reverse-engineered decimals or per-regime special caps. Keep
  baseline sets, sweep grids, and seed/episode protocols uniform across
  benchmarks in the same paper.
- **Best-tuned baseline presentation**: Tune each baseline thoroughly, then
  report one operating point per baseline in main tables and figures chosen by
  one pre-declared rule (e.g., highest success, breaking ties by lowest
  violation) applied consistently across all metrics—never pairing a
  conservative setting for success with an aggressive setting for violation.
  State sweep grids concisely in captions or text and keep full sweeps in the
  appendix.
- **No hidden hacks or result gates**: Never add win-rate or speedup
  `RuntimeError` assertions to benchmark scripts. Disclose auxiliary
  pretraining, checkpoint selection (peak-val vs. final), or simulator
  simplifications.

### Metrics, statistics, provenance, and engineering repos

- **Boundary unit tests on metrics**: Test geometric and summary metrics on
  extreme edge cases (e.g., rank deflation, rank inflation, degenerate variance,
  zero gradients).
- **No oracle post-filtering**: Report unfiltered `All` metrics alongside tail
  quantiles (`p95`, `max`); never filter evaluation draws with ground-truth
  labels.
- **Statistical hygiene**: Pair `eval_seed` across all arms per training seed
  (never offset by arm index). Use uniform sample SD (`ddof=1`), 95%
  Bootstrap/Wilson CIs, explicit SD vs. SE plot labels, and verified physical
  units (apply action scaling and `dt` before labeling `rad/s` or `m/s`).
- **Provenance**: Record `git_sha`, `git_dirty`, hardware, seed list, and full
  hyperparameters in every `summary.json`. Run final sweeps from clean commits
  and keep generating scripts in git while their numbers remain cited.
- **Engineering repo storage**: Recommend **Git LFS** in companion engineering
  and code repositories for tracked binary/media artifacts (plots, videos,
  compact snapshots), while keeping heavy checkpoints and raw datasets outside
  git.
- **Shared-server preflight**: Inspect `nvidia-smi` and active compute PIDs to
  avoid other users' GPUs. Measure single-job host PSS RAM before scaling
  concurrency; prefer shared environment pools (`snapshot`/`restore`) over
  duplicate train/val/test pools.

## 2. Scientific writing and human-in-the-loop depth

### Two-stage clarity and abstraction

| Stage | Goal |
| --- | --- |
| **First AI draft** | Target ~70% first-read comprehension for a junior PhD student in the field. Build around one unified scientific principle and minimal formalization faithful to the code and proofs; reject decorative buzzwords. |
| **Human-in-the-loop deepening** | Refine paragraph by paragraph and sentence by sentence with the user; discuss structural cuts and figure trade-offs before editing. When higher-level mathematical abstraction communicates the core idea more concisely and powerfully, adopt it deliberately and accept the trade-off in introductory readability. |

### Core writing principles

| Principle | Rule |
| --- | --- |
| **Essence before means** | State the physical phenomenon, problem structure, or unified principle before the statistical estimator or neural implementation. |
| **Causal chaining** | State causes before effects. Link each sentence's opening to the previous sentence's ending. |
| **Term introduction & consistency** | Bridge from familiar anchors into new terms with simple active clauses. Keep one name and one symbol per concept across the whole paper; avoid raw code identifiers and symbol reuse. |
| **Baseline naming & symmetry** | Name baselines after their recognizable literature lineage with parallel syntax exposing controlled factors (e.g., `Oracle + ATACOM`, `ECoMaNN (Pos) + ATACOM`, `ECoMaNN (Vel) + ATACOM`; uniform `Method (Ablation)` or `Method w/o X` for ablations). Strip internal code identifiers, debug qualifiers (`fixed ...`), JSON keys, `git_sha`, `ep_seed`, and internal run IDs (`Exp 1A`, `Arm`) from published prose, tables, and captions. |
| **Table & figure restraint** | Keep main tables and figures uncluttered: one method per row (no slash-packed rows), one best-tuned point per swept baseline, minimal in-plot text boxes, and no emotional punctuation (`!`). |
| **Sentence economy** | Merge overlapping sentences and prefer short active-voice sentences. Remove promotional adjectives and redundant default qualifiers. |
| **Detail placement** | Keep motivation, core mechanism, falsifiable hypotheses, and compact contributions in `Abstract` and `Introduction`; complete algorithms, exact losses, and load-bearing theorems in `Problem` and `Method`; structured baseline taxonomy, ablations, and honest failure boundaries in `Experiments`. |
| **Titles & macros** | Prefer short, general, punchy titles over defensive qualified subtitles. Manage method names via a single LaTeX macro for one-line global updates. |
| **Load-bearing theory** | Keep only theorems that explain the mechanism or yield testable empirical predictions. Stress-test every mathematical claim and prose assertion against boundary counterexamples before freezing text. |
| **Scope & citations** | State scope conditions explicitly. Cite prior works strictly for what they establish, avoiding unfulfilled analogies. |

## 3. Manuscript repository, Overleaf, LaTeX, and Zotero workflow

### Collaboration background and coauthor-invisible principle

Manuscript repositories sync to **Overleaf** (via GitHub Integration or Overleaf
Git) for collaboration with coauthors, while actual drafting happens locally in
an editor with AI agents. **Coauthors on Overleaf must see a clean, natural,
human-edited Overleaf project on `main` with zero trace of local Git/AI tooling
and zero disrupted builds or comments.**

### Three-branch publication workflow (`dev` / `main` / `publish/<topic>`)

| Branch | Rule |
| --- | --- |
| `dev` | Active local drafting and AI collaboration: manuscript edits, `AGENTS.md`, `README.md`, revision plans, candidate figures, diagnostics, evidence ledgers, companion appendices, and slides. |
| `main` | Clean branch synced with Overleaf and shared with coauthors: accepted manuscript sources, required figures, bibliography, and conference style files only. Exclude `.gitignore`, dotfiles, build artifacts, `slides/`, `docs/`, and all internal files (use `.git/info/exclude` locally on `main`). |
| `publish/<topic>` | Branched from updated `main`. Transfer accepted manuscript changes from `dev` by file, audit compilation and full diff against `main`, then open a PR into `main`. Never merge `dev` directly into `main`. |

Procedure: sync Overleaf edits to `main` first -> write and commit on `dev` ->
update `main` and branch `publish/<topic>` -> transfer accepted files cleanly ->
compile and stealth-audit full diff -> push/PR when authorized -> transfer
coauthor edits from `main` back into `dev` by file or manuscript-only commit.

### Overleaf guardrails and pitfalls to prevent

| Pitfall | Guardrail |
| --- | --- |
| **No Git LFS on Overleaf** | Never enable or commit Git LFS pointers in a manuscript repository (Overleaf does not support Git LFS and breaks figure compilation). Keep heavy raw media, code, and checkpoints in the companion engineering repository. |
| **Compile timeout & large vector PDFs** | Rasterize dense scatter/heatmap internals inside vector PDF axes (`rasterized=True` at 300 DPI) and keep figures lightweight (typically `< 1-2 MB`, far below Overleaf's 50 MB file cap) so Overleaf compilation and preview stay fast. |
| **TeX Live parity & no `--shell-escape`** | Target standard `pdflatex` + `bibtex` on `main` with zero `--shell-escape` dependencies (no `minted`, `svg`, or TikZ `externalize`) and avoid bleeding-edge local-only macros incompatible with the Overleaf project's TeX Live version. |
| **Zero dotfiles or build clutter on `main`** | Overleaf displays dotfiles in its sidebar and auto-runs `latexmk`. Never commit `.gitignore`, `.gitattributes`, `.latexmkrc`, `.github/`, `.DS_Store`, `.aux`, `.bbl`, or compiled `.pdf` outputs onto `main`. |
| **Protect coauthor diffs, comments & stealth** | Never reformat untouched paragraphs edited by coauthors; keep `publish/<topic>` edits surgical. Strip all AI/internal comments (`% TODO(agent)`, provenance notes) and raw code identifiers before merging to `main`. Write natural human squash commit messages on `main`. Never force-push `main` or an Overleaf remote, and coordinate pushes during active coauthor review so Overleaf comments and tracked changes are not displaced. |
| **Paths, filenames & sync races** | Use only lowercase ASCII filenames without spaces and root-relative paths (`figures/...`, never `../...`) on `main`. Because Overleaf GitHub sync is manual, always pull Overleaf changes into GitHub `main` before merging new local pushes. |

### LaTeX, bibliography, and pre-submission audit

- **Source formatting**: Put each prose sentence on one source line with blank
  lines between paragraphs (keeping local `dev` vs. Overleaf coauthor diffs clean
  at sentence granularity). Preserve equations, tables, and TikZ blocks; disable
  fixed-width wrapping.
- **Compilation & page budget**: Compile with `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=build main.tex`.
  When a venue counts appendices toward the page limit, keep companion writing
  materials in a separate appendix toggled off in `main.tex`
  (`\includeappendixfalse`) plus a standalone compiled appendix PDF kept off
  `main`.
- **TikZ citations**: Use standard `\cite{...}` inside TikZ figures, guarded by
  `\renewcommand{\cite}[2][]{[\detokenize{#2}]}` before `\begin{document}` for
  standalone compilation.
- **Zotero & `.bib` read-only**: Humans maintain Zotero and export `.bib` via
  Better BibTeX for Overleaf sync; direct AI edits get overwritten or desync.
  AI agents may only read Zotero and `.bib` files (never edit, overwrite,
  regenerate, or delete `.bib`) and treat existing Zotero metadata as trusted.
- **Evidence ledger & visual check**: Maintain a repo-local ledger on `dev`
  mapping every reported number 1-to-1 to exact `summary.json` keys and
  `git_sha`. Before delivery, verify zero LaTeX/BibTeX errors, warnings, or
  overfull hboxes, exact page count via `pdfinfo`, and page-by-page visual
  inspection of rendered PNGs (`pdftoppm -png -r 150`).
