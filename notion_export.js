const { Client } = require("@notionhq/client");
const { NotionToMarkdown } = require("notion-to-md");
const fs = require('fs').promises;
const path = require('path');

const args = process.argv.slice(2);
const NOTION_TOKEN = args[0];
const NOTION_PAGE_IDS = args[1].split(',');
const OUTPUT_DIR = args[2] || './output';
const SEPARATE_CHILD_PAGES = args[3] === 'true';
const EXTRA_ARGS = args.slice(4);
const DEBUG_TABLES =
  process.env.DEBUG_TABLES === '1' ||
  process.env.DEBUG_TABLES === 'true' ||
  EXTRA_ARGS.includes('--debug-tables') ||
  EXTRA_ARGS.includes('--debug') ||
  EXTRA_ARGS.includes('true');

const notion = new Client({
  auth: NOTION_TOKEN,
  notionVersion: '2025-09-03', 
});

const n2m = new NotionToMarkdown({ 
  notionClient: notion,
  config: {
    separateChildPage: SEPARATE_CHILD_PAGES,
    parseChildPages: true
  }
});

// ---------- TABLES: deterministic HTML emitter (no regex) ----------
function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

function looksLikeAsciiDiagram(s) {
  const str = String(s || '');
  // Detect any of the unicode “diagram” families the project uses:
  // - Box drawing (light/heavy/double/rounded/dashed/mixed): U+2500–U+257F
  // - Block elements (progress bars, shading): U+2580–U+259F
  // - Geometric shapes (squares, triangles, circles, etc.): U+25A0–U+25FF
  // - Arrows: U+2190–U+21FF
  // - Misc symbols (warning/info/etc.): U+2600–U+26FF
  // - Dingbats (checks, crosses, stars, etc.): U+2700–U+27BF
  if (/[\u2500-\u257F\u2580-\u259F\u25A0-\u25FF\u2190-\u21FF\u2600-\u26FF\u2700-\u27BF]/u.test(str)) {
    return true;
  }
  // Also treat common ASCII “diagram-ish” tokens as diagrams.
  return /(<==>|<->|==>|<==|->|<-|\|->|<-\\|)/.test(str);
}

function escapeLatexForFancyVerbatimCommandchars(s) {
  // We emit a FancyVerb `Verbatim` with `commandchars=\\{}` so `\textbf{...}` works.
  // To avoid accidental commands, replace literal command/group chars with printable commands.
  return String(s)
    .replace(/\\/g, '\\textbackslash{}')
    .replace(/\{/g, '\\textbraceleft{}')
    .replace(/\}/g, '\\textbraceright{}');
}

function renderRichTextPieceToHtml(rt) {
  if (!rt) return '';

  // Most blocks include `plain_text`, which already reflects mentions, equations, etc.
  // We still handle common rich_text types explicitly for safety.
  let text = '';
  if (rt.type === 'text') text = rt.text?.content ?? rt.plain_text ?? '';
  else if (rt.type === 'equation') text = rt.equation?.expression ?? rt.plain_text ?? '';
  else if (rt.type === 'mention') text = rt.plain_text ?? '';
  else text = rt.plain_text ?? '';

  // Preserve soft line breaks inside table cells
  let html = escapeHtml(text).replace(/\n/g, '<br />');

  const href = rt.href;
  if (href) {
    html = `<a href="${escapeHtml(href)}">${html}</a>`;
  }

  const ann = rt.annotations || {};
  if (ann.code) html = `<code>${html}</code>`;
  if (ann.bold) html = `<strong>${html}</strong>`;
  if (ann.italic) html = `<em>${html}</em>`;
  if (ann.strikethrough) html = `<del>${html}</del>`;
  if (ann.underline) html = `<u>${html}</u>`;

  return html;
}

function renderCellToHtml(cellRichTextArray) {
  const parts = Array.isArray(cellRichTextArray) ? cellRichTextArray : [];
  return parts.map(renderRichTextPieceToHtml).join('');
}

function renderRichTextArrayToPlainText(richTextArray) {
  const parts = Array.isArray(richTextArray) ? richTextArray : [];
  return parts
    .map(rt => String(rt?.plain_text ?? '').normalize('NFC'))
    .join('');
}

