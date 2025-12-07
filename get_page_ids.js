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

// Initialize Notion client with API version 2025-09-03
const notion = new Client({
  auth: NOTION_TOKEN,
  notionVersion: '2025-09-03', // Required for @notionhq/client v5.x
});

// Rate limiting helper to avoid API throttling
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

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

/**
 * Get data source IDs from a database
 * API 2025-09-03: Databases now contain multiple data sources
 */
async function getDataSourcesFromDatabase(databaseId) {
  try {
    const database = await notion.databases.retrieve({ database_id: databaseId });
    // API 2025-09-03 returns data_sources array
    if (database.data_sources && database.data_sources.length > 0) {
      return database.data_sources.map(ds => ({
        id: ds.id,
        name: ds.name || 'Untitled'
      }));
    }
    // Fallback for backwards compatibility - use database ID as data source ID
    return [{ id: databaseId, name: database.title?.[0]?.plain_text || 'Untitled' }];
  } catch (error) {
    console.error(`Error getting data sources for ${databaseId}: ${error.message}`);
    return [{ id: databaseId, name: 'Unknown' }];
  }
}

/**
 * Query a data source for pages
 * API 2025-09-03: Use dataSources.query instead of databases.query
 */
async function queryDataSource(dataSourceId) {
  try {
    // SDK v5.x with API 2025-09-03 uses dataSources.query
    const results = [];
    let cursor = undefined;
    
    do {
      const response = await notion.dataSources.query({
        data_source_id: dataSourceId,
        page_size: 100,
        start_cursor: cursor,
      });
      
      results.push(...response.results);
      cursor = response.has_more ? response.next_cursor : undefined;
    } while (cursor);
    
    return results;
  } catch (error) {
    // Fallback: Try using databases.query for backwards compatibility
    console.error(`dataSources.query failed, trying databases.query: ${error.message}`);
    try {
      const results = [];
      let cursor = undefined;
      
      do {
        const response = await notion.databases.query({
          database_id: dataSourceId,
          page_size: 100,
          start_cursor: cursor,
        });
        
        results.push(...response.results);
        cursor = response.has_more ? response.next_cursor : undefined;
      } while (cursor);
      
      return results;
    } catch (fallbackError) {
      console.error(`Fallback also failed: ${fallbackError.message}`);
      return [];
    }
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
            
            // Rate limiting to avoid API throttling
            await delay(100);
            
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
          
          // API 2025-09-03: Get data sources from database first
          const dataSources = await getDataSourcesFromDatabase(dbId);
          
          for (const dataSource of dataSources) {
            console.error(`${'  '.repeat(level)}  📁 Data source: ${dataSource.name}`);
            
            // Query each data source for pages
            const pages = await queryDataSource(dataSource.id);
            
            for (const page of pages) {
              if (!pageIds.has(page.id)) {
                pageIds.add(page.id);
                const title = await getPageTitle(page.id);
                
                pageInfo.push({
                  id: page.id,
                  title: title,
                  level: level + 1,
                  parent: dbId,
                  dataSourceId: dataSource.id,
                  fromDatabase: true
                });
                
                console.error(`${'  '.repeat(level + 1)}📄 DB Page: ${title} (${page.id.substring(0, 8)}...)`);
                
                // Rate limiting to avoid API throttling
                await delay(50);
              }
            }
          }
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
    console.error('🔍 Scanning for all page IDs (API 2025-09-03)...\n');
    
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
      apiVersion: '2025-09-03',
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
