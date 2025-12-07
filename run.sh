#!/bin/bash

# Simple script to automatically scan for page IDs and export all Notion pages
# Uses docker-compose for easy management with live file mounting

sudo rm -rf output

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🚀 Notion Auto Scanner & Exporter${NC}"
echo -e "${GREEN}========================================${NC}"
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
echo -e "${BLUE}🔍 STEP 1: Scanning for page IDs...${NC}"
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

# Step 2: Export pages and dynamically create folder structure
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}📥 STEP 2: Exporting pages with custom formatting...${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Export using notion-to-md with custom formatting for each database
$DOCKER_COMPOSE run --rm notion-export node -e "
const { Client } = require('@notionhq/client');
const { NotionToMarkdown } = require('notion-to-md');
const fs = require('fs').promises;
const path = require('path');

const notion = new Client({ auth: '$NOTION_TOKEN' });
const n2m = new NotionToMarkdown({
  notionClient: notion,
  config: {
    separateChildPage: true,
    parseChildPages: true
  }
});

// Custom transformers to ensure images are preserved
n2m.setCustomTransformer('image', async (block) => {
  const imageUrl = block.image?.file?.url || block.image?.external?.url || '';
  const caption = block.image?.caption?.map(t => t.plain_text).join('') || '';
  
  if (imageUrl) {
    return caption ? \`![\${caption}](\${imageUrl})\\n*\${caption}*\` : \`![](\${imageUrl})\`;
  }
  return '';
});

// Ensure emojis in all text blocks are preserved with proper Unicode handling
n2m.setCustomTransformer('paragraph', async (block) => {
  const text = block.paragraph?.rich_text?.map(t => {
    // Ensure proper emoji and Unicode handling
    return t.plain_text ? String(t.plain_text).normalize('NFC') : '';
  }).join('') || '';
  return text + '\\n';
});

// Custom transformer for handling database property emojis
n2m.setCustomTransformer('callout', async (block) => {
  const icon = block.callout?.icon?.emoji || '';
  const text = block.callout?.rich_text?.map(t => String(t.plain_text || '').normalize('NFC')).join('') || '';
  return icon ? \`\${icon} \${text}\\n\` : text + '\\n';
});

// Build a lookup table for all pages
const pageIdToTitle = {};

async function buildPageLookup(pageIds) {
  for (const pageId of pageIds) {
    try {
      const cleanId = pageId.replace(/-/g, '');
      const page = await notion.pages.retrieve({ page_id: cleanId });
      
      let title = 'Untitled';
      for (const [key, value] of Object.entries(page.properties)) {
        if (value.type === 'title' && value.title?.[0]?.plain_text) {
          title = value.title[0].plain_text;
          break;
        }
      }
      pageIdToTitle[cleanId] = title;
    } catch (e) {
      // Ignore lookup errors
    }
  }
}

// Format property value based on type
function formatPropertyValue(property) {
  switch (property.type) {
    case 'title':
      return property.title.map(t => t.plain_text || '').join('');
    case 'rich_text':
      return property.rich_text.map(t => t.plain_text || '').join('');
    case 'number':
      return property.number ? property.number.toString() : '';
    case 'select':
      // Preserve emojis in select options - ensure proper UTF-8 handling
      if (property.select && property.select.name) {
        // Convert to ensure proper emoji handling
        return String(property.select.name);
      }
      return '';
    case 'multi_select':
      // Preserve emojis in multi-select options - ensure proper UTF-8 handling
      if (property.multi_select && Array.isArray(property.multi_select)) {
        return property.multi_select.map(s => String(s.name || '')).join(', ');
      }
      return '';
    case 'date':
      if (property.date) {
        const start = property.date.start;
        const end = property.date.end;
        return end ? \`\${start} → \${end}\` : start;
      }
      return '';
    case 'checkbox':
      return property.checkbox ? '✓' : '✗';
    case 'url':
      return property.url || '';
    case 'email':
      return property.email || '';
    case 'phone_number':
      return property.phone_number || '';
    case 'files':
      return property.files.map(f => f.name).join(', ');
    case 'formula':
      if (property.formula) {
        switch (property.formula.type) {
          case 'string': return property.formula.string || '';
          case 'number': return property.formula.number ? property.formula.number.toString() : '';
          case 'boolean': return property.formula.boolean ? 'true' : 'false';
          case 'date': return property.formula.date ? property.formula.date.start : '';
        }
      }
      return '';
    case 'relation':
      // Try to resolve relation IDs to page titles
      return property.relation.map(r => {
        const cleanId = r.id.replace(/-/g, '');
        const title = pageIdToTitle[cleanId];
        // If we found a title, use it; otherwise show the ID with a note
        return title || \`[Page: \${r.id}]\`;
      }).join(', ');
    case 'rollup':
      if (property.rollup) {
        switch (property.rollup.type) {
          case 'number': return property.rollup.number ? property.rollup.number.toString() : '';
          case 'array': return 'Array';
        }
      }
      return '';
    case 'people':
      return property.people.map(p => p.name || p.person?.email || 'Unknown').join(', ');
    case 'created_time':
      return property.created_time;
    case 'created_by':
      return property.created_by.name || property.created_by.person?.email || 'Unknown';
    case 'last_edited_time':
      return property.last_edited_time;
    case 'last_edited_by':
      return property.last_edited_by.name || property.last_edited_by.person?.email || 'Unknown';
    default:
      return '';
  }
}

// Get ALL databases in the workspace dynamically
async function getAllDatabases() {
  console.log('🔍 Discovering ALL databases in your Notion workspace...');
  const databases = {};
  
  try {
    // Search for all databases in the workspace
    const response = await notion.search({
      filter: {
        property: 'object',
        value: 'database'
      },
      page_size: 100
    });
    
    // Map each database by its ID
    for (const db of response.results) {
      const title = db.title[0]?.plain_text || 'Untitled Database';
      databases[db.id] = title;
      console.log(\`   Found database: \${title} (ID: \${db.id})\`);
    }
    
    console.log(\`\\n📊 Found \${Object.keys(databases).length} databases total\\n\`);
  } catch (error) {
    console.log('   ⚠️ Could not get databases:', error.message);
  }
  
  return databases;
}

// Get page info including parent database and all properties
async function getPageInfo(pageId) {
  try {
    const page = await notion.pages.retrieve({ page_id: pageId });
    
    // Get title
    let title = 'Untitled';
    const properties = {};
    const propertyOrder = []; // Track the order of properties
    
    // Preserve the order of properties as they appear in the API response
    for (const [key, value] of Object.entries(page.properties)) {
      propertyOrder.push(key);
      if (value.type === 'title' && value.title?.[0]?.plain_text) {
        title = value.title[0].plain_text;
      }
      // Store all properties for database items
      properties[key] = formatPropertyValue(value);
    }
    
    // Get parent database ID if it exists
    const parentId = page.parent.database_id || page.parent.page_id || null;
    
    // If this is a database item, try to get the database schema to determine property order
    let databasePropertyOrder = [];
    if (parentId && page.parent.type === 'database_id') {
      try {
        const database = await notion.databases.retrieve({ database_id: parentId });
        // The order of properties in the database.properties object reflects the order in the UI
        databasePropertyOrder = Object.keys(database.properties);
      } catch (e) {
        console.log(`Could not retrieve database schema for ${parentId}: ${e.message}`);
        // Fall back to the order from the page properties
        databasePropertyOrder = propertyOrder;
      }
    } else {
      databasePropertyOrder = propertyOrder;
    }
    
    return {
      title,
      parentId,
      parentType: page.parent.type,
      properties,
      propertyOrder: databasePropertyOrder,
      fullPage: page
    };
  } catch {
    return { title: 'Untitled', parentId: null, parentType: null, properties: {} };
  }
}

// Generic formatting for ALL database entries
function formatDatabaseProperties(dbName, pageInfo, entryNumber) {
  // Clean up database name to remove numbering
  const cleanDbName = dbName.replace(/^\\d+\\.\\s*/, '');
  
  // Determine the entry label based on database name patterns
  let entryLabel = 'Entry';
  if (cleanDbName.includes('Meeting')) {
    entryLabel = 'Meeting';
  } else if (cleanDbName.includes('Paper') || cleanDbName.includes('Literature')) {
    entryLabel = 'Paper';
  } else if (cleanDbName.includes('Issue')) {
    entryLabel = 'Issue';
  } else if (cleanDbName.includes('Implementation')) {
    entryLabel = 'Implementation';
  } else if (cleanDbName.includes('Week')) {
    entryLabel = 'Week';
  }
  
  // Use Nr property if available, otherwise use entryNumber
  const entryNum = pageInfo.properties['Nr'] || pageInfo.properties['#'] || entryNumber;
  
  // Create header
  let header = \`## \${cleanDbName} — \${entryLabel} \${entryNum}: \${pageInfo.title}\\n\\n\`;
  
  // Use the dynamic property order from the database if available
  const propertyOrder = pageInfo.propertyOrder || [];
  
  // Sort properties using the database's property order
  const sortedProperties = Object.entries(pageInfo.properties)
    .filter(([key, value]) => value && key !== pageInfo.title)
    .sort(([keyA], [keyB]) => {
      const indexA = propertyOrder.indexOf(keyA);
      const indexB = propertyOrder.indexOf(keyB);
      
      // If both keys are in the property order, sort by their position
      if (indexA !== -1 && indexB !== -1) {
        return indexA - indexB;
      }
      // If only keyA is in the property order, it comes first
      else if (indexA !== -1) {
        return -1;
      }
      // If only keyB is in the property order, it comes first
      else if (indexB !== -1) {
        return 1;
      }
      // If neither key is in the property order, sort alphabetically
      else {
        return keyA.localeCompare(keyB);
      }
    });
  
  // Add ALL properties in the sorted order
  let propertiesText = '';
  for (const [key, value] of sortedProperties) {
    // Convert to string and ensure proper UTF-8 handling - normalize Unicode
    const strValue = String(value).normalize('NFC');
    
    // Special formatting for certain property types
    if ((key === 'Entry' || key === 'Summary' || key === 'Description' || key === 'Notes') && strValue.length > 50) {
      propertiesText += \`**\${key}:**  \\n\${strValue}  \\n\\n\`;
    } else if (key.includes('Related') || key.includes('References')) {
      // Format relations as bullet points
      const items = strValue.split(',').map(v => v.trim()).filter(v => v);
      if (items.length > 0) {
        propertiesText += \`**\${key}:**  \\n\`;
        items.forEach(item => {
          propertiesText += \`- \${item}  \\n\`;
        });
        propertiesText += '\\n';
      }
    } else {
      propertiesText += \`**\${key}:** \${strValue}  \\n\`;
    }
  }
  
  return header + propertiesText;
}

// Create markdown content with custom formatting
async function createCustomMarkdown(pageId, pageInfo, dbName, entryNumber) {
  let content = '';
  
  // Add custom formatted properties for database items
  if (pageInfo.parentType === 'database_id' && dbName) {
    content = formatDatabaseProperties(dbName, pageInfo, entryNumber);
  } else {
    // For non-database pages, just use the title
    content = \`# \${pageInfo.title}\\n\\n\`;
  }
  
  // Add page content
  content += '\\n## Content\\n\\n';
  
  try {
    // Get the page content using notion-to-md
    const mdblocks = await n2m.pageToMarkdown(pageId);
    const mdString = n2m.toMarkdownString(mdblocks);
    
    if (mdString.parent) {
      // The parent string includes all content with images and emojis preserved
      content += mdString.parent;
      
      // If there are child pages, add them too
      if (mdString.children && mdString.children.length > 0) {
        content += '\\n\\n### Related Pages\\n\\n';
        for (const child of mdString.children) {
          content += \`- \${child}\\n\`;
        }
      }
    } else {
      content += '*No content available*';
    }
  } catch (error) {
    content += \`*Error retrieving content: \${error.message}*\`;
  }
  
  return content;
}

// Create database overview table with ALL columns dynamically
// Uses the database's property order for consistent column ordering
async function createDatabaseOverview(dbName, pages) {
  const cleanDbName = dbName.replace(/^\\d+\\.\\s*/, '');
  let content = \`# \${dbName} - Overview\\n\\n\`;
  content += \`Total Entries: \${pages.length}\\n\\n\`;
  
  if (pages.length === 0) {
    content += '*No entries in this database*\\n';
    return content;
  }
  
  // Collect all unique property keys across all pages
  const allProperties = new Set();
  allProperties.add('#'); // Always add entry number
  
  // Get the property order from the first page that has it
  let databasePropertyOrder = [];
  for (const { info } of pages) {
    if (info.propertyOrder && info.propertyOrder.length > 0) {
      databasePropertyOrder = info.propertyOrder;
      break;
    }
  }
  
  // Collect all properties
  for (const { info } of pages) {
    for (const key of Object.keys(info.properties)) {
      if (key && key !== info.title) {
        allProperties.add(key);
      }
    }
  }
  
  const propertyArray = Array.from(allProperties);
  
  // Sort properties using the database's property order
  propertyArray.sort((a, b) => {
    // Always put # first
    if (a === '#') return -1;
    if (b === '#') return 1;
    
    const aIndex = databasePropertyOrder.indexOf(a);
    const bIndex = databasePropertyOrder.indexOf(b);
    
    // If both keys are in the property order, sort by their position
    if (aIndex !== -1 && bIndex !== -1) {
      return aIndex - bIndex;
    }
    // If only keyA is in the property order, it comes first
    else if (aIndex !== -1) {
      return -1;
    }
    // If only keyB is in the property order, it comes first
    else if (bIndex !== -1) {
      return 1;
    }
    // If neither key is in the property order, sort alphabetically
    else {
      return a.localeCompare(b);
    }
  });
  
  // Build table header
  let tableHeader = '|';
  let tableSeparator = '|';
  
  for (const prop of propertyArray) {
    if (prop === '#') {
      tableHeader += ' # |';
      tableSeparator += '---|';
    } else {
      tableHeader += \` \${prop} |\`;
      tableSeparator += '---|';
    }
  }
  
  tableHeader += '\\n';
  tableSeparator += '\\n';
  
  content += tableHeader;
  content += tableSeparator;
  
  // Add rows
  let counter = 0;
  for (const { info } of pages) {
    counter++;
    let row = '|';
    
    for (const prop of propertyArray) {
      if (prop === '#') {
        row += \` \${counter} |\`;
      } else {
        const value = info.properties[prop] || '';
        // Remove newlines but preserve emojis - normalize Unicode for proper emoji handling
        let cleanValue = String(value)
          .normalize('NFC')  // Normalize Unicode to handle composite characters and emojis
          .replace(/\\n+/g, ' ')  // Replace newlines with spaces
          .replace(/\\s+/g, ' ')  // Replace multiple spaces with single space
          .replace(/^#+\\s*/g, '') // Remove markdown headers only at start
          .trim();
        
        // Preserve emojis while truncating long values for the table
        let displayValue = cleanValue;
        if (cleanValue.length > 50) {
          // Truncate but try to avoid breaking emojis
          displayValue = cleanValue.substring(0, 47);
          // Check if we might have broken an emoji at the end
          const lastChar = displayValue.charCodeAt(displayValue.length - 1);
          if (lastChar >= 0xD800 && lastChar <= 0xDBFF) {
            // High surrogate, we might have split an emoji
            displayValue = displayValue.substring(0, displayValue.length - 1);
          }
          displayValue += '...';
        }
        // Escape pipe characters but preserve all Unicode including emojis
        const escapedValue = displayValue.replace(/\\|/g, '\\\\|');
        row += \` \${escapedValue} |\`;
      }
    }
    
    content += row + '\\n';
  }
  
  return content;
}

// Group pages by database for proper ordering
async function groupPagesByDatabase(pageIds) {
  const grouped = {};
  const standalone = [];
  
  for (const pageId of pageIds) {
    const cleanId = pageId.replace(/-/g, '');
    const pageInfo = await getPageInfo(cleanId);
    
    if (pageInfo.parentType === 'database_id' && pageInfo.parentId) {
      if (!grouped[pageInfo.parentId]) {
        grouped[pageInfo.parentId] = [];
      }
      grouped[pageInfo.parentId].push({ id: cleanId, info: pageInfo });
    } else {
      standalone.push({ id: cleanId, info: pageInfo });
    }
  }
  
  return { grouped, standalone };
}

async function exportAll() {
  // First build the page lookup for relations
  const pageIds = '$NOTION_PAGE_IDS'.split(',').map(id => id.trim());
  console.log('Building complete page lookup for relations...');
  await buildPageLookup(pageIds);
  console.log(\`   Found \${Object.keys(pageIdToTitle).length} pages for lookup\\n\`);
  
  // Get ALL databases in the workspace
  const databases = await getAllDatabases();
  
  // Create base folders - use the mounted volume path
  const outputBase = '/app/output';
  await fs.mkdir(outputBase, { recursive: true });
  console.log('📁 Creating folder structure dynamically based on your Notion workspace...\\n');
  
  console.log(\`📥 Grouping and exporting \${pageIds.length} pages...\\n\`);
  
  // Group pages by database for proper ordering
  const { grouped, standalone } = await groupPagesByDatabase(pageIds);
  
  let processed = 0;
  const createdFolders = new Set();
  const databaseOverviews = {};
  
  // Process database pages (grouped)
  for (const [dbId, pages] of Object.entries(grouped)) {
    const dbName = databases[dbId] || 'Unknown Database';
    const folderPath = path.join(outputBase, dbName);
    
    // Create folder if it doesn't exist
    if (!createdFolders.has(folderPath)) {
      await fs.mkdir(folderPath, { recursive: true });
      createdFolders.add(folderPath);
      console.log(\`   📁 Created folder: \${dbName}\`);
    }
    
    // Sort pages to match Notion's default view order
    const sortedPages = [...pages].sort((a, b) => {
      // Try to sort by Nr or # property first
      const aNr = a.info.properties['Nr'] || a.info.properties['#'];
      const bNr = b.info.properties['Nr'] || b.info.properties['#'];
      
      if (aNr !== undefined && bNr !== undefined) {
        // Convert to numbers if possible
        const aNum = parseInt(aNr);
        const bNum = parseInt(bNr);
        if (!isNaN(aNum) && !isNaN(bNum)) {
          return aNum - bNum;
        }
      }
      
      // Fall back to title alphabetical sorting
      return a.info.title.localeCompare(b.info.title);
    });
    
    // Store sorted pages for overview
    databaseOverviews[dbName] = sortedPages;
    
    // Process pages in sorted order
    let counter = 0;
    for (const { id, info } of sortedPages) {
      processed++;
      counter++;
      
      try {
        console.log(\`[\${processed}/\${pageIds.length}] Exporting: \${info.title}\`);
        
        // Generate numbered filename
        const filename = \`\${counter.toString().padStart(2, '0')}. \${info.title}.md\`
          .replace(/[^a-zA-Z0-9 .-]/g, '')
          .trim();
        
        const outputPath = path.join(folderPath, filename);
        
        // Create custom formatted markdown
        const content = await createCustomMarkdown(id, info, dbName, counter);
        
        // Save the content with explicit UTF-8 encoding to preserve emojis
        await fs.writeFile(outputPath, content, 'utf8');
        
        console.log(\`   ✅ Saved to: \${dbName}/\${filename}\`);
        console.log(\`      Properties: \${Object.keys(info.properties).length} fields\`);
      } catch (error) {
        console.log(\`   ❌ Failed: \${error.message}\`);
      }
    }
    
    // Create overview table for this database
    if (sortedPages.length > 0) {
      const overviewContent = await createDatabaseOverview(dbName, sortedPages);
      const overviewPath = path.join(folderPath, '_Overview.md');
      // Write with UTF-8 encoding to preserve emojis
      await fs.writeFile(overviewPath, overviewContent, 'utf8');
      console.log(\`   📊 Created overview: \${dbName}/_Overview.md\`);
    }
  }
  
  // Sort standalone pages by title
  const sortedStandalone = [...standalone].sort((a, b) =>
    a.info.title.localeCompare(b.info.title)
  );
  
  // Process standalone pages
  let standaloneCounter = 0;
  for (const { id, info } of sortedStandalone) {
    processed++;
    standaloneCounter++;
    
    try {
      console.log(\`[\${processed}/\${pageIds.length}] Exporting: \${info.title}\`);
      
      // Generate numbered filename
      const filename = \`\${standaloneCounter.toString().padStart(2, '0')}. \${info.title}.md\`
        .replace(/[^a-zA-Z0-9 .-]/g, '')
        .trim();
      
      const outputPath = path.join(outputBase, filename);
      
      // Create custom formatted markdown
      const content = await createCustomMarkdown(id, info, null, standaloneCounter);
      
      // Save the content with explicit UTF-8 encoding to preserve emojis
      await fs.writeFile(outputPath, content, 'utf8');
      
      console.log(\`   ✅ Saved to: \${filename}\`);
    } catch (error) {
      console.log(\`   ❌ Failed: \${error.message}\`);
    }
  }
  
  console.log(\`\\n✅ Exported \${processed} pages with custom formatting!\`);
  console.log('\\n📊 Folder structure created:');
  
  // List the created structure
  for (const folder of createdFolders) {
    const folderName = path.basename(folder);
    console.log(\`   📁 \${folderName}/ (with _Overview.md)\`);
  }
}

exportAll().catch(console.error);
"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✨ ALL DONE! Export complete!${NC}"
    echo -e "${GREEN}📁 Check the output/ directory${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    echo ""
    echo -e "${GREEN}📊 Your Notion structure has been dynamically organized!${NC}"
    echo ""
    echo "The folder structure was created based on your actual Notion databases."
    echo "Each database has its own folder with all its pages inside."
    
    # Count exported files and show structure
    FILE_COUNT=$(find output -name "*.md" 2>/dev/null | wc -l)
    if [ $FILE_COUNT -gt 0 ]; then
        echo ""
        echo -e "${GREEN}📊 Successfully exported $FILE_COUNT markdown files${NC}"
        echo ""
        echo "Folder structure created:"
        ls -la output/ | head -15
    else
        echo ""
        echo -e "${YELLOW}⚠️ No files found in output/ directory yet${NC}"
        echo "Files may still be processing inside the container..."
    fi
else
    echo -e "${RED}❌ Export failed!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}💡 Tips:${NC}"
echo "  • Your code changes are automatically reflected (live mounting)"
echo "  • Run '$DOCKER_COMPOSE run --rm notion-export python get_page_ids.py' to re-scan"
echo "  • Run '$DOCKER_COMPOSE run --rm notion-export python export_notion.py' to re-export"
echo "  • Or just run './run.sh' again to do both!"