function renderRichTextArrayToPandocDiagramBlocks(richTextArray) {
  const parts = Array.isArray(richTextArray) ? richTextArray : [];

  // Build HTML that preserves spacing and supports bold within diagrams.
  const htmlInner = parts.map(rt => {
    const text = String(rt?.plain_text ?? '').normalize('NFC');
    const escaped = escapeHtml(text);
    if (rt?.annotations?.bold) return `<strong>${escaped}</strong>`;
    return escaped;
  }).join('');

  // Build LaTeX that keeps monospace alignment and supports bold segments.
  const latexInner = parts.map(rt => {
    const text = String(rt?.plain_text ?? '').normalize('NFC');
    const escaped = escapeLatexForFancyVerbatimCommandchars(text);
    if (rt?.annotations?.bold) return `\\textbf{${escaped}}`;
    return escaped;
  }).join('');

  const htmlBlock = `<pre class="notion-ascii-diagram"><code>${htmlInner}</code></pre>`;
  const latexBlock =
`\\begin{Verbatim}[commandchars=\\\\\\{\\}]
${latexInner}
\\end{Verbatim}`;

  // Pandoc will select the appropriate raw block for the target output format.
  return `\n\n\`\`\`{=html}\n${htmlBlock}\n\`\`\`\n\n\`\`\`{=latex}\n${latexBlock}\n\`\`\`\n\n`;
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
      console.error("DEBUG_TABLE_BLOCK:", JSON.stringify({ id: block.id, table: block.table }, null, 2));
      console.error("DEBUG_TABLE_FIRST_ROW_JSON:", JSON.stringify(firstRow, null, 2));
    }

    const hasColHeader = !!block.table?.has_column_header;
    const hasRowHeader = !!block.table?.has_row_header;
  
    const parsedRows = rows
      .filter(r => r.type === 'table_row')
      .map(r => (r.table_row?.cells || []).map(cell =>
        renderCellToHtml(cell)
      ));
  
    if (parsedRows.length === 0) return '';
  
    const maxCols = Math.max(...parsedRows.map(r => r.length));
    const norm = parsedRows.map(r => {
      const rr = r.slice();
      while (rr.length < maxCols) rr.push('');
      return rr;
    });
  
    const thead = hasColHeader ? norm[0] : null;
    const tbody = hasColHeader ? norm.slice(1) : norm;
  
    let html = '\n<table>\n';
    if (thead) {
      html += '  <thead>\n    <tr>\n';
      thead.forEach((c, j) => {
        html += `      <th>${c}</th>\n`;
      });
      html += '    </tr>\n  </thead>\n';
    }
    html += '  <tbody>\n';
    tbody.forEach((r) => {
      html += '    <tr>\n';
      r.forEach((c, j) => {
        if (hasRowHeader && j === 0) {
          html += `      <th scope="row">${c}</th>\n`;
        } else {
          html += `      <td>${c}</td>\n`;
        }
      });
      html += '    </tr>\n';
    });
    html += '  </tbody>\n</table>\n';
    return html;
  });
  
  // Prevent row blocks from being rendered separately (avoid duplicates)
  n2m.setCustomTransformer('table_row', async () => '');

// ---------- CODE BLOCKS: preserve ASCII diagrams + optional bold/emojis ----------
n2m.setCustomTransformer('code', async (block) => {
  const lang = (block.code?.language || '').toLowerCase();
  const rich = block.code?.rich_text || [];

  // Some Notion "plain text" diagrams are stored as code blocks with styled spans.
  // Default exporters sometimes insert newlines between spans; we must join spans as-is.
  const plain = renderRichTextArrayToPlainText(rich);

  const isDiagram =
    lang === 'plain text' ||
    lang === 'text' ||
    lang === 'plain' ||
    looksLikeAsciiDiagram(plain);

  if (isDiagram) {
    return renderRichTextArrayToPandocDiagramBlocks(rich);
  }

  const fenceLang = lang && lang !== 'plain text' ? lang : '';
  const fence = fenceLang ? `\`\`\`${fenceLang}` : '```';
  return `\n\n${fence}\n${plain}\n\`\`\`\n\n`;
});
  

// =============================================================================
// POST-PROCESSING: Fix Structural Failures for LaTeX Output
// =============================================================================

function cleanNotionMarkdown(content) {
  let cleaned = content;

  // 0. Remove exporter artifacts if they appear in-page
  // (Some pipelines inject these; user does not want them in every file.)
  cleaned = cleaned
    .replace(/^\s*\*\*Generated:\*\*.*(?:\r?\n)?/gmi, '')
    .replace(/^\s*\*\*Config:\*\*.*(?:\r?\n)?/gmi, '')
    .replace(/^\s*Generated:\s*.*(?:\r?\n)?/gmi, '');
  
  // 1. Repair Merged Dates (e.g., "16 May 202514 September 2025")
  // Ensures timeline integrity for academic record keeping.
  cleaned = cleaned.replace(
    /(\d{1,2}\s+\w+\s+\d{4})(\d{1,2}\s+\w+\s+\d{4})/g,
    '$1 -- $2'
  );

  // 4. Whitespace Normalization
  cleaned = cleaned.replace(/\n{3,}/g, '\n\n');

  return cleaned;
}

