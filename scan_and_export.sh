#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🔍 Notion Page Scanner & Exporter${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env file not found!${NC}"
    echo "Please create a .env file with:"
    echo "  NOTION_TOKEN=your_token_here"
    echo "  NOTION_PAGE_ID=parent_page_id_here"
    exit 1
fi

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

# Step 1: Scan for all page IDs
echo -e "${YELLOW}Step 1: Scanning for all page IDs...${NC}"
docker run --rm \
    -v $(pwd):/app \
    -e NOTION_TOKEN="$NOTION_TOKEN" \
    -e NOTION_PAGE_ID="$NOTION_PAGE_ID" \
    -e RECURSIVE=true \
    notion-to-markdown \
    python get_page_ids.py

# Check if scan was successful
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Scan failed!${NC}"
    exit 1
fi

# Check if found_page_ids.txt exists
if [ ! -f found_page_ids.txt ]; then
    echo -e "${RED}❌ No page IDs found!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Scan complete! Page IDs saved to found_page_ids.txt${NC}"
echo ""

# Ask user if they want to export all pages
read -p "Do you want to export all found pages now? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Extract NOTION_PAGE_IDS from the file
    export NOTION_PAGE_IDS=$(grep "^NOTION_PAGE_IDS=" found_page_ids.txt | cut -d'=' -f2)
    
    if [ -z "$NOTION_PAGE_IDS" ]; then
        echo -e "${RED}❌ Could not extract page IDs!${NC}"
        exit 1
    fi
    
    # Count pages
    PAGE_COUNT=$(echo "$NOTION_PAGE_IDS" | tr ',' '\n' | wc -l)
    
    echo ""
    echo -e "${YELLOW}Step 2: Exporting $PAGE_COUNT pages...${NC}"
    echo ""
    
    # Run the export
    docker run --rm \
        -v $(pwd)/output:/app/output \
        -e NOTION_TOKEN="$NOTION_TOKEN" \
        -e NOTION_PAGE_IDS="$NOTION_PAGE_IDS" \
        -e SEPARATE_CHILD_PAGES=true \
        notion-to-markdown
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}✅ Export complete!${NC}"
        echo -e "${GREEN}📁 Check the output/ directory${NC}"
        echo -e "${GREEN}========================================${NC}"
    else
        echo -e "${RED}❌ Export failed!${NC}"
        exit 1
    fi
else
    echo ""
    echo -e "${YELLOW}Skipping export. Page IDs are saved in found_page_ids.txt${NC}"
    echo -e "${YELLOW}To export later, update your .env file with the NOTION_PAGE_IDS line from the file.${NC}"
fi