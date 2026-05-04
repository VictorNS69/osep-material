#!/usr/bin/env python3
"""
IP/URL Replacer Script
Recursively searches through specified file types and replaces URLs/IPs with a new value.
"""

import os
import re
import shutil
import argparse
from pathlib import Path
from typing import List, Tuple, Set
from datetime import datetime

# ANSI color codes
COLORS = {
    'RED': '\033[91m',
    'GREEN': '\033[92m',
    'YELLOW': '\033[93m',
    'BLUE': '\033[94m',
    'MAGENTA': '\033[95m',
    'CYAN': '\033[96m',
    'WHITE': '\033[97m',
    'BOLD': '\033[1m',
    'UNDERLINE': '\033[4m',
    'END': '\033[0m',
}

def color_text(text, color):
    """Colorize text with ANSI codes"""
    return f"{COLORS.get(color.upper(), '')}{text}{COLORS['END']}"

# Default excluded directories (exact directory names)
DEFAULT_EXCLUDED_DIRS = {'backup', '.git', '.gitmodules', 'Tools', 'tunneling/ligolo'}

# Default excluded files (to prevent self-modification)
DEFAULT_EXCLUDED_FILES = {'ip-replace.py', 'ip-replace.pyc', '__pycache__', 'simple-http-post-server.py'}

# File extensions to process
TARGET_EXTENSIONS = {'.ps1', '.hta', '.cs', '.sh', '.py', '.aspx', '.c', '.vba'}

