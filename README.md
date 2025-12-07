# Notion to Markdown Exporter 🚀

Automatically scan and export all Notion pages to Markdown with Docker!

## Features ✨

- **Automatic page discovery**: Scans a parent page and finds all child pages
- **Auto .env update**: Automatically updates your .env file with discovered page IDs
- **Live development**: Change your Python/JS files and they're instantly reflected in Docker
- **One-command export**: Single script to scan and export everything

## Quick Start 🏃‍♂️

### 1. Setup your .env file

Create a `.env` file with your Notion integration token and parent page ID:

```bash
NOTION_TOKEN=your_integration_token_here
NOTION_PAGE_ID=parent_page_id_to_scan
```

Get your integration token from: https://www.notion.so/my-integrations

### 2. Run the automatic scanner & exporter

```bash
./run.sh
```

That's it! This will:
1. Build the Docker image
2. Scan your parent page for all child pages
3. Automatically update your .env with all found page IDs
4. Export all pages to markdown in the `output/` directory

## How It Works 🔧

### File Structure
- `run.sh` - Main script that runs everything automatically
- `get_page_ids.py` - Scans Notion for page IDs and updates .env
- `export_notion.py` - Exports pages to markdown
- `docker-compose.yml` - Docker setup with live file mounting
- `output/` - Where your markdown files are saved

### Live Development
All source files are mounted as volumes in Docker, so you can edit:
- `get_page_ids.py`
- `export_notion.py`
- `notion_export.js`
- `get_page_ids.js`

Changes are reflected immediately without rebuilding!

## Manual Commands 🛠️

If you want to run steps individually:

### Just scan for page IDs:
```bash
docker-compose run --rm notion-export python get_page_ids.py
```

### Just export (after .env has page IDs):
```bash
docker-compose run --rm notion-export python export_notion.py
```

### Build the Docker image:
```bash
docker-compose build
```

## Environment Variables 📝

- `NOTION_TOKEN` - Your Notion integration token (required)
- `NOTION_PAGE_ID` - Parent page ID to scan from (required for scanning)
- `NOTION_PAGE_IDS` - Comma-separated list of page IDs (auto-populated)
- `SEPARATE_CHILD_PAGES` - Save child pages as separate files (default: true)
- `RECURSIVE` - Scan child pages recursively (default: true)
- `AUTO_EXPORT` - Auto-export after scanning (default: false)

## Troubleshooting 🔍

1. **Permission denied on run.sh**: Run `chmod +x run.sh`
2. **Docker not found**: Install Docker and Docker Compose
3. **Page scan fails**: Make sure your integration has access to the pages
4. **No output files**: Check Docker logs with `docker-compose logs`

## That's It! 🎉

Now you can easily export all your Notion pages to markdown with a single command!