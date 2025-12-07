#!/bin/bash

# Script to scan and export Notion pages with hierarchical structure preservation
# This maintains the parent-child relationships and database structure

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}========================================${NC}"
echo -e "${PURPLE}🏗️  Notion Hierarchical Scanner & Exporter${NC}"
echo -e "${PURPLE}========================================${NC}"
echo ""
echo -e "${BLUE}This will preserve your Notion structure:${NC}"
echo "  • Parent-child page relationships"
echo "  • Database pages marked with 📊"
echo "  • Nested folder structure matching Notion"
echo "  • Index file for easy navigation"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ Error: .env file not found!${NC}"
    echo ""
    echo "Please create a .env file with at minimum:"
    echo "  NOTION_TOKEN=your_integration_token_here"
    echo "  NOTION_PAGE_ID=parent_page_id_to_scan"
    echo ""
    echo "Get your token from: https://www.notion.so/my-integrations"
    exit 1
fi

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

# Check for required variables
if [ -z "$NOTION_TOKEN" ]; then
    echo -e "${RED}❌ Error: NOTION_TOKEN not found in .env file!${NC}"
    exit 1
fi

if [ -z "$NOTION_PAGE_ID" ] && [ -z "$NOTION_PAGE_IDS" ]; then
    echo -e "${RED}❌ Error: NOTION_PAGE_ID not found in .env file!${NC}"
    echo "This is needed as the parent page to scan for all child pages."
    exit 1
fi

# Detect if we should use 'docker compose' or 'docker-compose'
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    echo -e "${RED}❌ Error: Docker Compose not found!${NC}"
    echo "Please install Docker and Docker Compose"
    exit 1
fi

echo -e "${BLUE}Using: $DOCKER_COMPOSE${NC}"
echo ""

# Build the Docker image
echo -e "${YELLOW}📦 Building Docker image...${NC}"
$DOCKER_COMPOSE build

echo -e "${GREEN}✅ Docker image ready${NC}"
echo ""

# Step 1: Scan for all page IDs and automatically update .env
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔍 STEP 1: Scanning page hierarchy...${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

$DOCKER_COMPOSE run --rm notion-export python get_page_ids.py

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Page scan failed!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Page scan complete! Your .env file has been updated with all page IDs.${NC}"
echo ""

# Reload environment variables to get the updated NOTION_PAGE_IDS
export $(cat .env | grep -v '^#' | xargs)

# Step 2: Export all pages with hierarchical structure
echo -e "${PURPLE}========================================${NC}"
echo -e "${PURPLE}🏗️  STEP 2: Exporting with hierarchical structure...${NC}"
echo -e "${PURPLE}========================================${NC}"
echo ""

# Mount the new hierarchical exporter
$DOCKER_COMPOSE run --rm \
    -v "$(pwd)/export_notion_hierarchical.py":/app/export_notion_hierarchical.py:ro \
    notion-export python export_notion_hierarchical.py

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✨ ALL DONE! Hierarchical export complete!${NC}"
    echo -e "${GREEN}📁 Check the output/ directory${NC}"
    echo -e "${GREEN}📑 Open output/INDEX.md for navigation${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # Show structure preview
    if [ -f output/INDEX.md ]; then
        echo ""
        echo -e "${PURPLE}📊 Structure Preview:${NC}"
        head -20 output/INDEX.md | tail -15
        echo "..."
    fi
    
    # Count exported files
    FILE_COUNT=$(find output -name "*.md" 2>/dev/null | wc -l)
    if [ $FILE_COUNT -gt 0 ]; then
        echo ""
        echo -e "${GREEN}📊 Successfully exported $FILE_COUNT markdown files${NC}"
    fi
else
    echo -e "${RED}❌ Export failed!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}💡 Tips:${NC}"
echo "  • Your Notion structure is preserved in nested folders"
echo "  • Database pages are prefixed with 📊_"
echo "  • Each folder has a README.md for GitHub compatibility"
echo "  • Check output/INDEX.md for the complete structure"
echo "  • Run './run.sh' for simple flat export"
echo "  • Run './run_hierarchical.sh' for structured export"