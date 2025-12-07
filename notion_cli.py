#!/usr/bin/env python3
"""
Notion Export CLI
Unified command-line interface for all Notion export operations
"""

import os
import sys
import json
import argparse
import subprocess
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Colors for terminal output
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def print_header(text):
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'=' * 50}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{text}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{'=' * 50}{Colors.ENDC}\n")

def print_success(text):
    print(f"{Colors.GREEN}✅ {text}{Colors.ENDC}")

def print_error(text):
    print(f"{Colors.RED}❌ {text}{Colors.ENDC}")

def print_info(text):
    print(f"{Colors.BLUE}ℹ️  {text}{Colors.ENDC}")

def print_warning(text):
    print(f"{Colors.YELLOW}⚠️  {text}{Colors.ENDC}")

def check_config():
    """Verify required configuration is present"""
    token = os.getenv('NOTION_TOKEN')
    page_id = os.getenv('NOTION_PAGE_ID') or os.getenv('NOTION_PAGE_IDS')
    
    if not token:
        print_error("NOTION_TOKEN not found in environment or .env file")
        print_info("Get your token from: https://www.notion.so/my-integrations")
        return False
    
    if not page_id:
        print_error("NOTION_PAGE_ID not found in environment or .env file")
        print_info("Copy the page ID from your Notion page URL")
        return False
    
    return True

