.PHONY: help install install-pinned update latex build pdf preview preview-check html word serve clean

VERSION ?=

help:
	@echo "Targets:"
	@echo "  install        Pull the latest document-sanity from GitHub main and sync"
	@echo "                 the venv. Use this by default — document-sanity changes often."
	@echo "  install-pinned Install strictly from uv.lock (no upgrade). Reproducible / CI."
	@echo "  update         Alias for 'install' — re-resolve document-sanity to GitHub HEAD."
	@echo "  latex          Generate LaTeX artifacts in out/<version>/latex/ (no PDF compile)"
	@echo "  pdf            Build + compile to PDF (out/<version>/pdf/main.pdf)"
	@echo "  preview        Insert/refresh markdown-preview blocks in docs/"
	@echo "  preview-check  Fail if preview blocks are missing or stale (CI)"
	@echo "  html           Emit interactive HTML viewer (out/<version>/html/)"
	@echo "  word           Build a Word (.docx) document (out/<version>/word/main.docx)"
	@echo "  serve          Serve the HTML viewer on http://localhost:8000"
	@echo "  clean          Remove out/"
	@echo ""
	@echo "Pass VERSION=<ver> to any target for a specific dated version; otherwise"
	@echo "document-sanity auto-detects the latest src/<ver>/ directory."

# Default install = always pull latest main. `uv sync` alone respects uv.lock,
# which pins document-sanity to a specific commit and silently skips git updates;
# `uv lock --upgrade-package` re-resolves the git dep to the current HEAD.
install: update
update:
	uv lock --upgrade-package document-sanity
	uv sync

install-pinned:
	uv sync

latex:
	uv run document-sanity build $(if $(VERSION),--version $(VERSION))

# Deprecated alias for `latex`. Kept so existing scripts keep working.
build: latex

pdf:
	uv run document-sanity build --compile $(if $(VERSION),--version $(VERSION))

preview:
	uv run document-sanity preview $(if $(VERSION),--version $(VERSION))

preview-check:
	uv run document-sanity preview --check $(if $(VERSION),--version $(VERSION))

html: preview
	uv run document-sanity html $(if $(VERSION),--version $(VERSION))

word: preview
	uv run document-sanity word $(if $(VERSION),--version $(VERSION))

serve: html
	@ver=$${VERSION:-$$(ls -1 out | grep -E '^[0-9]{8}' | sort -r | head -1)}; \
	if [ -z "$$ver" ]; then ver=$$(ls -1 out | head -1); fi; \
	echo "Serving out/$$ver/html/ at http://localhost:8000"; \
	python3 -m http.server --directory out/$$ver/html 8000

clean:
	rm -rf out/