function convertCalloutsToLatex(content) {
  // Wraps 💡 and ⚠️ Notion callouts in LaTeX quote environments
  const calloutPattern = /([💡⚠️])\s*([\s\S]+?)(?=\n\n|\n#|$)/g;
  
  return content.replace(calloutPattern, (match, icon, text) => {
    const label = icon === '💡' ? 'Note' : 'Warning';
    const escaped = text.trim()
      .replace(/&/g, '\\&')
      .replace(/%/g, '\\%')
      .replace(/\$/g, '\\$')
      .replace(/_/g, '\\_')
      .replace(/#/g, '\\#');
    
    return `\n\n\`\`\`{=latex}\n\\begin{quote}\n\\textbf{${label}:} ${escaped}\n\\end{quote}\n\`\`\`\n\n`;
  });
}

function processContent(content) {
  let processed = content;
  processed = cleanNotionMarkdown(processed);
  processed = convertCalloutsToLatex(processed);
  return processed;
}

// =============================================================================
// EXPORT LOGIC
// =============================================================================

async function getPageTitle(pageId) {
  try {
    const page = await notion.pages.retrieve({ page_id: pageId });
    const prop = page.properties.title || page.properties.Name || page.properties.name;
    return prop?.title?.[0]?.plain_text || pageId.substring(0, 8);
  } catch (error) {
    return pageId.substring(0, 8);
  }
}

function sanitizeFilename(name) {
  return name.replace(/[^a-z0-9]/gi, '_').toLowerCase();
}

async function exportSinglePage(pageId) {
  const pageName = await getPageTitle(pageId);
  const sanitizedName = sanitizeFilename(pageName);
  const files = [];
  
  const mdblocks = await n2m.pageToMarkdown(pageId);
  const mdString = n2m.toMarkdownString(mdblocks);
  
  if (SEPARATE_CHILD_PAGES && mdString.children) {
    const pageDir = path.join(OUTPUT_DIR, sanitizedName);
    await fs.mkdir(pageDir, { recursive: true });
    
    const parentContent = processContent(mdString.parent || '');
    const parentPath = path.join(pageDir, 'index.md');
    await fs.writeFile(parentPath, parentContent, 'utf8');
    files.push({ type: 'parent', path: parentPath });
    
    for (const [childId, childContent] of Object.entries(mdString.children)) {
      const processedChild = processContent(childContent);
      const childName = sanitizeFilename(childId);
      const childPath = path.join(pageDir, `${childName}.md`);
      await fs.writeFile(childPath, processedChild, 'utf8');
      files.push({ type: 'child', childId, path: childPath });
    }
    console.error(`Exported: ${pageName}`);
    return { success: true, pageId, pageName, directory: pageDir, files };
  } else {
    const finalMd = processContent(mdString.parent || '');
    const outPath = path.join(OUTPUT_DIR, `${sanitizedName}.md`);
    await fs.writeFile(outPath, finalMd, 'utf8');
    files.push({ type: 'single', path: outPath });
    console.error(`Exported: ${pageName}`);
    return { success: true, pageId, pageName, directory: OUTPUT_DIR, files };
  }
}

(async () => {
  try {
    await fs.mkdir(OUTPUT_DIR, { recursive: true });
    const pages = [];
    let hadError = false;

    for (const id of NOTION_PAGE_IDS) {
      const cleanId = id.trim().replace(/-/g, '');
      if (!cleanId) continue;
      try {
        const res = await exportSinglePage(cleanId);
        pages.push(res);
      } catch (e) {
        hadError = true;
        const msg = e && (e.stack || e.message) ? (e.stack || e.message) : String(e);
        console.error(`Failed to export page ${cleanId}: ${msg}`);
        pages.push({ success: false, pageId: cleanId, error: msg });
      }
    }

    // IMPORTANT: stdout must be clean JSON for the Python wrapper
    console.log(JSON.stringify({
      success: !hadError,
      totalPages: pages.length,
      pages,
    }));

    if (hadError) process.exitCode = 1;
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
})();