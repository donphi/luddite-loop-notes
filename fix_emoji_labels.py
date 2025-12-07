#!/usr/bin/env python3
"""
Add descriptive labels next to emojis in markdown files
This helps when emojis don't render properly in viewers
"""

import os
import re
from pathlib import Path

# Emoji mappings - add label after emoji
emoji_map = {
    '🧹': '🧹[Broom]',
    '📘': '📘[Book]',
    '📊': '📊[Chart]',
    '📈': '📈[ChartUp]',
    '🔄': '🔄[Refresh]',
    '📄': '📄[Page]',
    '📁': '📁[Folder]',
    '✅': '✅[Done]',
    '❌': '❌[Cross]',
    '✓': '✓[Check]',
    '✗': '✗[X]',
    '📝': '📝[Memo]',
    '🔍': '🔍[Search]',
    '⚠️': '⚠️[Warning]',
    '💻': '💻[Computer]',
    '🐛': '🐛[Bug]',
    '✨': '✨[Sparkles]',
    '🔧': '🔧[Wrench]',
    '📦': '📦[Package]',
    '🎨': '🎨[Art]',
    '⚡': '⚡[Zap]',
    '🔒': '🔒[Lock]',
    '🔑': '🔑[Key]',
    '📌': '📌[Pin]',
    '🏆': '🏆[Trophy]',
    '🎉': '🎉[Party]'
}

def process_file(filepath):
    """Process a single markdown file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        modified = False
        for emoji, replacement in emoji_map.items():
            # Only replace if the label isn't already there
            if emoji in content and f'{emoji}[' not in content:
                # Replace emoji followed by space
                content = content.replace(f'{emoji} ', f'{replacement} ')
                modified = True
        
        if modified:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ Fixed: {filepath}")
            return True
    except Exception as e:
        print(f"❌ Error processing {filepath}: {e}")
    return False

def main():
    """Process all markdown files in output directory"""
    output_dir = Path('./output')
    if not output_dir.exists():
        print("❌ Output directory not found!")
        return
    
    files_processed = 0
    files_modified = 0
    
    # Process all .md files recursively
    for md_file in output_dir.rglob('*.md'):
        files_processed += 1
        if process_file(md_file):
            files_modified += 1
    
    print(f"\n📊 Summary:")
    print(f"  • Processed: {files_processed} files")
    print(f"  • Modified: {files_modified} files")
    print(f"\n✨ Done! Emojis now have descriptive labels.")

if __name__ == '__main__':
    main()