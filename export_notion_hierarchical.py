#!/usr/bin/env python3
"""
Hierarchical Notion to Markdown exporter that preserves structure
"""

import os
import sys
import json
import subprocess
from pathlib import Path
from typing import Dict, List, Optional
from dotenv import load_dotenv

load_dotenv()

class HierarchicalNotionExporter:
    def __init__(self):
        self.notion_token = os.getenv('NOTION_TOKEN')
        self.notion_page_ids = os.getenv('NOTION_PAGE_IDS', os.getenv('NOTION_PAGE_ID', ''))
        self.output_dir = os.getenv('OUTPUT_DIR', './output')
        self.separate_child_pages = os.getenv('SEPARATE_CHILD_PAGES', 'true').lower() == 'true'
        self.structure = {}  # Will hold the hierarchical structure
        
    def validate_config(self) -> bool:
        """Validate required configuration"""
        if not self.notion_token:
            print("❌ Error: NOTION_TOKEN environment variable is required")
            return False
        
        if not self.notion_page_ids:
            print("❌ Error: NOTION_PAGE_IDS environment variable is required")
            return False
        
        return True
    
    def get_page_structure(self) -> Dict:
        """Get the hierarchical structure of pages"""
        try:
            # First, scan for all pages and their relationships
            args = [
                'node',
                'get_page_ids.js',
                self.notion_token,
                self.notion_page_ids.split(',')[0].strip().replace('-', ''),  # Use first as parent
                'true'  # Always recursive for structure
            ]
            
            print("🔍 Analyzing page structure...")
            result = subprocess.run(
                args,
                capture_output=True,
                text=True,
                check=False
            )
            
            if result.returncode != 0:
                print(f"❌ Failed to get page structure")
                return {}
            
            try:
                data = json.loads(result.stdout)
                if data.get('success'):
                    # Build hierarchy from flat list
                    pages = data.get('pages', [])
                    self.build_hierarchy(pages)
                    return data
            except json.JSONDecodeError:
                print(f"❌ Failed to parse structure data")
                return {}
                
        except Exception as e:
            print(f"❌ Error getting structure: {e}")
            return {}
    
    def build_hierarchy(self, pages: List[Dict]) -> None:
        """Build hierarchical structure from flat page list"""
        # Create a map of page ID to page info
        page_map = {page['id']: page for page in pages}
        
        # Build tree structure
        self.structure = {}
        for page in pages:
            page['children'] = []
            if page['parent'] is None:
                # Root page
                self.structure[page['id']] = page
            else:
                # Find parent and add as child
                parent_id = page['parent']
                if parent_id in page_map:
                    page_map[parent_id].setdefault('children', []).append(page)
    
    def export_page_hierarchically(self, page_id: str, parent_dir: str, page_info: Dict = None) -> Dict:
        """Export a page and its children maintaining hierarchy"""
        try:
            # Get page title and info
            page_title = page_info.get('title', 'Untitled') if page_info else 'Untitled'
            is_database = page_info.get('fromDatabase', False) if page_info else False
            level = page_info.get('level', 0) if page_info else 0
            
            # Clean the page title for filesystem
            safe_title = "".join(c for c in page_title if c.isalnum() or c in (' ', '-', '_', '.')).rstrip()
            safe_title = safe_title[:100] if safe_title else page_id[:8]
            
            # Create directory for this page (always create a directory for organization)
            if level == 0:
                # Root page gets main directory
                page_dir = Path(parent_dir)
            else:
                # All child pages get their own directories
                page_dir = Path(parent_dir) / safe_title
            
            page_dir.mkdir(parents=True, exist_ok=True)
            
            # Export the page content using Node.js
            args = [
                'node',
                'notion_export.js',
                self.notion_token,
                page_id.replace('-', ''),
                str(page_dir),
                str(self.separate_child_pages).lower()
            ]
            
            print(f"{'  ' * level}📄 Exporting: {page_title}")
            
            result = subprocess.run(
                args,
                capture_output=True,
                text=True,
                check=False
            )
            
            export_result = {
                'id': page_id,
                'title': page_title,
                'path': str(page_dir),
                'level': level,
                'is_database': is_database
            }
            
            if result.returncode == 0:
                try:
                    data = json.loads(result.stdout)
                    if data.get('success'):
                        export_result['success'] = True
                        export_result['files'] = data.get('pages', [{}])[0].get('files', [])
                        
                        # Rename main file to README.md for better GitHub viewing
                        for file_info in export_result['files']:
                            if file_info.get('type') == 'parent':
                                old_path = Path(file_info['path'])
                                if old_path.exists() and old_path.name != 'README.md':
                                    new_path = old_path.parent / 'README.md'
                                    old_path.rename(new_path)
                                    file_info['path'] = str(new_path)
                    else:
                        export_result['success'] = False
                        export_result['error'] = data.get('error', 'Unknown error')
                except:
                    export_result['success'] = False
                    export_result['error'] = result.stderr or result.stdout
            else:
                export_result['success'] = False
                export_result['error'] = result.stderr or result.stdout
            
            # Export children if they exist
            if page_info and 'children' in page_info:
                export_result['children'] = []
                for child in page_info['children']:
                    child_result = self.export_page_hierarchically(
                        child['id'],
                        str(page_dir),
                        child
                    )
                    export_result['children'].append(child_result)
            
            return export_result
            
        except Exception as e:
            return {
                'id': page_id,
                'title': page_title if 'page_title' in locals() else 'Unknown',
                'success': False,
                'error': str(e)
            }
    
    def save_structure_metadata(self, structure_data: Dict) -> None:
        """Save the structure metadata as JSON"""
        metadata_file = Path(self.output_dir) / 'structure.json'
        with open(metadata_file, 'w') as f:
            json.dump(structure_data, f, indent=2)
        print(f"\n📋 Structure metadata saved to: {metadata_file}")
    
    def create_index_md(self, export_results: Dict) -> None:
        """Create an index.md file with the structure"""
        index_file = Path(self.output_dir) / 'INDEX.md'
        
        def write_tree(f, item, indent=0):
            prefix = "  " * indent
            icon = "📊" if item.get('is_database') else "📄"
            status = "✅" if item.get('success') else "❌"
            title = item.get('title', 'Untitled')
            
            # Make it a link if successful
            if item.get('success') and item.get('path'):
                rel_path = Path(item['path']).relative_to(self.output_dir)
                f.write(f"{prefix}- {status} {icon} [{title}]({rel_path}/README.md)\n")
            else:
                f.write(f"{prefix}- {status} {icon} {title}\n")
            
            # Write children
            for child in item.get('children', []):
                write_tree(f, child, indent + 1)
        
        with open(index_file, 'w') as f:
            f.write("# Notion Export Structure\n\n")
            f.write("This is the hierarchical structure of your Notion export.\n\n")
            f.write("## Legend\n")
            f.write("- 📄 Regular Page\n")
            f.write("- 📊 Database Page\n")
            f.write("- ✅ Successfully Exported\n")
            f.write("- ❌ Export Failed\n\n")
            f.write("## Structure\n\n")
            write_tree(f, export_results)
        
        print(f"📑 Index created at: {index_file}")
    
    def export(self) -> bool:
        """Main export function with hierarchy preservation"""
        print("=" * 50)
        print("🏗️  Hierarchical Notion to Markdown Exporter")
        print("=" * 50)
        print()
        
        if not self.validate_config():
            return False
        
        # Get the page structure first
        structure_data = self.get_page_structure()
        if not structure_data:
            print("❌ Failed to get page structure")
            return False
        
        print(f"\n📊 Found {structure_data.get('totalPages', 0)} pages in hierarchy")
        print("=" * 50)
        print()
        
        # Create output directory
        Path(self.output_dir).mkdir(parents=True, exist_ok=True)
        
        # Export pages hierarchically
        print("📥 Exporting ALL pages with structure...\n")
        
        # Export ALL pages from the scan results
        all_pages = structure_data.get('pages', [])
        export_results = {
            'success': True,
            'pages': []
        }
        
        # Group pages by their parent for organization
        pages_by_parent = {}
        for page in all_pages:
            parent_id = page.get('parent')
            if parent_id not in pages_by_parent:
                pages_by_parent[parent_id] = []
            pages_by_parent[parent_id].append(page)
        
        # Create directories based on page titles
        for page in all_pages:
            page_id = page['id']
            page_title = page.get('title', 'Untitled')
            parent_id = page.get('parent')
            level = page.get('level', 0)
            is_db = page.get('fromDatabase', False)
            
            # Determine the path based on parent relationships
            if level == 0:
                # Root page
                page_path = Path(self.output_dir)
            elif level == 1:
                # Top-level sections
                safe_title = "".join(c for c in page_title if c.isalnum() or c in (' ', '-', '_')).rstrip()[:100]
                page_path = Path(self.output_dir) / safe_title
            else:
                # Find parent path
                parent_page = next((p for p in all_pages if p['id'] == parent_id), None)
                if parent_page:
                    parent_title = parent_page.get('title', 'Untitled')
                    safe_parent = "".join(c for c in parent_title if c.isalnum() or c in (' ', '-', '_')).rstrip()[:100]
                    safe_title = "".join(c for c in page_title if c.isalnum() or c in (' ', '-', '_')).rstrip()[:100]
                    
                    if parent_page.get('level', 0) == 0:
                        page_path = Path(self.output_dir) / safe_title
                    else:
                        page_path = Path(self.output_dir) / safe_parent / safe_title
                else:
                    safe_title = "".join(c for c in page_title if c.isalnum() or c in (' ', '-', '_')).rstrip()[:100]
                    page_path = Path(self.output_dir) / safe_title
            
            # Create directory
            page_path.mkdir(parents=True, exist_ok=True)
            
            # Export the page content
            print(f"{'  ' * level}📄 Exporting: {page_title}")
            
            # Use notion_export.js to export the actual content
            args = [
                'node',
                'notion_export.js',
                self.notion_token,
                page_id.replace('-', ''),
                str(page_path),
                'true'
            ]
            
            try:
                result = subprocess.run(
                    args,
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                if result.returncode == 0:
                    export_results['pages'].append({
                        'id': page_id,
                        'title': page_title,
                        'path': str(page_path),
                        'success': True
                    })
                else:
                    export_results['pages'].append({
                        'id': page_id,
                        'title': page_title,
                        'path': str(page_path),
                        'success': False,
                        'error': result.stderr or result.stdout
                    })
            except Exception as e:
                export_results['pages'].append({
                    'id': page_id,
                    'title': page_title,
                    'path': str(page_path),
                    'success': False,
                    'error': str(e)
                })
        
        if export_results:
            # Save metadata
            self.save_structure_metadata(structure_data)
            
            # Create index file
            self.create_index_md(export_results)
            
            print("\n" + "=" * 50)
            print("✅ Export completed with hierarchical structure!")
            print(f"📁 Files saved to: {self.output_dir}/")
            print(f"📑 Check INDEX.md for navigation")
            print("=" * 50)
            return True
        else:
            print("❌ Export failed")
            return False

def main():
    """Main entry point"""
    exporter = HierarchicalNotionExporter()
    success = exporter.export()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()