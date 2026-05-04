# AGENTS.md

Operating instructions for an agent driving this template. Two
distinct jobs:

1. **Onboarding**: take a heap of source documents (Word, markdown,
   PDF, CSV, loose figures) and turn them into a new
   `src/<version>/` that builds cleanly across all four targets.
2. **Iteration**: refine an existing `src/<version>/` in a tight
   edit / preview / review loop, finishing every iteration with
   `make preview` so the GitHub-renderable preview blocks stay in
   sync.

Read [README.md](./README.md) first for the project layout, the
manifest schema, and the make targets. This file is the runbook for
*how an agent moves through that surface*.

---

## 0. Ground rules

- **Never edit `out/`.** That tree is a build product. Edit `src/`,
  `templates/`, or `styles/`, then rebuild.
- **`src/manuscript/` and `src/proposal/` are starters.** When
  onboarding new content, create `src/<new-name>/` rather than
  overwriting either. Copy structure from whichever starter is
  closer to the target document type.
- **End every iteration with `make preview`.** The preview command
  inserts / refreshes inline `![alt](path)` / `$$…$$` / pipe-table
  approximations next to ```latex blocks so GitHub, VSCode,
  Obsidian, and Cursor all render the markdown meaningfully. HTML
  and Word builds also depend on these blocks for figures declared
  inside ```latex fences. **This is non-negotiable.** A loop that
  ends without `make preview` leaves the markdown half-rendered.
- **Don't commit `out/` or the venv.** `.gitignore` already covers
  them; don't widen the ignore list to mask anything.

---

## 1. Onboarding workflow

You're given a set of source documents in some inbox directory
(`./inputs/`, a Slack thread, a zip, a Google Drive link the user
already downloaded). Goal: produce `src/<version>/` with a manifest,
docs, figures, tables, and references that build clean.

### 1.1 Pick a version name and starter

- **Manuscript-style** sources (paper, journal article, technical
  report with abstract / methods / results): clone the
  `src/manuscript/` shape. Auto-rendered title block, sections like
  Introduction / Methods / Results / Discussion.
- **Proposal-style** sources (SBIR/STTR, NIH/NSF, whitepaper, with
  hand-numbered sections like "1.0 Introduction"): clone the
  `src/proposal/` shape. `metadata.render: false`,
  `template: proposal`, sections numbered in markdown headings.

```bash
cp -r src/proposal src/<your-version>
# or
cp -r src/manuscript src/<your-version>
```

Then erase the demo content under `docs/`, `figures/`, `tables/`,
`references.bib` — keep `manifest.yaml` as a structural skeleton
you'll edit.

### 1.2 Convert Word inputs (`.docx`) → markdown + media

`document-sanity` does not import Word natively. Use **pandoc**:

```bash
mkdir -p inputs/extracted
pandoc inputs/source.docx \
    -t gfm \
    --extract-media=inputs/extracted/media \
    -o inputs/extracted/source.md
```

What this does:

- `-t gfm` (GitHub-Flavored Markdown) gives you tables as pipe
  tables and predictable heading levels.
- `--extract-media=...` writes every embedded image into a
  subdirectory and rewrites image references in the markdown to
  point at the extracted files.
- Tables that pandoc can't represent as pipe tables come through as
  raw HTML — that's a signal you should either (a) simplify the
  table, (b) inline it as a markdown pipe table by hand, or (c)
  promote it to a CSV under `tables/` (see §1.5).

Repeat for every input `.docx`. Keep the per-source markdown files
as scratch in `inputs/extracted/` — you'll split / merge / rewrite
them into the version's `docs/` next.

### 1.3 Plan the section structure

Read the extracted markdown end-to-end. Identify the logical
sections — usually they map onto the input's heading hierarchy.
Then either:

- **One file per section**, named by content (`introduction.md`,
  `methods.md`, `results.md`, …) — preferred for manuscript-style
  output.
- **Numbered prefix per section** (`1_introduction.md`,
  `2_aims.md`, …) — preferred for proposal-style output where on-
  disk order tracks rendered order.

Write the chosen order into `manifest.yaml` under `sections:`. Use
`_bibliography` as a pseudo-section to place the References list,
and `_toc` for `\tableofcontents`.