class URLReplacer:
    def __init__(self, search_pattern: str, replace_url: str, backup_dir: str = None, 
                 dry_run: bool = False, confirm: bool = True, excluded_dirs: Set[str] = None):
        self.search_pattern = search_pattern
        self.replace_url = replace_url
        self.backup_dir = backup_dir
        self.dry_run = dry_run
        self.confirm = confirm
        self.excluded_dirs = excluded_dirs or DEFAULT_EXCLUDED_DIRS
        self.excluded_files = DEFAULT_EXCLUDED_FILES
        self.files_processed = 0
        self.files_modified = 0
        self.files_backed_up = 0
        self.total_replacements = 0
        self.total_errors = 0
        self.files_with_matches = 0
        self.start_path = Path.cwd()  # Store the starting path
        
        # Create backup directory with timestamp if not in dry-run mode
        if not self.dry_run and self.backup_dir:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            self.backup_path = Path(self.backup_dir).resolve() / f"backup_{timestamp}"
            self.backup_path.mkdir(parents=True, exist_ok=True)
        else:
            self.backup_path = None
        
    def should_exclude_path(self, file_path: Path) -> bool:
        """Check if a file path should be excluded based on directory names or filenames."""
        path_str = str(file_path)
        
        # Check if file should be excluded by name
        if file_path.name in self.excluded_files:
            return True
        
        # Check each excluded pattern
        for excluded in self.excluded_dirs:
            # Exact match for directory name in any part of the path
            if excluded in path_str.split(os.sep):
                return True
            # Check if excluded pattern is a subpath 
            if excluded.replace('/', os.sep) in path_str:
                return True
        
        return False
    
    def backup_file(self, file_path: Path) -> bool:
        """Create a backup of the file in the backup directory."""
        if self.dry_run:
            return True
        
        if not self.backup_path:
            raise ValueError("Backup directory not initialized. Use --backup-dir parameter.")
            
        try:
            # Resolve to absolute paths
            abs_file_path = file_path.resolve()
            abs_start_path = self.start_path.resolve()
            
            # Create relative path structure in backup directory
            try:
                relative_path = abs_file_path.relative_to(abs_start_path)
            except ValueError:
                # If file is outside start path, use the full path name (replace slashes)
                relative_path = Path(str(abs_file_path).replace('/', '_').replace('\\', '_'))
            
            backup_file_path = self.backup_path / relative_path
            
            # Create parent directories if they don't exist
            backup_file_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Copy the file
            shutil.copy2(abs_file_path, backup_file_path)
            self.files_backed_up += 1
            
            print(f"{color_text('[*]', 'cyan')} Backed up: {file_path} -> {backup_file_path}")
            
            return True
        except Exception as e:
            print(f"{color_text('[!]', 'red')} Failed to backup {file_path}: {e}")
            self.total_errors += 1
            return False
    
    def show_line_diff(self, before_line: str, after_line: str, line_num: int, max_width: int = 150):
        """Show a colored diff of a single line."""
        print(f"  {color_text(f'Line {line_num}:', 'yellow')}")
        
        # Truncate long lines for display
        if len(before_line) > max_width:
            before_display = before_line[:max_width] + "..."
            after_display = after_line[:max_width] + "..."
        else:
            before_display = before_line
            after_display = after_line
        
        # Show old line in red
        print(f"    {color_text('-', 'red')} {color_text(before_display, 'red')}")
        # Show new line in green
        print(f"    {color_text('+', 'green')} {color_text(after_display, 'green')}")
    
    def replace_in_file(self, file_path: Path) -> Tuple[bool, int]:
        """Replace URLs in a single file. Returns (modified, replacement_count)."""
        replacement_count = 0
        modified_lines = []
        
        try:
            # Read file content
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
            
            new_lines = []
            file_modified = False
            
            # Process each line
            for line_num, line in enumerate(lines, start=1):
                original_line = line.rstrip('\n\r')
                new_line = original_line
                line_replacements = 0
                
                # If search pattern is provided, replace it directly with replace_url
                if self.search_pattern:
                    # Escape special regex characters in search pattern
                    escaped_pattern = re.escape(self.search_pattern)
                    new_line, line_replacements = re.subn(escaped_pattern, self.replace_url, original_line)
                    
                    # Also try with word boundaries if needed (for partial URLs)
                    if line_replacements == 0:
                        # Try to replace just the domain/IP part while keeping the protocol
                        # Extract protocol and rest from search pattern
                        search_match = re.match(r'(https?://)?(.+)', self.search_pattern)
                        if search_match:
                            search_proto = search_match.group(1) or ''
                            search_rest = search_match.group(2)
                            
                            replace_full = self.replace_url
                            
                            # Pattern to match similar structure
                            flexible_pattern = re.compile(
                                f"({re.escape(search_proto)})?{re.escape(search_rest)}",
                                re.IGNORECASE
                            )
                            new_line, line_replacements = flexible_pattern.subn(replace_full, original_line)
                else:
                    # Replace all URLs with the new URL
                    # This matches any URL pattern (http://, https://) followed by domain/IP and optional port/path
                    url_pattern = re.compile(
                        r'(https?://|ftp://)[a-zA-Z0-9.-]+(?::[0-9]+)?(?:/[^\s\'"<>\(\)\[\]{}]*)?',
                        re.IGNORECASE
                    )
                    new_line, line_replacements = url_pattern.subn(self.replace_url, original_line)
                    
                    # Also match standalone IPs (without protocol)
                    ip_pattern = re.compile(
                        r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b(?::[0-9]+)?(?:/[^\s\'"<>\(\)\[\]{}]*)?',
                        re.IGNORECASE
                    )
                    new_line, ip_count = ip_pattern.subn(self.replace_url, new_line)
                    line_replacements += ip_count
                
                if line_replacements > 0:
                    file_modified = True
                    replacement_count += line_replacements
                    # ALWAYS store changes for preview (both dry-run and normal mode)
                    modified_lines.append((line_num, original_line, new_line))
                
                # Preserve original line ending
                if line.endswith('\n'):
                    new_lines.append(new_line + '\n')
                else:
                    new_lines.append(new_line)
            
            # Check if any changes were made
            if not file_modified:
                return False, 0
            
            self.files_with_matches += 1
            self.total_replacements += replacement_count
            
            # Show changes in dry-run mode
            if self.dry_run:
                print(f"\n{color_text('[DRY RUN]', 'yellow')} Would modify: {file_path}")
                print(f"{color_text(f'  Replacements: {replacement_count}', 'cyan')}")
                print("-" * 70)
                # Show all modified lines with full red/green coloring
                for line_num, before, after in modified_lines[:10]:  # Show up to 10 lines
                    self.show_line_diff(before, after, line_num)
                if len(modified_lines) > 10:
                    print(f"  {color_text(f'... and {len(modified_lines) - 10} more lines with changes', 'cyan')}")
                print("-" * 70)
                return True, replacement_count
            
            # Confirm before modifying if enabled
            if self.confirm:
                print(f"\n{color_text('[*]', 'cyan')} File: {file_path}")
                print(f"    {color_text(f'Replacements found: {replacement_count}', 'yellow')}")
                print(f"    {color_text('Preview of changes:', 'cyan')}")
                print("-" * 70)
                # Show first 3 changes as preview
                for line_num, before, after in modified_lines[:3]:
                    self.show_line_diff(before, after, line_num)
                if len(modified_lines) > 3:
                    print(f"    {color_text(f'... and {len(modified_lines) - 3} more lines with changes', 'cyan')}")
                print("-" * 70)
                response = input(f"    {color_text('Modify this file? [y/N/q] (q to quit): ', 'cyan')}").lower()
                if response == 'q':
                    print(f"{color_text('[!]', 'red')} User quit")
                    exit(0)
                elif response != 'y':
                    print(f"    {color_text('Skipping', 'yellow')} {file_path}")
                    return False, 0
            
            # Create backup (mandatory unless dry-run)
            if not self.backup_file(file_path):
                print(f"{color_text('[!]', 'red')} Backup failed, skipping modification")
                return False, 0
            
            # Write the modified content
            with open(file_path, 'w', encoding='utf-8', newline='') as f:
                f.writelines(new_lines)
            
            print(f"{color_text('[+]', 'green')} Modified: {file_path} ({replacement_count} replacement{'s' if replacement_count != 1 else ''})")
            return True, replacement_count
            
        except Exception as e:
            print(f"{color_text('[!]', 'red')} Error processing {file_path}: {e}")
            self.total_errors += 1
            return False, 0
    
    def process_directory(self, start_path: str = '.'):
        """Recursively process all target files in directory."""
        self.start_path = Path(start_path).resolve()
        
        # Print header
        print("\n" + "=" * 80)
        print(color_text(" URL/IP Replacement Tool ", 'bold') + color_text("v2.0", 'cyan'))
        print("=" * 80)
        print(f"{color_text('Starting directory:', 'cyan')} {self.start_path}")
        print(f"{color_text('Search pattern:', 'cyan')} {self.search_pattern or 'All URLs/IPs'}")
        print(f"{color_text('Replace with:', 'cyan')} {color_text(self.replace_url, 'green')}")
        print(f"{color_text('File types:', 'cyan')} {', '.join(TARGET_EXTENSIONS)}")
        print(f"{color_text('Excluded dirs:', 'cyan')} {', '.join(self.excluded_dirs)}")
        print(f"{color_text('Excluded files:', 'cyan')} {', '.join(self.excluded_files)}")
        
        if self.dry_run:
            print(color_text('[*] DRY RUN MODE - No files will be modified', 'yellow'))
        else:
            if self.backup_dir:
                print(f"{color_text('Backup directory:', 'cyan')} {self.backup_path}")
                print(color_text('[*] BACKUP MODE ENABLED - Files will be backed up before modification', 'green'))
            else:
                print(color_text('[!] WARNING: No backup directory specified. Backup is recommended!', 'yellow'))
        
        if self.confirm and not self.dry_run:
            print(color_text('[*] Interactive mode - Will ask for confirmation before each modification', 'cyan'))
        print("=" * 80)
        print()
        
        # Walk through directory
        for root, dirs, files in os.walk(self.start_path):
            # Modify dirs in-place to skip excluded directories
            root_path = Path(root)
            
            # Filter out excluded directories from traversal
            filtered_dirs = []
            for d in dirs:
                should_exclude = False
                d_path = root_path / d
                if self.should_exclude_path(d_path):
                    should_exclude = True
                if not should_exclude:
                    filtered_dirs.append(d)
            dirs[:] = filtered_dirs
            
            for file in files:
                file_path = root_path / file
                
                # Check if file extension matches
                if file_path.suffix.lower() not in TARGET_EXTENSIONS:
                    continue
                
                # Check if path should be excluded
                if self.should_exclude_path(file_path):
                    continue
                
                self.files_processed += 1
                modified, count = self.replace_in_file(file_path)
                if modified:
                    self.files_modified += 1
        
        # Print colored summary
        self.print_summary()
    
    def print_summary(self):
        """Print a colored summary of the operation."""
        print("\n" + "=" * 80)
        print(color_text(" SUMMARY ", 'bold') + color_text("=" * 71, 'cyan'))
        print("=" * 80)
        
        # Mode
        mode = "DRY RUN" if self.dry_run else ("Interactive" if self.confirm else "Automatic")
        mode_color = 'yellow' if self.dry_run else ('cyan' if self.confirm else 'green')
        print(f"  {color_text('Mode:', 'cyan')} {color_text(mode, mode_color)}")
        
        # Statistics
        print(f"  {color_text('Files processed:', 'cyan')} {self.files_processed}")
        print(f"  {color_text('Files with matches:', 'cyan')} {color_text(str(self.files_with_matches), 'yellow') if self.files_with_matches > 0 else '0'}")
        print(f"  {color_text('Files modified:', 'cyan')} {color_text(str(self.files_modified), 'green') if self.files_modified > 0 else '0'}")
        print(f"  {color_text('Total replacements:', 'cyan')} {color_text(str(self.total_replacements), 'green') if self.total_replacements > 0 else '0'}")
        
        if not self.dry_run and self.backup_path:
            print(f"  {color_text('Files backed up:', 'cyan')} {color_text(str(self.files_backed_up), 'blue') if self.files_backed_up > 0 else '0'}")
            if self.files_backed_up > 0:
                print(f"  {color_text('Backup location:', 'cyan')} {self.backup_path}")
        
        if self.total_errors > 0:
            print(f"  {color_text('Errors:', 'cyan')} {color_text(str(self.total_errors), 'red')}")
        
        # Success/Error indicators
        print("  " + "-" * 76)
        if self.dry_run:
            print(f"  {color_text('⚠️  DRY RUN COMPLETE - No files were actually modified', 'yellow')}")
        elif self.total_errors == 0 and self.files_modified > 0:
            print(f"  {color_text('✅ SUCCESS - All operations completed successfully!', 'green')}")
            if self.backup_path:
                print(f"  {color_text('📦 Backups saved to:', 'cyan')} {self.backup_path}")
        elif self.total_errors == 0 and self.files_modified == 0:
            print(f"  {color_text('ℹ️  No matching patterns found in any files', 'cyan')}")
        else:
            print(f"  {color_text('⚠️  COMPLETED WITH ERRORS - Check the output above', 'red')}")
        
        print("=" * 80 + "\n")

def main():
    parser = argparse.ArgumentParser(
        description='Search and replace URLs/IPs in various file types',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Replace specific URL (backup is mandatory unless dry-run)
  python ip-replace.py --search "http://192.168.1.100" --replace-url "http://10.0.0.1" --backup-dir ./backups
  
  # Replace all URLs with new URL
  python ip-replace.py --replace-url "http://10.0.0.1" --backup-dir ./backups
  
  # Dry run (no backup needed, no files modified)
  python ip-replace.py --search "http://192.168.1.100" --replace-url "http://10.0.0.1" --dry-run
  
  # With no confirmation (automatic mode)
  python ip-replace.py --search "http://192.168.1.100" --replace-url "http://10.0.0.1" --backup-dir ./backups --no-confirm
  
  # Custom excluded directories
  python ip-replace.py --replace-url "http://10.0.0.1" --backup-dir ./backups --exclude-dirs "Tools" "test" ".venv"
        """
    )
    
    parser.add_argument('--search', 
                       help='Specific URL/IP pattern to search for (e.g., "http://192.168.1.100"). '
                            'If not provided, will replace any URL/IP found')
    
    parser.add_argument('--replace-url', 
                       required=True,
                       help='URL/IP to replace with (e.g., "http://10.0.0.1")')
    
    parser.add_argument('--backup-dir', 
                       help='Directory to store backups of original files before modification. '
                            'MANDATORY unless --dry-run is specified')
    
    parser.add_argument('--dry-run', 
                       action='store_true',
                       help='Preview changes without actually modifying files (backup not required)')
    
    parser.add_argument('--no-confirm', 
                       action='store_true',
                       help='Modify files without asking for confirmation (overrides --confirm)')
    
    parser.add_argument('--exclude-dirs', 
                       nargs='+',
                       default=[],
                       help='Additional directories to exclude (space-separated)')
    
    args = parser.parse_args()
    
    # Check if backup directory is provided when not in dry-run mode
    if not args.dry_run and not args.backup_dir:
        parser.error(f"{color_text('--backup-dir is required unless --dry-run is specified', 'red')}")
    
    # Combine default excluded directories with user-provided ones
    excluded_dirs = DEFAULT_EXCLUDED_DIRS.union(set(args.exclude_dirs))
    
    # Create the replacer instance
    replacer = URLReplacer(
        search_pattern=args.search,
        replace_url=args.replace_url,
        backup_dir=args.backup_dir,
        dry_run=args.dry_run,
        confirm=not args.no_confirm,
        excluded_dirs=excluded_dirs
    )
    
    # Run the replacement
    try:
        replacer.process_directory()
    except KeyboardInterrupt:
        print(f"\n{color_text('[!]', 'red')} Operation cancelled by user")
        exit(1)
    except Exception as e:
        print(f"{color_text('[!]', 'red')} Fatal error: {e}")
        exit(1)

if __name__ == '__main__':
    main()
