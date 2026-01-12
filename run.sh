#!/bin/bash

# Simple script to automatically scan for page IDs and export all Notion pages
# Uses docker-compose for easy management with live file mounting
#
# Usage:
#   ./run.sh           # Clean output and run full export (default)
#   ./run.sh --no-clean # Keep existing output, only update/add files

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

# Clean output directory unless --no-clean is passed
if [[ "$1" != "--no-clean" ]]; then
    if [ -d "output" ]; then
        echo -e "${YELLOW}🧹 Cleaning output directory...${NC}"
        rm -rf output 2>/dev/null || sudo rm -rf output  # Fallback to sudo if needed (old files)
        echo -e "${GREEN}✅ Output directory cleaned${NC}"
        echo ""
    fi
else
    echo -e "${BLUE}ℹ️  Keeping existing output (--no-clean)${NC}"
    echo ""
fi

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

# Export UID/GID so Docker runs as current user (files won't be owned by root)
export DOCKER_UID=$(id -u)
export DOCKER_GID=$(id -g)

# Create output directory on HOST with correct ownership before Docker mounts it
if [ ! -d "output" ]; then
    mkdir -p output
    echo -e "${GREEN}✅ Created output directory${NC}"
fi

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

const notion = new Client({ 
  auth: '$NOTION_TOKEN',
  notionVersion: '2025-09-03' // Required for @notionhq/client v5.x
});
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

// ---------- TABLES: deterministic HTML emitter (Pandoc-friendly) ----------
const DEBUG_TABLES = process.env.DEBUG_TABLES === '1' || process.env.DEBUG_TABLES === 'true';

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/\"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function renderRichTextPieceToHtml(rt) {
  if (!rt) return '';

  let text = '';
  if (rt.type === 'text') text = (rt.text && rt.text.content) ? rt.text.content : (rt.plain_text || '');
  else if (rt.type === 'equation') text = (rt.equation && rt.equation.expression) ? rt.equation.expression : (rt.plain_text || '');
  else text = rt.plain_text || '';

  let html = escapeHtml(text).replace(/\\n/g, '<br />');

  const href = rt.href;
  if (href) {
    html = '<a href=\"' + escapeHtml(href) + '\">' + html + '</a>';
  }

  const ann = rt.annotations || {};
  if (ann.code) html = '<code>' + html + '</code>';
  if (ann.bold) html = '<strong>' + html + '</strong>';
  if (ann.italic) html = '<em>' + html + '</em>';
  if (ann.strikethrough) html = '<del>' + html + '</del>';
  if (ann.underline) html = '<u>' + html + '</u>';

  return html;
}

function renderCellToHtml(cellRichTextArray) {
  const parts = Array.isArray(cellRichTextArray) ? cellRichTextArray : [];
  return parts.map(renderRichTextPieceToHtml).join('');
}

async function listAllChildren(blockId) {
  const out = [];
  let cursor = undefined;
  while (true) {
    const resp = await notion.blocks.children.list({
      block_id: blockId,
      page_size: 100,
      start_cursor: cursor,
    });
    out.push(...resp.results);
    if (!resp.has_more) break;
    cursor = resp.next_cursor;
  }
  return out;
}

// Override Notion "table" blocks: emit raw HTML table so Pandoc -> LaTeX is stable
n2m.setCustomTransformer('table', async (block) => {
  const rows = await listAllChildren(block.id);
  const firstRow = rows.find(r => r.type === 'table_row');
  if (DEBUG_TABLES && firstRow) {
    console.error('DEBUG_TABLE_BLOCK:', JSON.stringify({ id: block.id, table: block.table }, null, 2));
    console.error('DEBUG_TABLE_FIRST_ROW_JSON:', JSON.stringify(firstRow, null, 2));
  }

  const hasColHeader = !!(block.table && block.table.has_column_header);
  const hasRowHeader = !!(block.table && block.table.has_row_header);

  const parsedRows = rows
    .filter(r => r.type === 'table_row')
    .map(r => (r.table_row && r.table_row.cells ? r.table_row.cells : []).map(cell => renderCellToHtml(cell)));

  if (parsedRows.length === 0) return '';

  const maxCols = Math.max.apply(null, parsedRows.map(r => r.length));
  const norm = parsedRows.map(r => {
    const rr = r.slice();
    while (rr.length < maxCols) rr.push('');
    return rr;
  });

  const thead = hasColHeader ? norm[0] : null;
  const tbody = hasColHeader ? norm.slice(1) : norm;

  let html = '\\n<table>\\n';
  if (thead) {
    html += '  <thead>\\n    <tr>\\n';
    thead.forEach((c) => {
      html += '      <th>' + c + '</th>\\n';
    });
    html += '    </tr>\\n  </thead>\\n';
  }
  html += '  <tbody>\\n';
  tbody.forEach((r) => {
    html += '    <tr>\\n';
    r.forEach((c, j) => {
      if (hasRowHeader && j === 0) html += '      <th scope=\"row\">' + c + '</th>\\n';
      else html += '      <td>' + c + '</td>\\n';
    });
    html += '    </tr>\\n';
  });
  html += '  </tbody>\\n</table>\\n';
  return html;
});