### 1.4 Place figures

`pandoc --extract-media` dumps everything into one directory with
auto-generated filenames (`media/image1.png`,
`media/image2.png`, …). Move and rename into the
`figures/<id>/<id>.<ext>` layout this template expects:

```bash
# Example — figure that's the "framework overview"
mkdir -p src/<ver>/figures/overview
mv inputs/extracted/media/image1.png src/<ver>/figures/overview/overview.png
```

Rules:

- The directory name and the file stem must match the figure id.
- One figure id can have multiple format files for different build
  targets: `overview.pdf` (PDF prefers vector), `overview.html`
  (HTML prefers interactive), `overview.png` (Word and fallback).
  The builder picks the best fit per target automatically.
- Add an entry under `figures:` in `manifest.yaml` with the id;
  `width: "\\textwidth"` is a sane default. You can omit `source:`
  and let directory auto-resolution work.
- Reference from markdown via either:
  - **Inline image** `![alt text](../figures/overview/overview.png)`
    for figures used once, or
  - **Manifest-declared** with `{{fig:overview}}` inside a ```latex
    `\begin{figure}` block when you want a numbered float with a
    caption. The `manuscript/docs/methods.md` example shows the
    latter.

### 1.5 Place tables

For each table in the input, decide whether it's:

- **Inline** — small, presentation-only (caption / metric /
  description). Just write a markdown pipe table directly in the
  doc:
  ```markdown
  | Metric    | Value            | Notes              |
  |-----------|------------------|--------------------|
  | N         | {{NUM_SAMPLES:,}} | Total enrolled     |
  ```
- **Data-driven file** — output of an analysis script, regenerated
  often, or wider than 4–5 columns. Put the file under
  `src/<ver>/tables/` and add a `tables:` entry:
  ```yaml
  tables:
    subgroup_summary:
      source: tables/subgroup_summary.csv
      format: csv          # csv | tsv | markdown | latex
      provenance:
        description: Effect size by subgroup.
        source: data/analysis_results.parquet
        command: python scripts/subgroup_summary.py --out tables/subgroup_summary.csv
        updated: "2026-04-21"
  ```
  Reference from markdown with `{{tab:subgroup_summary}}` — the
  token expands to a markdown pipe table at build time and renders
  identically in PDF, HTML, and Word.

If pandoc emitted an HTML `<table>` block for an input table that
was too complex for a pipe table:

- For 5+ rows of structured data, extract to a CSV (open the input
  doc in Word, copy-paste the table into a spreadsheet, save as
  CSV) and use the `{{tab:<id>}}` path.
- For complex multi-column-header layouts that don't reduce to a
  flat CSV, drop into a ```latex block with `\begin{tabular}` and
  put a sibling `tables/<id>.tex` file plus a `format: latex` entry
  if you want a separate file.

### 1.6 Variables

Numbers that appear in the prose AND are derived from data should
become variables. The pattern:

```yaml
variables:
  NUM_SAMPLES: 1247                    # simple form
  PVAL:                                # full form with provenance
    value: 0.0087
    provenance:
      description: Two-sided p-value, BH-adjusted across 12 tests.
      source: data/results.csv
      command: python scripts/fit.py
      updated: "2026-04-21"
```

Reference with `{{NUM_SAMPLES:,}}` or `{{PVAL:.2e}}` (Python format
specs). Variables with provenance show a clickable popover in the
HTML viewer.

When onboarding, scan the prose for hard-coded numbers — sample
sizes, p-values, R² values, accuracy figures, dollar amounts — and
promote them to variables with provenance pointing at the source
document or upstream analysis.

### 1.7 References (bibliography)

Look at the input for citation markers. Three patterns:

- **`\cite{key}` already in source**: keep as-is in markdown.
  Add a matching `@article{key, …}` to `references.bib`.
- **Numbered citations `[1]`, `[2]`**: replace with `\cite{key}`
  using a meaningful slug. Build `references.bib` by transcribing
  the input's reference list.
- **Author-year citations `(Smith 2024)`**: same — replace with
  `\cite{smith_2024}` and add the bib entry.

The `_bibliography` pseudo-section in `manifest.sections` is where
the rendered References list lands.

