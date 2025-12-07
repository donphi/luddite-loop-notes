/**
 * Notion API Utilities
 * Shared utilities for rate limiting, retries, and error handling
 */

const { Client, APIErrorCode, isNotionClientError } = require("@notionhq/client");

// Configuration for Notion API 2025-09-03
// See: https://developers.notion.com/reference/versioning
const CONFIG = {
  API_VERSION: '2025-09-03',  // Multi-source databases support
  MAX_RETRIES: 3,
  INITIAL_DELAY_MS: 1000,
  MAX_DELAY_MS: 30000,
  RATE_LIMIT_DELAY_MS: 100,
};

/**
 * Sleep for specified milliseconds
 */
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

/**
 * Calculate exponential backoff delay
 */
function getBackoffDelay(attempt, initialDelay = CONFIG.INITIAL_DELAY_MS) {
  const delay = initialDelay * Math.pow(2, attempt);
  // Add jitter to prevent thundering herd
  const jitter = Math.random() * 0.3 * delay;
  return Math.min(delay + jitter, CONFIG.MAX_DELAY_MS);
}

/**
 * Retry wrapper for Notion API calls
 * Handles rate limiting and transient errors
 */
async function withRetry(fn, options = {}) {
  const maxRetries = options.maxRetries || CONFIG.MAX_RETRIES;
  const context = options.context || 'API call';
  
  let lastError;
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      
      // Check if it's a Notion API error
      if (isNotionClientError(error)) {
        // Rate limited - wait and retry
        if (error.code === APIErrorCode.RateLimited) {
          const waitTime = getBackoffDelay(attempt);
          console.error(`⏳ Rate limited on ${context}. Waiting ${Math.round(waitTime/1000)}s before retry ${attempt + 1}/${maxRetries}...`);
          await delay(waitTime);
          continue;
        }
        
        // Service unavailable - retry with backoff
        if (error.code === APIErrorCode.ServiceUnavailable) {
          const waitTime = getBackoffDelay(attempt);
          console.error(`🔄 Service unavailable on ${context}. Retry ${attempt + 1}/${maxRetries} in ${Math.round(waitTime/1000)}s...`);
          await delay(waitTime);
          continue;
        }
        
        // Don't retry on auth/validation errors
        if (error.code === APIErrorCode.Unauthorized || 
            error.code === APIErrorCode.InvalidRequest ||
            error.code === APIErrorCode.ObjectNotFound) {
          throw error;
        }
      }
      
      // Unknown error - retry with backoff on first few attempts
      if (attempt < maxRetries) {
        const waitTime = getBackoffDelay(attempt);
        console.error(`⚠️ Error on ${context}. Retry ${attempt + 1}/${maxRetries} in ${Math.round(waitTime/1000)}s...`);
        await delay(waitTime);
      }
    }
  }
  
  throw lastError;
}

/**
 * Create a Notion client with proper configuration
 */
function createNotionClient(auth) {
  return new Client({
    auth: auth,
    notionVersion: CONFIG.API_VERSION,
    timeoutMs: 60000,
  });
}

/**
 * Sanitize a string for use as filename
 */
function sanitizeFilename(name, maxLength = 100) {
  if (!name) return 'untitled';
  
  return name
    .replace(/[<>:"/\\|?*\x00-\x1f]/g, '') // Remove invalid chars
    .replace(/\s+/g, ' ')                   // Normalize whitespace
    .trim()
    .substring(0, maxLength) || 'untitled';
}

/**
 * Format a date for display
 */
function formatDate(date) {
  return new Intl.DateTimeFormat('en-GB', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
}

/**
 * Get page title from various property types
 */
async function getPageTitle(notion, pageId) {
  try {
    const page = await withRetry(
      () => notion.pages.retrieve({ page_id: pageId }),
      { context: `getPageTitle(${pageId.substring(0, 8)})` }
    );
    
    // Try common title property names
    const titleProps = ['title', 'Title', 'Name', 'name'];
    
    for (const propName of titleProps) {
      if (page.properties[propName]?.title?.[0]?.plain_text) {
        return page.properties[propName].title[0].plain_text;
      }
    }
    
    // Fallback: find any title property
    for (const [key, value] of Object.entries(page.properties)) {
      if (value.type === 'title' && value.title?.[0]?.plain_text) {
        return value.title[0].plain_text;
      }
    }
    
    return 'Untitled';
  } catch (error) {
    console.error(`Failed to get title for page ${pageId}: ${error.message}`);
    return 'Untitled';
  }
}

/**
 * Progress tracker for batch operations
 */
class ProgressTracker {
  constructor(total, label = 'Processing') {
    this.total = total;
    this.current = 0;
    this.label = label;
    this.startTime = Date.now();
    this.errors = [];
  }
  
  increment(item = '') {
    this.current++;
    const percent = Math.round((this.current / this.total) * 100);
    const elapsed = ((Date.now() - this.startTime) / 1000).toFixed(1);
    const itemInfo = item ? `: ${item.substring(0, 40)}${item.length > 40 ? '...' : ''}` : '';
    console.log(`[${this.current}/${this.total}] (${percent}%) ${this.label}${itemInfo} [${elapsed}s]`);
  }
  
  addError(item, error) {
    this.errors.push({ item, error: error.message || error });
  }
  
  summary() {
    const elapsed = ((Date.now() - this.startTime) / 1000).toFixed(1);
    console.log(`\n✅ Completed: ${this.current - this.errors.length}/${this.total} in ${elapsed}s`);
    if (this.errors.length > 0) {
      console.log(`❌ Errors: ${this.errors.length}`);
      this.errors.forEach(e => console.log(`   - ${e.item}: ${e.error}`));
    }
  }
}

module.exports = {
  CONFIG,
  delay,
  getBackoffDelay,
  withRetry,
  createNotionClient,
  sanitizeFilename,
  formatDate,
  getPageTitle,
  ProgressTracker,
};

