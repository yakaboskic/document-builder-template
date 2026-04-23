# document-builder-template

A ready-to-clone GitHub template for manuscripts built with
[document-sanity](https://github.com/yakaboskic/document-sanity). Markdown
is the source of truth; builds produce a compilable LaTeX tree, a PDF, an
interactive HTML viewer, a Word (`.docx`) document, and
markdown-preview blocks for GitHub.

## Clone and rename

On GitHub, click **Use this template** → **Create a new repository**.
Locally:

```bash
git clone https://github.com/<you>/<your-repo> my-paper
cd my-paper

# Rename the project in pyproject.toml
sed -i '' 's/document-builder-template/your-slug/' pyproject.toml     # macOS
sed -i    's/document-builder-template/your-slug/' pyproject.toml     # linux
```

Edit `src/initial/manifest.yaml` with your title / authors /
affiliations / abstract. Add `\newcommand` macros to
`templates/article.tex` if your writing wants custom math shortcuts
(`\prob` → `\text{Pr}`, etc.). Fill `src/<MMDDYYYY>/docs/*.md` with your
sections.

## Prerequisites

- Python 3.10+
- [uv](https://github.com/astral-sh/uv) (`brew install uv` or
  `pipx install uv`)
- A TeX distribution (MacTeX / TeX Live) with `pdflatex` and `bibtex` for
  PDF builds. Not required for HTML or Word builds.

## Quickstart

```bash
make install              # pulls document-sanity from GitHub main and syncs venv
make pdf                  # build + compile out/<ver>/pdf/main.pdf
make html                 # interactive HTML viewer at out/<ver>/html/index.html
make word                 # Word document at out/<ver>/word/main.docx
make serve                # also runs `make html`, opens http://localhost:8000
```

`make install` always pulls the latest `document-sanity` commit from
GitHub `main`. Use `make install-pinned` for strictly
lockfile-reproducible builds (CI).

## Workflow

1. Edit `src/<ver>/docs/*.md`. See
   [document-sanity docs](https://github.com/yakaboskic/document-sanity/tree/main/docs)
   for the opinionated conventions:
   - Figures go under `src/<ver>/figures/<figure-id>/<figure-id>.{pdf,png,html,...}`.
     PDF builds prefer `.pdf`, HTML prefers `.html`, Word prefers `.png`.
   - Label prefixes (`fig:`, `tab:`, `eq:`, `sec:`) drive automatic
     numbering in the HTML viewer.
   - Variables with provenance power the HTML viewer's interactive side
     panel.

2. **After editing any ```latex block**, refresh the markdown-preview:
   ```bash
   make preview
   ```
   This regenerates inline `![alt](path)` / `$$…$$` / pipe-table
   approximations so the doc renders meaningfully on GitHub, VSCode,
   Obsidian, and Cursor — and so `make html` / `make word` can embed
   the figures described in ```latex fences.

   > **Figures missing from `make html` or `make word` output?**
   > `make html` and `make word` depend on `make preview`, so a fresh
   > clone renders correctly. If you invoke `document-sanity html` /
   > `document-sanity word` directly (bypassing make) and figures
   > declared inside ```latex blocks don't appear, run `make preview`
   > first — those fences are PDF-only; HTML and Word pick up figures
   > from the markdown-preview blocks written beside them.

3. **Before committing**, optionally verify previews are up-to-date:
   ```bash
   make preview-check
   ```
   Returns non-zero if any ```latex block's preview is stale. Good for
   CI.

4. Build and inspect:
   ```bash
   make pdf                                     # for submission-quality output
   make html                                    # for interactive review
   make word                                    # for Word-native review/comments
   ```

## Word output

Drop a `.docx` template into `templates/` (alongside `article.tex`) and
point to it from `manifest.yaml`:

```yaml
metadata:
  title: "My Paper"
  template: article              # for LaTeX/PDF build
  word_template: my-template     # looks for templates/my-template.docx
```

Headers, footers, theme, fonts, and page layout are preserved from the
template; only the body is replaced with generated content. Styles are
extracted from the template's `styles.xml` + `theme1.xml` and applied
automatically — no hand-tuning required. See the
[Word output docs](https://github.com/yakaboskic/document-sanity/blob/main/docs/word.md)
for the full behavior.

## Cutting a new version

```bash
# Copy src/initial/ (or the latest version) to today's date
uv run document-sanity new-version --strategy date
```

Versions are directories under `src/`. The template ships with
`src/initial/` — on first real cut, `new-version` creates
`src/MMDDYYYY/` for an archived snapshot, and subsequent `new-version`
runs increment the date from there. All commands auto-detect the latest
version; pass `VERSION=<name>` to the Makefile for a specific one
(e.g. `make pdf VERSION=initial`).

## Layout

```
.
├── pyproject.toml          # declares document-sanity as the only dep
├── Makefile                # install / build / pdf / preview / html / word / serve
├── .gitignore              # ignores out/ and build intermediates
├── README.md               # you are here
├── templates/
│   ├── article.tex         # default LaTeX template with insertion points
│   │                       # replace with nature.tex + sn-jnl.cls for Nature
│   └── <name>.docx         # optional — Word template (headers/footers/theme)
└── src/
    └── initial/            # starter version — use `new-version` to snapshot dated copies
        ├── manifest.yaml   # metadata, variables, figures, tables — one-stop config
        ├── docs/           # markdown sections in manifest.sections order
        │   ├── introduction.md
        │   ├── methods.md
        │   ├── results.md
        │   └── discussion.md
        ├── figures/        # <id>/<id>.{pdf,png,html} subdirectory layout
        │   └── example/
        │       └── example.png
        ├── tables/         # optional .tex tables (you can also inline them)
        └── references.bib  # bibliography
```

## References

- **document-sanity repo**: https://github.com/yakaboskic/document-sanity
- **Opinionated docs**: https://github.com/yakaboskic/document-sanity/tree/main/docs
- **Example paper project**: https://github.com/yakaboskic/pigean-indirect-support
