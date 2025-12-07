#!/usr/bin/env python3
"""
Organize the exported files into proper structure based on Notion hierarchy
"""

import os
import shutil
from pathlib import Path

# Define the proper structure based on your Notion
STRUCTURE = {
    "Databases": {
        "1. Activity Log (80+ Required)": [
            "Abruptly Cancelled",
            "Convert UKB PDFs to MD and JSON", 
            "Convert UKB PDF to MD",
            "Convert UKB PDF to MD error 2",
            "Download More PDFs",
            "Download PDFs",
            "Extract DOI Numbers",
            "Final PDF Collection",
            "Project Notebook Discussion",
            "normalisation",
            "Run convert_pdfspy",
            "Template"
        ],
        "2. Supervisor Meetings (10+ Required)": [
            "Introduction and Research Proposal Discussion",
            "RAG Discussion",
            "Refocus Research Question",
            "Hypothsis Validation Options"
        ],
        "3. Experiments & Validation (8+ Required)": [
            "Benchmark Embedding Models for Phenotype Similarity",
            "test"
        ],
        "4. Literature Review (30+ Papers)": [
            "Contextual Word Embedding for Biomedical Knowledge Extraction",
            "Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks",
            "Survey of Vector Database Management Systems",
            "UK Biobank An Open Access Resource",
            "The Monarch Initiative Integrative Data Platform"
        ],
        "5. Issues & Debugging (15+ Required)": [
            "Error",
            "Metadata Correction",
            "Metadata Correction Continued",
            "Threadripper  AMD Trouble",
            "Threadripper RAM Trouble Continued",
            "UKB Source Metadata Infected"
        ],
        "6. Weekly Summaries (12+ Required)": [
            "Week 1 - Project Setup"
        ],
        "7. Code Implementations (10+ Required)": [
            "FAISS",
            "LangChain", 
            "LlamaIndex",
            "Milvus",
            "PyTorch",
            "Transformers",
            "Weaviate",
            "RAG Pipeline Core"
        ],
        "8. System Architecture & Infrastructure": [
            "Docker Extension",
            "Python Runtime",
            "RooCode Extension",
            "Ubuntu Desktop",
            "VS Code",
            "Workstation 1 - Development",
            "Workstation 2 - Testing",
            "GPU - Workstation 1"
        ],
        "9. Prompts & Templates": [
            "Synonym Generation Prompt for UK Biobank Fields",
            "Synonym Generator Evaluation"
        ]
    },
    "Research Pages": {
        ".": [  # Direct children
            "Project Overview",
            "Research Methods", 
            "Pipeline Architecture"
        ],
        "Journals": [
            "Understanding MD Feature Extraction Journals",
            "Field-Weighted XML Retrieval Based on BM25"
        ]
    },
    "Progress Tracking": {
        ".": []  # Add any progress tracking pages here
    }
}

def organize_files():
    """Reorganize the output directory into proper structure"""
    output_dir = Path("output")
    
    if not output_dir.exists():
        print("❌ Output directory not found!")
        return
    
    # Create new organized structure
    organized_dir = Path("output_organized")
    organized_dir.mkdir(exist_ok=True)
    
    print("📁 Creating organized structure...")
    
    # Process each main section
    for main_section, databases in STRUCTURE.items():
        main_path = organized_dir / main_section
        main_path.mkdir(exist_ok=True)
        print(f"\n📂 {main_section}/")
        
        for db_name, pages in databases.items():
            if db_name == ".":
                # Direct children of the section
                db_path = main_path
            else:
                db_path = main_path / db_name
                db_path.mkdir(exist_ok=True)
                print(f"  📁 {db_name}/")
            
            # Move matching pages
            for page_name in pages:
                # Try to find the page directory
                for item in output_dir.iterdir():
                    if item.is_dir() and item.name == page_name:
                        # Copy the entire directory
                        dest = db_path / page_name
                        if item.exists():
                            shutil.copytree(item, dest, dirs_exist_ok=True)
                            print(f"    ✅ Moved: {page_name}")
                        break
    
    # Copy any remaining files that weren't categorized
    print("\n📋 Copying uncategorized files...")
    for item in output_dir.iterdir():
        if item.name not in ["output_organized"]:
            dest = organized_dir / item.name
            if not dest.exists():
                if item.is_dir():
                    shutil.copytree(item, dest, dirs_exist_ok=True)
                else:
                    shutil.copy2(item, dest)
                print(f"  📄 {item.name}")
    
    print("\n✅ Organization complete! Check output_organized/ directory")
    print("\n📊 Structure created:")
    print("output_organized/")
    print("├── Databases/")
    print("│   ├── 1. Activity Log (80+ Required)/")
    print("│   ├── 2. Supervisor Meetings (10+ Required)/")
    print("│   ├── 3. Experiments & Validation (8+ Required)/")
    print("│   ├── 4. Literature Review (30+ Papers)/")
    print("│   ├── 5. Issues & Debugging (15+ Required)/")
    print("│   ├── 6. Weekly Summaries (12+ Required)/")
    print("│   ├── 7. Code Implementations (10+ Required)/")
    print("│   ├── 8. System Architecture & Infrastructure/")
    print("│   └── 9. Prompts & Templates/")
    print("├── Research Pages/")
    print("│   ├── Project Overview/")
    print("│   ├── Research Methods/")
    print("│   ├── Pipeline Architecture/")
    print("│   └── Journals/")
    print("└── Progress Tracking/")

if __name__ == "__main__":
    organize_files()