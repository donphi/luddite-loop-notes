const { Client } = require("@notionhq/client");
const { NotionToMarkdown } = require("notion-to-md");
const fs = require('fs').promises;
const path = require('path');

// Get arguments from Python script
const args = process.argv.slice(2);
const NOTION_TOKEN = args[0];
const NOTION_PAGE_IDS = args[1].split(','); // Now accepts comma-separated IDs
const OUTPUT_DIR = args[2] || './output';
const SEPARATE_CHILD_PAGES = args[3] === 'true';

if (!NOTION_TOKEN || !NOTION_PAGE_IDS || NOTION_PAGE_IDS.length === 0) {
  console.error(JSON.stringify({
    error: "Missing required arguments: NOTION_TOKEN and NOTION_PAGE_IDS"
  }));
  process.exit(1);
}

// Initialize Notion client
const notion = new Client({
  auth: NOTION_TOKEN,
});

// Initialize NotionToMarkdown with config
const n2m = new NotionToMarkdown({ 
  notionClient: notion,
  config: {
    separateChildPage: SEPARATE_CHILD_PAGES,
    parseChildPages: true
  }
});

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
    return null;
  } catch (error) {
    return null;
  }
}

function sanitizeFilename(name) {
  return name.replace(/[^a-z0-9]/gi, '_').toLowerCase();
}

async function exportSinglePage(pageId, pageName) {
  try {
    // Get page title if not provided
    if (!pageName) {
      pageName = await getPageTitle(pageId) || pageId.substring(0, 8);
    }
    
    const sanitizedName = sanitizeFilename(pageName);
    
    // Convert page to markdown
    const mdblocks = await n2m.pageToMarkdown(pageId);
    const mdString = n2m.toMarkdownString(mdblocks);
    
    const pageResult = {
      pageId: pageId,
      pageName: pageName,
      files: []
    };
    
    // Determine file structure based on whether there are child pages
    const hasChildren = SEPARATE_CHILD_PAGES && mdString.children && Object.keys(mdString.children).length > 0;
    
    if (hasChildren) {
      // If there are child pages, create a directory for this page
      const pageDir = path.join(OUTPUT_DIR, sanitizedName);
      await fs.mkdir(pageDir, { recursive: true });
      
      // Save parent page as index.md
      const parentFile = path.join(pageDir, 'index.md');
      await fs.writeFile(parentFile, mdString.parent || '');
      pageResult.files.push({
        type: 'parent',
        path: parentFile,
        content_length: (mdString.parent || '').length
      });
      
      // Save child pages with clean names
      for (const [childId, childContent] of Object.entries(mdString.children)) {
        // Try to extract a meaningful name from the child content
        const firstLine = childContent.split('\n')[0];
        let childName = firstLine.startsWith('#') ? firstLine.replace(/^#+\s*/, '') : childId;
        const sanitizedChildName = sanitizeFilename(childName);
        const childFile = path.join(pageDir, `${sanitizedChildName}.md`);
        await fs.writeFile(childFile, childContent);
        pageResult.files.push({
          type: 'child',
          id: childId,
          path: childFile,
          content_length: childContent.length
        });
      }
      
      pageResult.directory = pageDir;
    } else {
      // If no child pages, save as a single file in the output directory
      const parentFile = path.join(OUTPUT_DIR, `${sanitizedName}.md`);
      await fs.writeFile(parentFile, mdString.parent || '');
      pageResult.files.push({
        type: 'parent',
        path: parentFile,
        content_length: (mdString.parent || '').length
      });
      
      pageResult.directory = OUTPUT_DIR;
    }
    
    return pageResult;
    
  } catch (error) {
    return {
      pageId: pageId,
      pageName: pageName || pageId,
      error: error.message
    };
  }
}

async function exportNotionPages() {
  try {
    // Ensure base output directory exists
    await fs.mkdir(OUTPUT_DIR, { recursive: true });
    
    // Prepare result object
    const result = {
      success: true,
      totalPages: NOTION_PAGE_IDS.length,
      pages: []
    };
    
    // Export each page
    for (const pageId of NOTION_PAGE_IDS) {
      const cleanPageId = pageId.trim().replace('-', '');
      if (cleanPageId) {
        console.error(`Processing page: ${cleanPageId}`); // Progress to stderr
        const pageResult = await exportSinglePage(cleanPageId);
        result.pages.push(pageResult);
      }
    }
    
    // Output JSON result for Python to parse
    console.log(JSON.stringify(result));
    
  } catch (error) {
    console.error(JSON.stringify({
      error: error.message,
      stack: error.stack
    }));
    process.exit(1);
  }
}

// Run the export
exportNotionPages();