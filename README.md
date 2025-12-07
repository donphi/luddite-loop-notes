# luddite-loop-notes

> ⚠️ **Submodule Notice**  
> This repository is a submodule of [luddite-loop](https://github.com/donphi/luddite-loop) and appears as the `notes/` folder in the parent repo.

---

## Submodule Workflow

This repo and the parent repo are **versioned independently**. Changes here must be pushed separately.

### Editing files in this submodule

```bash
cd notes/                         # Enter submodule directory
# make your changes
git add .
git commit -m "Your message"
git push                          # Pushes to luddite-loop-notes repo
```

Then update the pointer in the parent repo:

```bash
cd ..                             # Back to luddite-loop root
git add notes
git commit -m "Update notes submodule"
git push                          # Pushes to luddite-loop repo
```

### Cloning the parent repo (with submodule)

```bash
git clone --recursive git@github.com:donphi/luddite-loop.git
```

The `--recursive` flag tells git to also clone all submodules. Without it, you get the parent repo but the `notes/` folder will be empty.

If already cloned without `--recursive`:

```bash
git submodule update --init --recursive
```

This initializes and fetches all submodules after the fact. The `--init` registers submodules defined in `.gitmodules`, and `--recursive` handles any nested submodules (submodules within submodules). Even if you don't have nested submodules now, it's good practice to include it.

### Pulling submodule updates

If this repo was updated elsewhere:

```bash
cd luddite-loop/
git submodule update --remote notes
```

---

## Notion to Markdown Exporter

Automatically scan and export all Notion pages to Markdown with Docker.

### Features

- **Automatic page discovery** — Scans a parent page and finds all child pages
- **Auto .env update** — Automatically updates your .env file with discovered page IDs
- **Live development** — Change your Python/JS files and they're instantly reflected in Docker
- **One-command export** — Single script to scan and export everything

---

### Quick Start

#### 1. Setup your .env file

Create a `.env` file with your Notion integration token and parent page ID:

```
NOTION_TOKEN=your_integration_token_here
NOTION_PAGE_ID=parent_page_id_to_scan
```

Get your integration token from: https://www.notion.so/my-integrations

#### 2. Run the automatic scanner & exporter

```bash
./run.sh
```

This will:
1. Build the Docker image
2. Scan your parent page for all child pages
3. Automatically update your .env with all found page IDs
4. Export all pages to markdown in the `output/` directory

---

### How It Works

#### File Structure

| File | Purpose |
|------|---------|
| `run.sh` | Main script that runs everything automatically |
| `get_page_ids.py` | Scans Notion for page IDs and updates .env |
| `export_notion.py` | Exports pages to markdown |
| `docker-compose.yml` | Docker setup with live file mounting |
| `output/` | Where your markdown files are saved |

#### Live Development

All source files are mounted as volumes in Docker, so you can edit:
- `get_page_ids.py`
- `export_notion.py`
- `notion_export.js`
- `get_page_ids.js`

Changes are reflected immediately without rebuilding.

---

### Manual Commands

Run steps individually if needed:

```bash
# Just scan for page IDs
docker-compose run --rm notion-export python get_page_ids.py

# Just export (after .env has page IDs)
docker-compose run --rm notion-export python export_notion.py

# Build the Docker image
docker-compose build
```

---

### Environment Variables

| Variable | Description |
|----------|-------------|
| `NOTION_TOKEN` | Your Notion integration token (required) |
| `NOTION_PAGE_ID` | Parent page ID to scan from (required for scanning) |
| `NOTION_PAGE_IDS` | Comma-separated list of page IDs (auto-populated) |
| `SEPARATE_CHILD_PAGES` | Save child pages as separate files (default: true) |
| `RECURSIVE` | Scan child pages recursively (default: true) |
| `AUTO_EXPORT` | Auto-export after scanning (default: false) |

---

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Permission denied on run.sh | Run `chmod +x run.sh` |
| Docker not found | Install Docker and Docker Compose |
| Page scan fails | Make sure your integration has access to the pages |
| No output files | Check Docker logs with `docker-compose logs` |