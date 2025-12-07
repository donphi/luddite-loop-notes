const { Client } = require("@notionhq/client");

// Get arguments
const args = process.argv.slice(2);
const NOTION_TOKEN = args[0] || process.env.NOTION_TOKEN;
const PARENT_PAGE_ID = args[1] || process.env.NOTION_PAGE_ID;
const RECURSIVE = (args[2] || process.env.RECURSIVE || 'true').toLowerCase() === 'true';

if (!NOTION_TOKEN || !PARENT_PAGE_ID) {
  console.error(JSON.stringify({
    error: "Missing required arguments: NOTION_TOKEN and PARENT_PAGE_ID"
  }));
  process.exit(1);
}

// Initialize Notion client
const notion = new Client({
  auth: NOTION_TOKEN,
});

// Store all found page IDs
const pageIds = new Set();
const pageInfo = [];

async function getPageTitle(pageId) {
  try {
    const page = await notion.pages.retrieve({ page_id: pageId });
    // Try to get title from different property types
    if (page.properties.title?.title?.[0]?.plain_text) {
      return page.properties.title.title[0].plain_text;
    } else if (page.properties.Name?.title?.[0]?.plain_text) {
      return page.properties.Name.title[0].plain_text;
    } else if (page.properties.name?.title?.[0]?.plain_text) {
      return page.properties.name.title[0].plain_text;
    }
    // Fallback to first title property found
    for (const [key, value] of Object.entries(page.properties)) {
      if (value.type === 'title' && value.title?.[0]?.plain_text) {
        return value.title[0].plain_text;
      }
    }
    return 'Untitled';
  } catch (error) {
    return 'Untitled';
  }
}

async function getChildPages(blockId, level = 0) {
  try {
    let cursor = undefined;
    
    do {
      const response = await notion.blocks.children.list({
        block_id: blockId,
        page_size: 100,
        start_cursor: cursor,
      });
      
      for (const block of response.results) {
        // Check if block is a child_page
        if (block.type === 'child_page') {
          const pageId = block.id;
          if (!pageIds.has(pageId)) {
            pageIds.add(pageId);
            const title = await getPageTitle(pageId);
            
            pageInfo.push({
              id: pageId,
              title: title,
              level: level,
              parent: blockId
            });
            
            console.error(`${'  '.repeat(level)}📄 Found: ${title} (${pageId.substring(0, 8)}...)`);
            
            // Recursively get child pages if enabled
            if (RECURSIVE) {
              await getChildPages(pageId, level + 1);
            }
          }
        }
        // Check if block is a child_database
        else if (block.type === 'child_database') {
          const dbId = block.id;
          console.error(`${'  '.repeat(level)}📊 Found database: ${dbId.substring(0, 8)}...`);
          
          // Get all pages in the database
          let dbCursor = undefined;
          do {
            const dbResponse = await notion.databases.query({
              database_id: dbId,
              page_size: 100,
              start_cursor: dbCursor,
            });
            
            for (const page of dbResponse.results) {
              if (!pageIds.has(page.id)) {
                pageIds.add(page.id);
                const title = await getPageTitle(page.id);
                
                pageInfo.push({
                  id: page.id,
                  title: title,
                  level: level + 1,
                  parent: dbId,
                  fromDatabase: true
                });
                
                console.error(`${'  '.repeat(level + 1)}📄 DB Page: ${title} (${page.id.substring(0, 8)}...)`);
              }
            }
            
            dbCursor = dbResponse.has_more ? dbResponse.next_cursor : undefined;
          } while (dbCursor);
        }
      }
      
      cursor = response.has_more ? response.next_cursor : undefined;
    } while (cursor);
    
  } catch (error) {
    console.error(`Error fetching children for ${blockId}: ${error.message}`);
  }
}

async function getAllPageIds() {
  try {
    console.error('🔍 Scanning for all page IDs...\n');
    
    // Add the parent page itself
    const parentTitle = await getPageTitle(PARENT_PAGE_ID);
    pageIds.add(PARENT_PAGE_ID);
    pageInfo.push({
      id: PARENT_PAGE_ID,
      title: parentTitle,
      level: 0,
      parent: null
    });
    console.error(`📄 Parent: ${parentTitle} (${PARENT_PAGE_ID.substring(0, 8)}...)\n`);
    
    // Get all child pages
    await getChildPages(PARENT_PAGE_ID, 1);
    
    // Output results
    const result = {
      success: true,
      totalPages: pageIds.size,
      parentPage: PARENT_PAGE_ID,
      recursive: RECURSIVE,
      pageIds: Array.from(pageIds),
      pages: pageInfo
    };
    
    console.error(`\n✅ Found ${pageIds.size} total pages (including parent)`);
    console.error('\n📋 Page IDs for export (copy this for NOTION_PAGE_IDS):');
    console.error(Array.from(pageIds).join(','));
    
    // Output JSON to stdout for parsing
    console.log(JSON.stringify(result));
    
  } catch (error) {
    console.error(JSON.stringify({
      error: error.message,
      stack: error.stack
    }));
    process.exit(1);
  }
}

// Run the scanner
getAllPageIds();