### 1.8 Word styles (when the input has a desired look)

If the input `.docx` has the visual design you want to preserve in
the output, extract its styles into the styles folder:

```bash
uv run document-sanity word --extract-styles \
    --template inputs/source.docx \
    --output styles/<your-name>.yaml
```

Then point the manifest at it:
```yaml
metadata:
  word_styles: <your-name>      # → styles/<your-name>.yaml
```

If you also want the input's header / footer / theme / page layout,
copy the `.docx` itself into `templates/<your-name>.docx` and set
`word_template: <your-name>`. The build will preserve everything
from the template `<w:sectPr>` (headers, footers, margins, theme
refs) and only replace the body.

### 1.9 Construct `manifest.yaml`

By the time you've done §1.1–1.8, the manifest is mostly written.
A complete onboarded manuscript-style manifest looks like:

```yaml
metadata:
  title: "Paper Title"
  authors: [...]
  affiliations: {...}
  abstract: |
    ...
  keywords: [...]
  template: article
  word_template: article
  word_styles: article
  html_styles: article
  render: true             # or false for proposal-style

sections:
  - docs/introduction.md
  - docs/methods.md
  - docs/results.md
  - docs/discussion.md
  - _bibliography

variables: { ... }
figures: { ... }
tables: { ... }
```

### 1.10 First build + the mandatory preview

```bash
make install                     # if you haven't yet
make preview VERSION=<ver>       # insert preview blocks (mandatory after every change)
make latex VERSION=<ver>         # cheapest sanity check
make pdf VERSION=<ver>           # find pdflatex errors early
make html VERSION=<ver>
make word VERSION=<ver>
```

If a build fails, fix the underlying issue before moving on. Common
onboarding-time failures:

- **Unescaped `$`** in prose → use `\$`
- **Math operator characters** (`≥`, `≤`, `→`, `≠`, `×`) →
  already handled by the templates' `\DeclareUnicodeCharacter` block
- **Stray `\textsuperscript{}` from LaTeX-native source** →
  rewrite as `<sup>...</sup>` for cross-format consistency
- **Pipe character inside a table cell** → escape as `\|`
- **Missing figure file** → check the `figures/<id>/` directory has
  `<id>.{png,pdf,svg,html}` (stem must match dir name)

---

## 2. The agentic refinement loop

Once `src/<version>/` builds clean, iteration is short and tight:

```
┌──────────────────────────────────────────────────────────────────┐
│  1. Read user request + the current state of                     │
│     src/<ver>/manifest.yaml and the relevant docs/*.md           │
│                                                                  │
│  2. Make the smallest edit that addresses the request:           │
│       - prose change → edit docs/*.md                            │
│       - new variable → manifest.yaml + reference in prose        │
│       - new table → tables/<id>.csv + manifest.tables entry      │
│       - new figure → figures/<id>/<id>.{png,pdf,svg} + reference │
│       - style change → styles/<name>.yaml or .css                │
│                                                                  │
│  3. make preview VERSION=<ver>      ← MANDATORY                  │
│                                                                  │
│  4. Build the target the user is reviewing in:                   │
│       - default: make pdf (catches most errors)                  │
│       - if asked about HTML look: make html                      │
│       - if asked about Word look: make word                      │
│                                                                  │
│  5. If the build failed, diagnose from the log:                  │
│       - out/<ver>/latex/main.log for pdflatex                    │
│       - structured stdout from document-sanity for html/word     │
│     Fix; re-run from step 3.                                     │
│                                                                  │
│  6. Report back to the user: what changed (file paths +          │
│     line numbers), what the user should look at, any caveats.    │
└──────────────────────────────────────────────────────────────────┘
```

### 2.1 Why `make preview` is in step 3, not step 4

The preview blocks are markdown approximations of ```latex figures /
equations / tables. Three things depend on them:

- **GitHub / VSCode / Obsidian rendering** — without preview blocks,
  ```latex fences render as code, not as figures.
