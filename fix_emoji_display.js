#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Emoji to name mapping for common emojis that aren't displaying
const emojiMap = {
  '🧹': '[🧹 Broom]',
  '📘': '[📘 Book]',
  '📊': '[📊 Chart]',
  '📈': '[📈 Chart Up]',
  '🔄': '[🔄 Arrows]',
  '✅': '[✅ Check]',
  '❌': '[❌ Cross]',
  '✓': '[✓ Check]',
  '✗': '[✗ Cross]',
  '📄': '[📄 Page]',
  '📁': '[📁 Folder]',
  '🚀': '[🚀 Rocket]',
  '💡': '[💡 Bulb]',
  '🔍': '[🔍 Search]',
  '⚠️': '[⚠️ Warning]',
  '🎯': '[🎯 Target]',
  '🏗️': '[🏗️ Construction]',
  '🔧': '[🔧 Wrench]',
  '📝': '[📝 Memo]',
  '🐛': '[🐛 Bug]',
  '✨': '[✨ Sparkles]',
  '🔥': '[🔥 Fire]',
  '📦': '[📦 Package]',
  '🎨': '[🎨 Art]',
  '⚡': '[⚡ Zap]',
  '🔒': '[🔒 Lock]',
  '🔓': '[🔓 Unlock]',
  '🔑': '[🔑 Key]',
  '📌': '[📌 Pin]',
  '🏆': '[🏆 Trophy]',
  '🎉': '[🎉 Party]',
  '💻': '[💻 Computer]',
  '📱': '[📱 Phone]',
  '🖥️': '[🖥️ Desktop]',
  '⚙️': '[⚙️ Gear]',
  '🔨': '[🔨 Hammer]',
  '🛠️': '[🛠️ Tools]',
  '🔬': '[🔬 Microscope]',
  '🔭': '[🔭 Telescope]',
  '📚': '[📚 Books]',
  '📖': '[📖 Open Book]',
  '📓': '[📓 Notebook]',
  '📒': '[📒 Ledger]',
  '📕': '[📕 Red Book]',
  '📗': '[📗 Green Book]',
  '📙': '[📙 Orange Book]',
  '📔': '[📔 Notebook2]',
  '📃': '[📃 Page Curl]',
  '📜': '[📜 Scroll]',
  '📋': '[📋 Clipboard]',
  '📊': '[📊 Bar Chart]',
  '📈': '[📈 Chart Up]',
  '📉': '[📉 Chart Down]',
  '📐': '[📐 Triangle]',
  '📏': '[📏 Ruler]',
  '🗂️': '[🗂️ Card Index]',
  '🗃️': '[🗃️ Card Box]',
  '🗄️': '[🗄️ Cabinet]',
  '🗑️': '[🗑️ Trash]',
  '📥': '[📥 Inbox]',
  '📤': '[📤 Outbox]',
  '📨': '[📨 Incoming]',
  '📧': '[📧 Email]',
  '📮': '[📮 Postbox]',
  '📪': '[📪 Mailbox]',
  '📬': '[📬 Mailbox Up]',
  '📭': '[📭 Mailbox Down]',
  '🔔': '[🔔 Bell]',
  '🔕': '[🔕 No Bell]',
  '📢': '[📢 Loudspeaker]',
  '📣': '[📣 Megaphone]',
  '💬': '[💬 Speech]',
  '💭': '[💭 Thought]',
  '🗨️': '[🗨️ Speech Left]',
  '👁️': '[👁️ Eye]',
  '🔗': '[🔗 Link]',
  '🔖': '[🔖 Bookmark]',
  '🏷️': '[🏷️ Label]',
  '💰': '[💰 Money Bag]',
  '💵': '[💵 Dollar]',
  '💴': '[💴 Yen]',
  '💶': '[💶 Euro]',
  '💷': '[💷 Pound]',
  '💸': '[💸 Money Wings]',
  '💳': '[💳 Credit Card]',
  '🧾': '[🧾 Receipt]',
  '💹': '[💹 Chart Yen]',
  '✉️': '[✉️ Envelope]',
  '📩': '[📩 Envelope Arrow]',
  '📨': '[📨 Incoming Envelope]',
  '📯': '[📯 Postal Horn]',
  '📮': '[📮 Postbox]',
  '🗳️': '[🗳️ Ballot Box]',
  '✏️': '[✏️ Pencil]',
  '✒️': '[✒️ Black Nib]',
  '🖋️': '[🖋️ Fountain Pen]',
  '🖊️': '[🖊️ Pen]',
  '🖌️': '[🖌️ Paintbrush]',
  '🖍️': '[🖍️ Crayon]',
  '📝': '[📝 Memo]'
};

function processFile(filePath) {
  try {
    let content = fs.readFileSync(filePath, 'utf8');
    let modified = false;
    
    // Replace emojis with emoji + name format
    for (const [emoji, replacement] of Object.entries(emojiMap)) {
      if (content.includes(emoji) && !content.includes(replacement)) {
        content = content.replaceAll(emoji, replacement);
        modified = true;
      }
    }
    
    if (modified) {
      fs.writeFileSync(filePath, content, 'utf8');
      console.log(`✅ Fixed emojis in: ${filePath}`);
      return true;
    }
    return false;
  } catch (error) {
    console.error(`Error processing ${filePath}: ${error.message}`);
    return false;
  }
}

function processDirectory(dirPath) {
  let filesProcessed = 0;
  let filesModified = 0;
  
  function walkDir(dir) {
    const files = fs.readdirSync(dir);
    
    for (const file of files) {
      const fullPath = path.join(dir, file);
      const stat = fs.statSync(fullPath);
      
      if (stat.isDirectory() && !file.startsWith('.')) {
        walkDir(fullPath);
      } else if (stat.isFile() && file.endsWith('.md')) {
        filesProcessed++;
        if (processFile(fullPath)) {
          filesModified++;
        }
      }
    }
  }
  
  walkDir(dirPath);
  console.log(`\n📊 Processed ${filesProcessed} markdown files`);
  console.log(`✨ Modified ${filesModified} files with emoji fixes`);
}

// Main execution
const outputDir = './output';
if (fs.existsSync(outputDir)) {
  console.log('🔧 Fixing emoji display in markdown files...\n');
  processDirectory(outputDir);
  console.log('\n✅ Done! Emojis should now be visible with their names.');
} else {
  console.error('❌ Output directory not found!');
  process.exit(1);
}