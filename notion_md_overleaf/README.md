
# Notion → Markdown → LaTeX (Overleaf-ready)

This repo converts clean Notion-exported `.md` files into **Overleaf-editable** `.tex` files.

Key fixes included:
- **HTML tables → real LaTeX tables** (`longtable` + `booktabs`)
- **Emoji/symbol sanitising** (Overleaf editor can open emoji-heavy uploads as read-only “Download” viewer)

---

## Requirements

### Local
- **Pandoc** (CLI available on your PATH)

### Overleaf (preamble)
Add these packages in your `main.tex`:

```tex
\usepackage{booktabs}
\usepackage{longtable}
\usepackage{fancyvrb}
````

---

## Files

Filters (must exist in `filters/`):

* `filters/html_tables.lua`
  Converts Notion HTML tables (`<table>...</table>`) into proper LaTeX tables.

* `filters/emoji_sanitize.lua`
  Replaces emojis/symbols with LaTeX-safe text (prevents Overleaf read-only viewer mode).

---

## Workflow

### Step 1 — Export Markdown from Notion

Export `.md` files via the Notion API (or your existing exporter).
Place the resulting `*.md` files in a single folder.

### Step 2 — Convert Markdown → LaTeX

From the folder containing your `*.md` files:

```bash
mkdir -p tex_files

for f in *.md; do
  pandoc "$f" \
    -f markdown+raw_html \
    -t latex \
    --lua-filter=filters/html_tables.lua \
    --lua-filter=filters/emoji_sanitize.lua \
    --wrap=preserve \
    -o "./tex_files/${f%.md}.tex"
done
```

Output: `./tex_files/*.tex`

### Step 3 — Upload to Overleaf

1. Upload the generated `tex_files/*.tex` into your Overleaf project.
2. Create/maintain a single `main.tex` that `\input{}`s the files you want:

```tex
\input{tex_files/10_evaluation_breakdown.tex}
\input{tex_files/21_ner_build.tex}
```

(Use whatever filenames you generated.)

---

## Notes / Troubleshooting

### “Overleaf only shows Download, I can’t edit”

This is caused by emoji/symbol characters in uploaded `.tex` files.
`emoji_sanitize.lua` removes/replaces them so the Overleaf editor opens the files normally.

### Tables show up as plain text (Metric / Value / …)

That means HTML tables weren’t converted. Confirm you included:

* `-f markdown+raw_html`
* `--lua-filter=filters/html_tables.lua`

---

## Recommended naming

Overleaf and LaTeX behave better with filenames that avoid spaces. If needed, rename outputs to snake_case before uploading.

