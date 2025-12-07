#!/usr/bin/env python3
"""
PROPERLY export and organize Notion pages with:
1. Create folder structure FIRST
2. Export files WITH TITLES into correct folders
3. Number files in sequence within each database
"""

import os
import sys
import json
import subprocess
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

class ProperNotionExporter:
    def __init__(self):
        self.notion_token = os.getenv('NOTION_TOKEN')
        self.notion_page_ids = os.getenv('NOTION_PAGE_IDS', '')
        self.output_dir = 'output_final'
        
    def run(self):
        """Main export with proper structure"""
        print("=" * 50)
        print("📁 CREATING PROPER FOLDER STRUCTURE FIRST")
        print("=" * 50)
        
        # Create the folder structure
        structure = {
            "Databases": [
                "1. Activity Log (80+ Required)",
                "2. Supervisor Meetings (10+ Required)", 
                "3. Experiments & Validation (8+ Required)",
                "4. Literature Review (30+ Papers)",
                "5. Issues & Debugging (15+ Required)",
                "6. Weekly Summaries (12+ Required)",
                "7. Code Implementations (10+ Required)",
                "8. System Architecture & Infrastructure",
                "9. Prompts & Templates"
            ],
            "Research Pages": [],
            "Progress Tracking": []
        }
        
        # Create all folders
        Path(self.output_dir).mkdir(exist_ok=True)
        for main_folder, subfolders in structure.items():
            main_path = Path(self.output_dir) / main_folder
            main_path.mkdir(exist_ok=True)
            print(f"✅ Created {main_folder}/")
            
            for subfolder in subfolders:
                sub_path = main_path / subfolder
                sub_path.mkdir(exist_ok=True)
                print(f"   📁 {subfolder}/")
        
        print("\n" + "=" * 50)
        print("📥 EXPORTING PAGES WITH PROPER NAMES")
        print("=" * 50)
        
        # Parse page IDs
        page_ids = [pid.strip() for pid in self.notion_page_ids.split(',') if pid.strip()]
        
        # Track counters for each database
        db_counters = {f"{i}": 0 for i in range(1, 10)}
        
        # Export each page
        for idx, page_id in enumerate(page_ids, 1):
            clean_id = page_id.replace('-', '')
            
            # Get page title using Node.js
            print(f"\n[{idx}/{len(page_ids)}] Processing {clean_id[:8]}...")
            
            # First get the page title
            js_code = f'''
            const {{Client}} = require("@notionhq/client");
            const notion = new Client({{auth: "{self.notion_token}"}});
            
            async function getInfo() {{
                try {{
                    const page = await notion.pages.retrieve({{page_id: "{clean_id}"}});
                    let title = "Untitled";
                    
                    // Try to get title
                    for (const [key, value] of Object.entries(page.properties)) {{
                        if (value.type === 'title' && value.title?.[0]?.plain_text) {{
                            title = value.title[0].plain_text;
                            break;
                        }}
                    }}
                    
                    // Get parent info
                    const parent = page.parent;
                    
                    console.log(JSON.stringify({{
                        title: title,
                        parent_type: parent.type,
                        parent_id: parent.database_id || parent.page_id || null
                    }}));
                }} catch (e) {{
                    console.log(JSON.stringify({{title: "Error", parent_type: null, parent_id: null}}));
                }}
            }}
            getInfo();
            '''
            
            result = subprocess.run(
                ['docker', 'compose', 'run', '--rm', 'notion-export', 'node', '-e', js_code],
                capture_output=True,
                text=True
            )
            
            try:
                info = json.loads(result.stdout.strip().split('\n')[-1])
                title = info.get('title', 'Untitled')
            except:
                title = f"Page_{idx}"
            
            print(f"   📄 Title: {title}")
            
            # Determine which folder this belongs to based on title/content
            folder = self.determine_folder(title, idx)
            
            # Determine the database number and increment counter
            db_num = folder.split('.')[0] if '.' in folder else '0'
            if db_num in db_counters:
                db_counters[db_num] += 1
                filename = f"{db_counters[db_num]:02d}. {title}.md"
            else:
                filename = f"{title}.md"
            
            # Clean filename
            filename = "".join(c for c in filename if c.isalnum() or c in (' ', '-', '_', '.')).rstrip()
            
            # Export to the correct folder
            if '.' in folder:  # It's a database folder
                output_path = Path(self.output_dir) / "Databases" / folder
            else:
                output_path = Path(self.output_dir) / folder
            
            output_file = output_path / filename
            
            # Export the actual content
            export_result = subprocess.run(
                ['docker', 'compose', 'run', '--rm', 'notion-export', 
                 'node', 'notion_export.js', self.notion_token, clean_id, str(output_path), 'true'],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if export_result.returncode == 0:
                print(f"   ✅ Exported to: {folder}/{filename}")
            else:
                print(f"   ❌ Failed to export")
        
        print("\n" + "=" * 50)
        print("✅ EXPORT COMPLETE WITH PROPER STRUCTURE!")
        print(f"📁 Check {self.output_dir}/ for organized files")
        print("=" * 50)
    
    def determine_folder(self, title, idx):
        """Determine which folder a page belongs to based on title"""
        title_lower = title.lower()
        
        # Map titles to folders
        if any(x in title_lower for x in ['abrupt', 'cancel', 'convert', 'ukb', 'pdf', 'download', 'extract', 'final', 'collection', 'normalis']):
            return "1. Activity Log (80+ Required)"
        elif any(x in title_lower for x in ['introduction', 'rag discussion', 'refocus', 'hypothsis', 'proposal', 'supervisor']):
            return "2. Supervisor Meetings (10+ Required)"
        elif any(x in title_lower for x in ['benchmark', 'test', 'experiment', 'validation']):
            return "3. Experiments & Validation (8+ Required)"
        elif any(x in title_lower for x in ['contextual', 'retrieval', 'survey', 'biobank', 'monarch', 'paper', 'literature']):
            return "4. Literature Review (30+ Papers)"
        elif any(x in title_lower for x in ['error', 'metadata', 'threadripper', 'trouble', 'infected', 'debug', 'issue']):
            return "5. Issues & Debugging (15+ Required)"
        elif any(x in title_lower for x in ['week', 'summary', 'weekly']):
            return "6. Weekly Summaries (12+ Required)"
        elif any(x in title_lower for x in ['faiss', 'langchain', 'llama', 'milvus', 'pytorch', 'transform', 'weaviate', 'pipeline', 'code']):
            return "7. Code Implementations (10+ Required)"
        elif any(x in title_lower for x in ['docker', 'python', 'roocode', 'ubuntu', 'vs code', 'workstation', 'gpu', 'system', 'infrastructure']):
            return "8. System Architecture & Infrastructure"
        elif any(x in title_lower for x in ['synonym', 'prompt', 'template']):
            return "9. Prompts & Templates"
        elif any(x in title_lower for x in ['research', 'method', 'overview', 'architecture']):
            return "Research Pages"
        elif any(x in title_lower for x in ['progress', 'tracking']):
            return "Progress Tracking"
        else:
            return "Databases"  # Default

if __name__ == "__main__":
    exporter = ProperNotionExporter()
    exporter.run()