- **HTML and Word builds** — they read figures from preview blocks
  for ```latex fences (the LaTeX path is the only one that reads
  the fence directly). `make html` and `make word` chain
  `make preview` for this reason; you still want it explicitly
  before user-visible review so the markdown source is in sync
  even if the user never builds HTML/Word.
- **Diff hygiene** — committing without a preview pass means the
  next person to run `make preview-check` will see drift. If you're
  about to hand the work back, `make preview` cleans that up.

If you skip `make preview` in step 3, you'll usually catch it
because the figure won't appear in HTML or Word output. But by then
you've already burned a build cycle. Just do it every time.

### 2.2 Smaller checkpoints

For multi-step refinements, build after each meaningful checkpoint
rather than queueing up edits. The build is cheap (a few seconds for
LaTeX, a few more for PDF) and a failed build at edit N is much
easier to debug than a failed build after N+5 edits.

For a one-line typo fix, the explicit cycle is overkill — just edit
+ `make preview`. Use judgment.

### 2.3 What to do when the user gives a Word doc with comments / suggestions

If the user hands you a marked-up `.docx` (track changes, comments,
suggestions) and asks you to apply the changes:

1. Convert the .docx to markdown with pandoc as in §1.2.
2. Diff the converted markdown against the corresponding section
   files in `src/<ver>/docs/`.
3. Apply the substantive changes by editing the source markdown
   directly. Don't try to round-trip the whole file — Word's
   formatting won't survive pandoc cleanly enough.
4. `make preview` + rebuild.

Comments / suggestions visible in Word's review pane appear in the
extracted markdown as `<span class="comment">…</span>` or similar
artifacts; treat those as instructions to apply, not content to
preserve.

---

## 3. Common ops

### Cut a new dated version from the current latest

```bash
uv run document-sanity new-version --strategy date
# creates src/MMDDYYYY/ as a copy
```

### Diff two versions

```bash
diff -ru src/manuscript src/MMDDYYYY/ | less
# or for a single section:
diff src/manuscript/docs/methods.md src/MMDDYYYY/docs/methods.md
```

### Inspect the auto-emitted Word styles after a build

```bash
make word VERSION=<ver>
$EDITOR out/<ver>/word/styles.yaml
# if you like the changes, copy back to styles/ and point manifest at it:
cp out/<ver>/word/styles.yaml styles/<name>.yaml
# ensure manifest.metadata.word_styles: <name>
```

### Run a quick correctness check before reporting

```bash
make preview-check VERSION=<ver>     # exits non-zero on stale preview blocks
make latex VERSION=<ver>             # cheapest end-to-end sanity check
```

---

## 4. Anti-patterns to avoid

- **Editing `out/` files** to "fix" something. Edit the source,
  rebuild.
- **Bypassing `make preview`** because "I'll do it at the end". You
  won't, and HTML/Word output will silently lose figures.
- **Hand-numbering markdown headings inside a manuscript-style
  version**. The manuscript template auto-numbers via `\section{}`;
  hand-writing "1." in the heading produces "1 1.".
- **Stuffing raw HTML / LaTeX into prose where a markdown form
  exists**. `<sup>X</sup>` over `\textsuperscript{X}`,
  `**bold**` over `<b>X</b>`, fenced ```` ``` ```` over `<pre>`.
- **Copying figures into multiple docs/ directories**. Figures live
  under `figures/<id>/` and are referenced by id; never duplicate.
- **Stale `references.bib` entries**. If you add a `\cite{key}`,
  add the bib entry in the same edit. `pdflatex` warns on undefined
  citations; if the warning shows up in the build log, fix it
  before reporting.
- **Letting prose dollar signs open math mode**. Use `\$`. If a
  build mysteriously errors with "Missing $ inserted", grep for an
  unescaped `$` in the source.
- **Adding new make targets without updating the README's targets
  table**. Pinned content drifts; documentation is part of the
  source.

---

## 5. When to escalate to the user

- **Ambiguous source content** (multiple drafts disagree, embedded
  notes asking the author a question). Ask which to use.
- **Missing bibliography entries**. Don't fabricate citations; ask
  for the source paper or DOI.
- **Layout choices that don't fall out of the manifest**. New
  templates, new fonts, new page sizes. Propose, don't decide.
- **A repeatable bug in `document-sanity` itself**. The upstream
  repo is at `https://github.com/yakaboskic/document-sanity` —
  surface the reproducer to the user; they'll decide whether to
  patch upstream or work around in the template.
