#!/usr/bin/env python3
"""
Extract all page IDs from a Notion parent page
Then optionally export them all
"""

import os
import sys
import json
import subprocess
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class NotionPageScanner:
    def __init__(self):
        self.notion_token = os.getenv('NOTION_TOKEN')
        self.parent_page_id = os.getenv('NOTION_PAGE_ID')
        self.recursive = os.getenv('RECURSIVE', 'true').lower() == 'true'
        self.auto_export = os.getenv('AUTO_EXPORT', 'false').lower() == 'true'
        
    def validate_config(self) -> bool:
        """Validate required configuration"""
        if not self.notion_token:
            print("❌ Error: NOTION_TOKEN environment variable is required")
            return False
        
        if not self.parent_page_id:
            print("❌ Error: NOTION_PAGE_ID environment variable is required")
            return False
        
        return True
    
    def scan_pages(self) -> dict:
        """Run the Node.js script to get all page IDs"""
        try:
            args = [
                'node',
                'get_page_ids.js',
                self.notion_token,
                self.parent_page_id.replace('-', ''),
                str(self.recursive).lower()
            ]
            
            print("🔍 Scanning Notion pages...")
            print("=" * 50)
            
            result = subprocess.run(
                args,
                capture_output=True,
                text=True,
                check=False
            )
            
            if result.returncode != 0:
                error_msg = result.stderr or result.stdout
                try:
                    error_data = json.loads(error_msg)
                    return {'success': False, 'error': error_data.get('error', 'Unknown error')}
                except json.JSONDecodeError:
                    return {'success': False, 'error': error_msg}
            
            try:
                return json.loads(result.stdout)
            except json.JSONDecodeError:
                return {'success': False, 'error': f'Invalid JSON response: {result.stdout}'}
                
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def update_env_file(self, page_ids: list) -> bool:
        """Update the .env file with new page IDs"""
        env_file = Path('.env')
        
        if not env_file.exists():
            print("⚠️  .env file not found, creating new one...")
            with open(env_file, 'w') as f:
                f.write(f"# Notion Integration Token\n")
                f.write(f"# Get it from: https://www.notion.so/my-integrations\n")
                f.write(f"NOTION_TOKEN={self.notion_token or 'YOUR_TOKEN_HERE'}\n")
                f.write(f"\n")
                f.write(f"# Notion Page IDs (auto-updated by get_page_ids.py)\n")
                f.write(f"NOTION_PAGE_IDS={','.join(page_ids)}\n")
                f.write(f"\n")
                f.write(f"# Whether to save child pages as separate files (true/false)\n")
                f.write(f"SEPARATE_CHILD_PAGES=true\n")
            print("✅ Created new .env file with page IDs")
            return True
        
        # Read existing .env file
        with open(env_file, 'r') as f:
            lines = f.readlines()
        
        # Update or add NOTION_PAGE_IDS
        updated = False
        new_lines = []
        for line in lines:
            if line.strip().startswith('NOTION_PAGE_IDS='):
                new_lines.append(f"NOTION_PAGE_IDS={','.join(page_ids)}\n")
                updated = True
            else:
                new_lines.append(line)
        
        # If NOTION_PAGE_IDS wasn't found, add it
        if not updated:
            # Add before the last line if it's empty, otherwise at the end
            if new_lines and new_lines[-1].strip() == '':
                new_lines.insert(-1, f"\n# Notion Page IDs (auto-updated by get_page_ids.py)\n")
                new_lines.insert(-1, f"NOTION_PAGE_IDS={','.join(page_ids)}\n")
            else:
                new_lines.append(f"\n# Notion Page IDs (auto-updated by get_page_ids.py)\n")
                new_lines.append(f"NOTION_PAGE_IDS={','.join(page_ids)}\n")
        
        # Write back to .env
        with open(env_file, 'w') as f:
            f.writelines(new_lines)
        
        print("✅ Updated .env file with new page IDs")
        return True
    
    def display_results(self, result: dict) -> None:
        """Display the scan results"""
        if not result.get('success'):
            print(f"❌ Scan failed: {result.get('error')}")
            return
        
        print("\n" + "=" * 50)
        print("📊 SCAN RESULTS")
        print("=" * 50)
        
        pages = result.get('pages', [])
        total = result.get('totalPages', 0)
        
        print(f"\n✅ Found {total} pages total\n")
        
        # Group pages by level for better display
        by_level = {}
        for page in pages:
            level = page.get('level', 0)
            if level not in by_level:
                by_level[level] = []
            by_level[level].append(page)
        
        # Display hierarchically
        print("📁 Page Hierarchy:")
        for level in sorted(by_level.keys()):
            for page in by_level[level]:
                indent = "  " * level
                icon = "📊" if page.get('fromDatabase') else "📄"
                title = page.get('title', 'Untitled')[:50]
                page_id = page.get('id', '')[:8]
                print(f"{indent}{icon} {title} ({page_id}...)")
        
        # Display copyable list
        print("\n" + "=" * 50)
        print("📋 READY TO EXPORT")
        print("=" * 50)
        
        page_ids = result.get('pageIds', [])
        
        # Automatically update .env file
        print("\n🔄 Updating .env file...")
        self.update_env_file(page_ids)
        
        print("\n✂️  Page IDs have been added to your .env file:")
        print("-" * 50)
        print(f"NOTION_PAGE_IDS={','.join(page_ids)}")
        print("-" * 50)
        
        # Try to save backup file (optional - if it fails, that's okay)
        try:
            # Try host directory first if mounted
            host_dir = Path('/app/host')
            if host_dir.exists():
                output_file = host_dir / 'found_page_ids.txt'
            else:
                output_file = Path('found_page_ids.txt')
            
            with open(output_file, 'w') as f:
                f.write(f"# Found {total} pages from parent: {result.get('parentPage')}\n")
                f.write(f"# Recursive scan: {result.get('recursive')}\n\n")
                f.write(f"# For .env file:\n")
                f.write(f"NOTION_PAGE_IDS={','.join(page_ids)}\n\n")
                f.write(f"# Individual page IDs:\n")
                for page in pages:
                    f.write(f"# {page.get('title', 'Untitled')}\n")
                    f.write(f"{page.get('id')}\n\n")
            
            print(f"\n💾 Backup also saved to: {output_file}")
        except Exception as e:
            # If backup fails, it's not critical - we already updated .env
            print(f"\n⚠️  Could not save backup file (non-critical): {e}")
        
        if self.auto_export:
            print("\n🚀 AUTO_EXPORT is enabled. Starting export of all pages...")
            self.export_all(page_ids)
    
    def export_all(self, page_ids: list) -> None:
        """Export all found pages"""
        print("\n" + "=" * 50)
        print("📥 EXPORTING ALL PAGES")
        print("=" * 50)
        
        # Update environment variable and run export
        os.environ['NOTION_PAGE_IDS'] = ','.join(page_ids)
        
        # Run the main export script
        try:
            subprocess.run(['python', 'export_notion.py'], check=True)
        except subprocess.CalledProcessError as e:
            print(f"❌ Export failed: {e}")
    
    def run(self) -> bool:
        """Main execution"""
        print("=" * 50)
        print("🔖 Notion Page ID Scanner")
        print("=" * 50)
        print()
        
        if not self.validate_config():
            return False
        
        print(f"📋 Configuration:")
        print(f"   - Parent page: {self.parent_page_id[:8]}...")
        print(f"   - Recursive scan: {self.recursive}")
        print(f"   - Auto export: {self.auto_export}")
        print()
        
        result = self.scan_pages()
        self.display_results(result)
        
        return result.get('success', False)

def main():
    """Main entry point"""
    scanner = NotionPageScanner()
    success = scanner.run()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()