#!/usr/bin/env python3
"""
Python wrapper for notion-to-md npm package
Orchestrates the Node.js script and handles configuration
"""

import os
import sys
import json
import subprocess
from pathlib import Path
from typing import Dict, List, Optional
from dotenv import load_dotenv

# Load environment variables from .env file if it exists
load_dotenv()

class NotionExporter:
    def __init__(self):
        self.notion_token = os.getenv('NOTION_TOKEN')
        self.notion_page_ids = os.getenv('NOTION_PAGE_IDS', os.getenv('NOTION_PAGE_ID', ''))
        self.output_dir = os.getenv('OUTPUT_DIR', '/app/output')
        self.separate_child_pages = os.getenv('SEPARATE_CHILD_PAGES', 'true').lower() == 'true'
        
    def validate_config(self) -> bool:
        """Validate required configuration"""
        if not self.notion_token:
            print("❌ Error: NOTION_TOKEN environment variable is required")
            print("   Get it from: https://www.notion.so/my-integrations")
            return False
        
        if not self.notion_page_ids:
            print("❌ Error: NOTION_PAGE_IDS environment variable is required")
            print("   Provide one or more page IDs separated by commas")
            return False
        
        # Parse page IDs (support both comma and space separated)
        self.page_ids_list = [
            pid.strip().replace('-', '') 
            for pid in self.notion_page_ids.replace(' ', ',').split(',') 
            if pid.strip()
        ]
        
        if not self.page_ids_list:
            print("❌ Error: No valid page IDs found")
            return False
        
        print(f"📋 Configuration:")
        print(f"   - Pages to export: {len(self.page_ids_list)}")
        for pid in self.page_ids_list[:3]:  # Show first 3
            print(f"     • {pid[:8]}...")
        if len(self.page_ids_list) > 3:
            print(f"     • ... and {len(self.page_ids_list) - 3} more")
        print(f"   - Output directory: {self.output_dir}")
        print(f"   - Separate child pages: {self.separate_child_pages}")
        print()
        
        return True
    
    def run_node_script(self) -> Dict:
        """Execute the Node.js script and return results"""
        try:
            # Export each page individually to ensure all are processed
            all_results = {
                'success': True,
                'totalPages': len(self.page_ids_list),
                'pages': []
            }
            
            print("🚀 Starting Notion export...")
            print(f"   Exporting {len(self.page_ids_list)} page(s)...")
            print()
            
            for idx, page_id in enumerate(self.page_ids_list, 1):
                clean_page_id = page_id.strip().replace('-', '')
                print(f"   📄 [{idx}/{len(self.page_ids_list)}] Exporting page {clean_page_id[:8]}...")
                
                # Prepare arguments for Node.js script
                args = [
                    'node',
                    'notion_export.js',
                    self.notion_token,
                    clean_page_id,  # Export one page at a time
                    self.output_dir,
                    str(self.separate_child_pages).lower()
                ]
                
                # Run the Node.js script with extended timeout for large pages
                result = subprocess.run(
                    args,
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=60  # Extended timeout for large pages
                )
                
                # Parse the result
                if result.returncode != 0:
                    error_msg = result.stderr or result.stdout
                    all_results['pages'].append({
                        'pageId': clean_page_id,
                        'error': error_msg[:200]  # Truncate long errors
                    })
                    print(f"      ❌ Failed: {error_msg[:100]}")
                else:
                    try:
                        page_result = json.loads(result.stdout)
                        if page_result.get('success') and page_result.get('pages'):
                            all_results['pages'].extend(page_result['pages'])
                            print(f"      ✅ Success")
                        else:
                            all_results['pages'].append({
                                'pageId': clean_page_id,
                                'error': 'No content returned'
                            })
                            print(f"      ⚠️  No content")
                    except json.JSONDecodeError:
                        all_results['pages'].append({
                            'pageId': clean_page_id,
                            'error': 'Invalid JSON response'
                        })
                        print(f"      ❌ Invalid response")
            
            return all_results
                
        except subprocess.TimeoutExpired:
            return {'success': False, 'error': 'Export timed out - page may be too large'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def display_results(self, result: Dict) -> None:
        """Display the export results"""
        if not result.get('success'):
            print(f"❌ Export failed: {result.get('error')}")
            return
        
        print("\n✅ Export completed successfully!")
        print(f"   Total pages processed: {result.get('totalPages', 0)}")
        
        pages = result.get('pages', [])
        successful_pages = [p for p in pages if 'error' not in p]
        failed_pages = [p for p in pages if 'error' in p]
        
        if successful_pages:
            print(f"\n📁 Successfully exported {len(successful_pages)} page(s):")
            for page in successful_pages:
                page_name = page.get('pageName', 'Unknown')
                page_dir = Path(page.get('directory', ''))
                files = page.get('files', [])
                
                parent_files = [f for f in files if f['type'] == 'parent']
                child_files = [f for f in files if f['type'] == 'child']
                
                print(f"\n   📄 {page_name}")
                print(f"      └─ Directory: {page_dir.name}/")
                print(f"      └─ Main file: {Path(parent_files[0]['path']).name if parent_files else 'N/A'}")
                if child_files:
                    print(f"      └─ Child pages: {len(child_files)} files")
        
        if failed_pages:
            print(f"\n⚠️  Failed to export {len(failed_pages)} page(s):")
            for page in failed_pages:
                print(f"   ❌ {page.get('pageName', page.get('pageId', 'Unknown'))}: {page.get('error', 'Unknown error')}")
        
        print(f"\n📍 All files saved to: {self.output_dir}/")
        print(f"   Each page has its own subdirectory")
    
    def export(self) -> bool:
        """Main export function"""
        print("=" * 50)
        print("🔖 Notion to Markdown Exporter (Python + Node.js)")
        print("=" * 50)
        print()
        
        # Validate configuration
        if not self.validate_config():
            return False
        
        # Run the export
        result = self.run_node_script()
        
        # Display results
        self.display_results(result)
        
        return result.get('success', False)

def main():
    """Main entry point"""
    exporter = NotionExporter()
    success = exporter.export()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()