// Prevent row blocks from being rendered separately (avoid duplicates)
n2m.setCustomTransformer('table_row', async () => '');

// ---------- CODE BLOCKS: preserve ASCII diagrams + optional bold/emojis ----------
function looksLikeAsciiDiagram(s) {
  const str = String(s || '');
  if (/[\u2500-\u257F\u2580-\u259F\u25A0-\u25FF\u2190-\u21FF\u2600-\u26FF\u2700-\u27BF]/u.test(str)) {
    return true;
  }
  return /(<==>|<->|==>|<==|->|<-|\|->|<-\\|)/.test(str);
}

function escapeLatexForFancyVerbatimCommandchars(s) {
  return String(s)
    .replace(/\\\\/g, '\\\\textbackslash{}')
    .replace(/\\{/g, '\\\\textbraceleft{}')
    .replace(/\\}/g, '\\\\textbraceright{}');
}

function renderRichTextArrayToPlainText(richTextArray) {
  const parts = Array.isArray(richTextArray) ? richTextArray : [];
  return parts.map(rt => String((rt && rt.plain_text) ? rt.plain_text : '').normalize('NFC')).join('');
}

function renderRichTextArrayToPandocDiagramBlocks(richTextArray) {
  const parts = Array.isArray(richTextArray) ? richTextArray : [];

  const htmlInner = parts.map(rt => {
    const text = String((rt && rt.plain_text) ? rt.plain_text : '').normalize('NFC');
    const escaped = escapeHtml(text);
    if (rt && rt.annotations && rt.annotations.bold) return '<strong>' + escaped + '</strong>';
    return escaped;
  }).join('');

  const latexInner = parts.map(rt => {
    const text = String((rt && rt.plain_text) ? rt.plain_text : '').normalize('NFC');
    const escaped = escapeLatexForFancyVerbatimCommandchars(text);
    if (rt && rt.annotations && rt.annotations.bold) return '\\\\textbf{' + escaped + '}';
    return escaped;
  }).join('');

  const htmlBlock = '<pre class=\"notion-ascii-diagram\"><code>' + htmlInner + '</code></pre>';
  const latexBlock =
'\\\\begin{Verbatim}[commandchars=\\\\\\\\\\\\{\\\\}]\\n' +
latexInner + '\\n' +
'\\\\end{Verbatim}';

  // IMPORTANT: this JS runs inside run.sh's node -e payload (bash double-quotes).
  // Use Pandoc's alternative fence ~~~ (avoid backticks).
  return '\\n\\n~~~{=html}\\n' + htmlBlock + '\\n~~~\\n\\n~~~{=latex}\\n' + latexBlock + '\\n~~~\\n\\n';
}

