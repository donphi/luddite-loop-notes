const fs = require('fs');
const path = require('path');

// Fix problematic emojis by adding descriptive text
const emojiMap = {
  '🧹': '🧹 [Broom]',
  '📘': '📘 [Book]',
  '📊': '📊 [Chart]',
  '📈': '📈 [Chart Up]',
  '🔄': '🔄 [Arrows]'
};

function processFile(filePath) {
  try {
    let content = fs.readFileSync(filePath, 'utf8');
    let modified = false;
    
    for (const [emoji, replacement] of Object.entries(emojiMap)) {
      // Simple replacement without complex conditions
      const regex = new RegExp(emoji + ' ', 'g');
      if (content.match(regex)) {
        content = content.replace(regex, replacement + ' ');
        modified = true;
      }
    }
    
    if (modified) {
      fs.writeFileSync(filePath, content, 'utf8');
      console.log('Fixed: ' + path.basename(filePath));
    }
  } catch (error) {
    console.error('Error:', error.message);
  }
}

// Process files
const files = [
  '/app/output/1. Activity Log (80+ Required)/02. Convert UKB PDFs to MD and JSON.md',
  '/app/output/1. Activity Log (80+ Required)/_Overview.md'
];

files.forEach(f => {
  if (fs.existsSync(f)) {
    processFile(f);
  }
});

console.log('Done! Emojis should now have descriptive text.');