def run_docker_command(cmd, timeout=300):
    """Run a docker-compose command with proper error handling"""
    # Detect docker compose command
    docker_compose = "docker-compose"
    try:
        result = subprocess.run(["docker", "compose", "version"], 
                              capture_output=True, check=False)
        if result.returncode == 0:
            docker_compose = "docker compose"
    except:
        pass
    
    full_cmd = f"{docker_compose} {cmd}"
    
    try:
        result = subprocess.run(
            full_cmd.split(),
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=Path(__file__).parent
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"
    except Exception as e:
        return False, "", str(e)

def save_export_metadata(output_dir, stats):
    """Save metadata about the export for tracking"""
    metadata_file = Path(output_dir) / '.export_metadata.json'
    
    metadata = {
        'last_export': datetime.now().isoformat(),
        'pages_exported': stats.get('pages', 0),
        'errors': stats.get('errors', 0),
        'duration_seconds': stats.get('duration', 0),
        'export_history': []
    }
    
    # Load existing history if present
    if metadata_file.exists():
        try:
            with open(metadata_file) as f:
                existing = json.load(f)
                metadata['export_history'] = existing.get('export_history', [])[-9:]  # Keep last 10
        except:
            pass
    
    # Add this export to history
    metadata['export_history'].append({
        'timestamp': metadata['last_export'],
        'pages': stats.get('pages', 0),
        'errors': stats.get('errors', 0)
    })
    
    with open(metadata_file, 'w') as f:
        json.dump(metadata, f, indent=2)
    
    return metadata_file

def cmd_scan(args):
    """Scan Notion for page IDs"""
    print_header("🔍 Scanning Notion Pages")
    
    if not check_config():
        return 1
    
    print_info("Building Docker image...")
    success, _, err = run_docker_command("build")
    if not success:
        print_error(f"Docker build failed: {err}")
        return 1
    
    print_info("Scanning pages...")
    success, out, err = run_docker_command("run --rm notion-export python get_page_ids.py")
    
    if success:
        print_success("Scan complete! Page IDs have been saved to .env")
    else:
        print_error(f"Scan failed: {err}")
        return 1
    
    return 0

def cmd_export(args):
    """Export Notion pages to Markdown"""
    print_header("📥 Exporting Notion to Markdown")
    
    if not check_config():
        return 1
    
    start_time = datetime.now()
    output_dir = args.output or os.getenv('OUTPUT_DIR', './output')
    
    # Clean output if requested
    if args.clean:
        print_warning(f"Cleaning output directory: {output_dir}")
        import shutil
        if Path(output_dir).exists():
            shutil.rmtree(output_dir)
    
    print_info("Building Docker image...")
    success, _, err = run_docker_command("build")
    if not success:
        print_error(f"Docker build failed: {err}")
        return 1
    
    # Scan first if requested
    if args.scan_first:
        print_info("Scanning for pages first...")
        success, _, err = run_docker_command("run --rm notion-export python get_page_ids.py")
        if not success:
            print_error(f"Scan failed: {err}")
            return 1
        # Reload env to get new page IDs
        load_dotenv(override=True)
    
    print_info("Exporting pages...")
    success, out, err = run_docker_command("run --rm notion-export python export_notion.py", timeout=600)
    
    duration = (datetime.now() - start_time).total_seconds()
    
    if success:
        # Count exported files
        md_files = list(Path(output_dir).rglob('*.md')) if Path(output_dir).exists() else []
        stats = {
            'pages': len(md_files),
            'errors': 0,
            'duration': duration
        }
        
        # Save metadata
        metadata_file = save_export_metadata(output_dir, stats)
        
        print_success(f"Export complete! {len(md_files)} files in {duration:.1f}s")
        print_info(f"Output: {output_dir}/")
        print_info(f"Metadata: {metadata_file}")
    else:
        print_error(f"Export failed: {err}")
        return 1
    
    return 0

def cmd_full(args):
    """Run full scan + export workflow"""
    print_header("🚀 Full Notion Export (Scan + Export)")
    
    args.scan_first = True
    args.clean = args.clean if hasattr(args, 'clean') else False
    args.output = args.output if hasattr(args, 'output') else None
    
    return cmd_export(args)

def cmd_status(args):
    """Show export status and history"""
    print_header("📊 Export Status")
    
    output_dir = args.output or os.getenv('OUTPUT_DIR', './output')
    metadata_file = Path(output_dir) / '.export_metadata.json'
    
    if not Path(output_dir).exists():
        print_warning("Output directory does not exist. Run an export first.")
        return 0
    
    # Count files
    md_files = list(Path(output_dir).rglob('*.md'))
    folders = [d for d in Path(output_dir).iterdir() if d.is_dir()]
    
    print(f"\n{Colors.CYAN}📁 Output Directory:{Colors.ENDC} {output_dir}")
    print(f"{Colors.CYAN}📄 Markdown Files:{Colors.ENDC} {len(md_files)}")
    print(f"{Colors.CYAN}📂 Folders:{Colors.ENDC} {len(folders)}")
    
    if metadata_file.exists():
        with open(metadata_file) as f:
            metadata = json.load(f)
        
        print(f"\n{Colors.CYAN}🕐 Last Export:{Colors.ENDC} {metadata.get('last_export', 'Unknown')}")
        
        history = metadata.get('export_history', [])
        if history:
            print(f"\n{Colors.CYAN}📜 Export History (last 5):{Colors.ENDC}")
            for entry in history[-5:]:
                print(f"   • {entry['timestamp']}: {entry['pages']} pages, {entry['errors']} errors")
    else:
        print_info("No export metadata found. Run an export to generate.")
    
    return 0

def cmd_clean(args):
    """Clean output directory"""
    print_header("🧹 Cleaning Output")
    
    output_dir = args.output or os.getenv('OUTPUT_DIR', './output')
    
    if not Path(output_dir).exists():
        print_info("Output directory does not exist. Nothing to clean.")
        return 0
    
    import shutil
    
    # Count before cleaning
    md_files = list(Path(output_dir).rglob('*.md'))
    
    if not args.yes:
        response = input(f"Delete {len(md_files)} files in {output_dir}? [y/N]: ")
        if response.lower() != 'y':
            print_info("Cancelled.")
            return 0
    
    shutil.rmtree(output_dir)
    print_success(f"Cleaned {len(md_files)} files from {output_dir}")
    
    return 0

def main():
    parser = argparse.ArgumentParser(
        description='Notion Export CLI - Export Notion pages to Markdown',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python notion_cli.py scan              # Scan for page IDs
  python notion_cli.py export            # Export pages to markdown
  python notion_cli.py full              # Scan + Export in one command
  python notion_cli.py full --clean      # Clean first, then scan + export
  python notion_cli.py status            # Show export status
  python notion_cli.py clean             # Clean output directory
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Scan command
    scan_parser = subparsers.add_parser('scan', help='Scan Notion for page IDs')
    
    # Export command
    export_parser = subparsers.add_parser('export', help='Export pages to Markdown')
    export_parser.add_argument('--output', '-o', help='Output directory')
    export_parser.add_argument('--clean', '-c', action='store_true', help='Clean output before export')
    export_parser.add_argument('--scan-first', '-s', action='store_true', help='Scan for pages before export')
    
    # Full command (scan + export)
    full_parser = subparsers.add_parser('full', help='Full workflow: scan + export')
    full_parser.add_argument('--output', '-o', help='Output directory')
    full_parser.add_argument('--clean', '-c', action='store_true', help='Clean output before export')
    
    # Status command
    status_parser = subparsers.add_parser('status', help='Show export status')
    status_parser.add_argument('--output', '-o', help='Output directory')
    
    # Clean command
    clean_parser = subparsers.add_parser('clean', help='Clean output directory')
    clean_parser.add_argument('--output', '-o', help='Output directory')
    clean_parser.add_argument('--yes', '-y', action='store_true', help='Skip confirmation')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 0
    
    commands = {
        'scan': cmd_scan,
        'export': cmd_export,
        'full': cmd_full,
        'status': cmd_status,
        'clean': cmd_clean,
    }
    
    return commands[args.command](args)

if __name__ == '__main__':
    sys.exit(main())