n2m.setCustomTransformer('code', async (block) => {
  const lang = ((block.code && block.code.language) ? block.code.language : '').toLowerCase();
  const rich = (block.code && block.code.rich_text) ? block.code.rich_text : [];
  const plain = renderRichTextArrayToPlainText(rich);

  const isDiagram = lang === 'plain text' || lang === 'text' || lang === 'plain' || looksLikeAsciiDiagram(plain);
  if (isDiagram) return renderRichTextArrayToPandocDiagramBlocks(rich);

  const fenceLang = lang && lang !== 'plain text' ? lang : '';
  const fence = fenceLang ? '~~~' + fenceLang : '~~~';
  return '\\n\\n' + fence + '\\n' + plain + '\\n~~~\\n\\n';
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

// Get ALL data sources in the workspace dynamically
// API 2025-09-03: Search now returns data_source objects instead of database
async function getAllDatabases() {
  console.log('🔍 Discovering ALL data sources in your Notion workspace (API 2025-09-03)...');
  const databases = {};
  
  try {
    // Search for all data sources in the workspace (API 2025-09-03)
    const response = await notion.search({
      filter: {
        property: 'object',
        value: 'data_source'  // Changed from 'database' for API 2025-09-03
      },
      page_size: 100
    });
    
    // Map each data source by its parent database ID for compatibility
    for (const ds of response.results) {
      // API 2025-09-03: data sources have parent.database_id
      const dbId = ds.parent?.database_id || ds.id;
      const dataSourceId = ds.id;
      const title = ds.title?.[0]?.plain_text || 'Untitled Database';
      // Map by BOTH database_id and data_source_id for compatibility
      databases[dbId] = title;
      databases[dataSourceId] = title;  // Pages reference by data_source_id
      console.log(\`   Found data source: \${title} (ID: \${ds.id})\`);
    }
    
    console.log(\`\\n📊 Found \${Object.keys(databases).length} data sources total\\n\`);
  } catch (error) {
    // Fallback: try with 'database' filter for backwards compatibility
    console.log('   ⚠️ data_source search failed, trying database fallback...');
    try {
      const response = await notion.search({
        filter: { property: 'object', value: 'database' },
        page_size: 100
      });
      for (const db of response.results) {
        const title = db.title?.[0]?.plain_text || 'Untitled Database';
        databases[db.id] = title;
      }
      console.log(\`\\n📊 Found \${Object.keys(databases).length} databases (fallback)\\n\`);
    } catch (fallbackError) {
      console.log('   ⚠️ Could not get databases:', fallbackError.message);
    }
  }
  
  return databases;
}

// Get page info including parent database/data source and all properties
// API 2025-09-03: Pages can have data_source_id parent
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
    
    // API 2025-09-03: Check for data_source_id first, then database_id
    const dataSourceId = page.parent.data_source_id || null;
    const parentId = page.parent.database_id || page.parent.page_id || null;
    
    // If this is a database/data source item, try to get the schema
    let databasePropertyOrder = [];
    if (dataSourceId || (parentId && page.parent.type === 'database_id')) {
      try {
        // API 2025-09-03: Use dataSources.retrieve for data source schema
        if (dataSourceId && notion.dataSources) {
          const dataSource = await notion.dataSources.retrieve({ data_source_id: dataSourceId });
          databasePropertyOrder = Object.keys(dataSource.properties || {});
        } else if (parentId) {
          // Fallback to databases.retrieve
          const database = await notion.databases.retrieve({ database_id: parentId });
          databasePropertyOrder = Object.keys(database.properties || {});
        }
      } catch (e) {
        console.log(\`Could not retrieve schema for \${dataSourceId || parentId}: \${e.message}\`);
        databasePropertyOrder = propertyOrder;
      }
    } else {
      databasePropertyOrder = propertyOrder;
    }
    
    return {
      title,
      parentId: dataSourceId || parentId,  // Prefer data source ID
      parentType: page.parent.type,
      dataSourceId,
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

  function stripExportArtifacts(s) {
    return String(s || '')
      .replace(/^\\s*\\*\\*Generated:\\*\\*.*(?:\\r?\\n)?/gmi, '')
      .replace(/^\\s*\\*\\*Config:\\*\\*.*(?:\\r?\\n)?/gmi, '')
      .replace(/^\\s*Generated:\\s*.*(?:\\r?\\n)?/gmi, '');
  }
  
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
      content += stripExportArtifacts(mdString.parent);
      
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
  
  return stripExportArtifacts(content);
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

// Group pages by database/data source for proper ordering
// API 2025-09-03: Pages can have data_source_id parent type
async function groupPagesByDatabase(pageIds) {
  const grouped = {};
  const standalone = [];
  
  for (const pageId of pageIds) {
    const cleanId = pageId.replace(/-/g, '');
    const pageInfo = await getPageInfo(cleanId);
    
    // API 2025-09-03: Check for both database_id and data_source_id parent types
    const isFromDatabase = pageInfo.parentType === 'database_id' || 
                           pageInfo.parentType === 'data_source_id' ||
                           pageInfo.dataSourceId;
    
    if (isFromDatabase && pageInfo.parentId) {
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
        
        // Use Nr property from Notion if available, otherwise use sequential counter
        const nrValue = info.properties['Nr'] || info.properties['#'] || info.properties['nr'];
        const fileNumber = nrValue ? String(nrValue).padStart(2, '0') : counter.toString().padStart(2, '0');
        
        // Generate numbered filename using Notion's Nr value
        const filename = \`\${fileNumber}. \${info.title}.md\`
          .replace(/[^a-zA-Z0-9 .-]/g, '')
          .trim();
        
        const outputPath = path.join(folderPath, filename);
        
        // Create custom formatted markdown (use Nr for entry number too)
        const entryNumber = nrValue || counter;
        const content = await createCustomMarkdown(id, info, dbName, entryNumber);
        
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
    console.log('   📁 ' + folderName + '/ [with _Overview.md]');
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