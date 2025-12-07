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

---

## Notion to Markdown Exporter

Automatically scan and export all Notion pages to Markdown with Docker.

### Features

- **Automatic page discovery** — Scans a parent page and finds all child pages
- **Auto .env update** — Automatically updates your .env file with discovered page IDs
- **Live development** — Change your Python/JS files and they're instantly reflected in Docker
- **One-command export** — Single script to scan and export everything
- **Rate limit handling** — Automatic retries with exponential backoff
- **Export tracking** — Metadata and history for each export run
- **Unified CLI** — Single command-line interface for all operations

### Package Versions

| Package | Version | Notes |
|---------|---------|-------|
| `@notionhq/client` | `^5.4.0` | Notion SDK v5.x |
| `notion-to-md` | `^3.1.2` | Stable markdown converter |
| Node.js | `20.x LTS` | In Docker |
| Python | `3.12` | In Docker |
| **API Version** | `2025-09-03` | Multi-source databases support |

### API 2025-09-03 Compliance

This exporter is updated for Notion API version `2025-09-03` which introduces:

- **Multi-source databases**: A database can now contain multiple data sources
- **New endpoints**: `dataSources.query()` replaces `databases.query()` for querying
- **New parent types**: Pages can have `data_source_id` parents
- **Search changes**: Filter uses `data_source` instead of `database`

The code includes fallbacks for backwards compatibility with older API versions.

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

**Option A: Using the shell script (recommended)**
```bash
./run.sh              # Cleans output/, then scans + exports (default)
./run.sh --no-clean   # Keeps existing files, only updates/adds
```

**Option B: Using the Python CLI**
```bash
python notion_cli.py full          # Scan + Export
python notion_cli.py full --clean  # Clean output first, then scan + export
```

This will:
1. Build the Docker image
2. Scan your parent page for all child pages
3. Automatically update your .env with all found page IDs
4. Export all pages to markdown in the `output/` directory

---

### CLI Commands

The `notion_cli.py` provides a unified interface:

```bash
# Scan for page IDs only
python notion_cli.py scan

# Export pages to markdown
python notion_cli.py export
python notion_cli.py export --clean        # Delete output/ first, then export
python notion_cli.py export --scan-first   # Scan for new pages before export

# Full workflow (scan + export)
python notion_cli.py full
python notion_cli.py full --clean          # Fresh export: delete output/, scan, export

# Check export status and history
python notion_cli.py status

# Clean output directory
python notion_cli.py clean                 # Delete all files in output/ (with confirmation)
python notion_cli.py clean --yes           # Delete without confirmation prompt
```

#### What does `--clean` do?

The `--clean` flag **deletes the entire `output/` directory** before running the export. This ensures you get a fresh export without any stale files from previous runs.

**When to use `--clean`:**
- After reorganizing pages in Notion
- When pages have been deleted in Notion
- To remove orphaned/renamed files
- For a guaranteed fresh start

**Without `--clean`:** Existing files are overwritten, but deleted/renamed pages in Notion will leave orphan files behind.

---

### How It Works

#### File Structure

| File | Purpose |
|------|---------|
| `run.sh` | Main script that runs everything automatically |
| `notion_cli.py` | Unified CLI for all operations |
| `get_page_ids.py` | Scans Notion for page IDs and updates .env |
| `export_notion.py` | Exports pages to markdown |
| `notion_utils.js` | Shared utilities (retry logic, rate limiting) |
| `notion_export.js` | Node.js markdown converter |
| `get_page_ids.js` | Node.js page scanner |
| `docker-compose.yml` | Docker setup with live file mounting |
| `output/` | Where your markdown files are saved |

#### Live Development

All source files are mounted as volumes in Docker, so you can edit:
- `get_page_ids.py`
- `export_notion.py`
- `notion_export.js`
- `get_page_ids.js`
- `notion_utils.js`

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

# Rebuild from scratch (after package updates)
docker-compose build --no-cache
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
| `OUTPUT_DIR` | Output directory for markdown files |

---

### Export Metadata

Each export creates a `.export_metadata.json` file in the output directory with:
- Last export timestamp
- Number of pages exported
- Export history (last 10 runs)

Check status with:
```bash
python notion_cli.py status
```

---

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Permission denied on run.sh | Run `chmod +x run.sh` |
| Docker not found | Install Docker and Docker Compose |
| Page scan fails | Make sure your integration has access to the pages |
| No output files | Check Docker logs with `docker-compose logs` |
| Rate limiting | Built-in retry with backoff handles this automatically |
| Timeout errors | Large pages may need more time; CLI has 10min timeout |

### After Updating Packages

If you've updated `package.json`, rebuild the Docker image:

```bash
docker-compose build --no-cache
```
