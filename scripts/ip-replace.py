#!/usr/bin/env python3
"""
URL Search and Replace Tool
Supports three modes: search (default), interactive, and direct
"""

import argparse
import os
import re
import shutil
import sys
import fnmatch
from pathlib import Path

# Default exclude patterns (excluding the script itself and related files)
EXCLUDE_PATTERNS = ["ip-replace.sh", "*.md", "*.exe", "*.bak", "*.bin"]

def should_exclude_file(file_path, script_name):
    """
    Check if a file should be excluded from processing
    
    Args:
        file_path: Path to the file to check
        script_name: Name of the current script
    
    Returns:
        bool: True if file should be excluded, False otherwise
    """
    filename = os.path.basename(file_path)
    
    # Exclude this script and ip-replace.sh
    if filename in ["ip-replace.sh", script_name]:
        return True
    
    # Check excluded patterns
    for pattern in EXCLUDE_PATTERNS:
        if fnmatch.fnmatch(filename, pattern):
            return True
    
    return False

def backup_file(file_path):
    """Create a backup of the file"""
    backup_path = file_path + ".bak"
    print(f"Creating backup: {backup_path}")
    shutil.copy2(file_path, backup_path)
    return backup_path

def search_in_file(file_path, search_pattern):
    """
    Search for pattern in file and return matches
    
    Returns:
        list: List of tuples (line_number, line_content)
    """
    matches = []
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line_num, line in enumerate(f, 1):
                if re.search(search_pattern, line):
                    matches.append((line_num, line.rstrip()))
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
    return matches

def replace_in_file(file_path, search_pattern, replace_url, dry_run=False):
    """
    Replace search pattern with replace_url in file
    
    Returns:
        tuple: (success, replacements_count, errors)
    """
    replacements = 0
    errors = []
    
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # Perform the replacement
        new_content, count = re.subn(search_pattern, replace_url, content)
        
        if count > 0:
            if not dry_run:
                # Write back to file
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"  Replaced {count} occurrence(s)")
            else:
                print(f"  Would replace {count} occurrence(s)")
            replacements = count
        else:
            print(f"  No matches found")
            
        return True, replacements, errors
        
    except Exception as e:
        error_msg = f"Error processing {file_path}: {e}"
        errors.append(error_msg)
        return False, replacements, errors

def process_file_interactive(file_path, search_pattern, replace_url):
    """
    Interactive mode: show each match and ask for confirmation
    """
    print(f"\nProcessing: {file_path}")
    
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
        
        modified = False
        new_lines = []
        
        for line_num, line in enumerate(lines, 1):
            if re.search(search_pattern, line):
                print(f"\nLine {line_num}: {line.rstrip()}")
                response = input(f"Replace with '{replace_url}'? (y/n/a/q): ").lower().strip()
                
                if response == 'q':
                    print("Quitting interactive mode")
                    return False, 0
                elif response == 'a':
                    # Replace all remaining in this file
                    new_line = re.sub(search_pattern, replace_url, line)
                    new_lines.append(new_line)
                    modified = True
                    print(f"  Auto-replacing this and remaining matches")
                elif response == 'y':
                    new_line = re.sub(search_pattern, replace_url, line)
                    new_lines.append(new_line)
                    modified = True
                    print(f"  Replaced")
                else:
                    new_lines.append(line)
            else:
                new_lines.append(line)
        
        if modified:
            # Create backup
            backup_file(file_path)
            
            # Write modified content
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            print(f"  File updated")
            return True, 1
        else:
            print(f"  No changes made")
            return True, 0
            
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False, 0

def find_files(directory, extensions=None):
    """
    Find all files in directory with given extensions
    
    Args:
        directory: Directory to search
        extensions: List of file extensions to include (None for all)
    
    Returns:
        list: List of file paths
    """
    files = []
    for root, _, filenames in os.walk(directory):
        for filename in filenames:
            if extensions:
                ext = os.path.splitext(filename)[1].lower()
                if ext in extensions:
                    files.append(os.path.join(root, filename))
            else:
                files.append(os.path.join(root, filename))
    return files

def main():
    parser = argparse.ArgumentParser(
        description='Search and replace URLs in files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --search-url "http://old.com" --replace-url "https://new.com"
  %(prog)s --mode interactive --search-url "http://old.com" --replace-url "https://new.com"
  %(prog)s --mode direct --search-url "http://old.com" --replace-url "https://new.com" --backup
        """
    )
    
    parser.add_argument('--mode', choices=['search', 'interactive', 'direct'], 
                       default='search',
                       help='Operation mode: search (default), interactive, or direct replace')
    
    parser.add_argument('--search-url', required=True,
                       help='URL pattern to search for (supports regex)')
    
    parser.add_argument('--replace-url', required=True,
                       help='URL to replace with')
    
    parser.add_argument('--backup', action='store_true',
                       help='Create backup files before replacing (required for direct mode)')
    
    parser.add_argument('--directory', default='.',
                       help='Directory to process (default: current directory)')
    
    parser.add_argument('--extensions', nargs='+',
                       help='File extensions to process (e.g., .html .js .css)')
    
    parser.add_argument('--exclude', nargs='+', default=[],
                       help='Additional filename patterns to exclude')
    
    parser.add_argument('--dry-run', action='store_true',
                       help='Show what would be changed without making changes')
    
    args = parser.parse_args()
    
    # Get current script name
    script_name = os.path.basename(__file__)
    
    # Validate arguments based on mode
    if args.mode == 'direct' and not args.backup:
        parser.error("--backup is required for direct mode")
    
    # Add user exclude patterns
    global EXCLUDE_PATTERNS
    EXCLUDE_PATTERNS.extend(args.exclude)
    
    # Check if directory exists
    if not os.path.isdir(args.directory):
        print(f"Error: Directory '{args.directory}' does not exist")
        sys.exit(1)
    
    print(f"Mode: {args.mode}")
    print(f"Search URL: {args.search_url}")
    print(f"Replace URL: {args.replace_url}")
    print(f"Directory: {os.path.abspath(args.directory)}")
    if args.extensions:
        print(f"Extensions: {', '.join(args.extensions)}")
    print(f"Excluding: {', '.join(EXCLUDE_PATTERNS)}")
    if args.dry_run:
        print("DRY RUN - No changes will be made")
    print("-" * 50)
    
    # Find files to process
    files = find_files(os.path.abspath(args.directory), args.extensions)
    
    if not files:
        print("No files found to process")
        return
    
    print(f"Found {len(files)} files to scan")
    
    # Compile regex pattern for efficiency
    try:
        search_pattern = re.compile(args.search_url)
    except re.error as e:
        print(f"Error in search pattern: {e}")
        sys.exit(1)
    
    total_replacements = 0
    total_errors = 0
    
    for file_path in files:
        # Check if file should be excluded
        if should_exclude_file(file_path, script_name):
            continue
        
        if args.mode == 'search':
            # Search mode: just find and display matches
            matches = search_in_file(file_path, search_pattern)
            if matches:
                print(f"\n{file_path}:")
                for line_num, line in matches:
                    print(f"  Line {line_num}: {line}")
        
        elif args.mode == 'interactive':
            # Interactive mode
            success, replacements = process_file_interactive(file_path, search_pattern, args.replace_url)
            if not success:
                break  # User quit
            total_replacements += replacements
        
        elif args.mode == 'direct':
            # Direct mode
            print(f"\nProcessing: {file_path}")
            
            # Create backup if requested
            if args.backup:
                backup_file(file_path)
            
            # Perform replacement
            success, replacements, errors = replace_in_file(
                file_path, search_pattern, args.replace_url, args.dry_run
            )
            
            if errors:
                print(f"  Errors: {', '.join(errors)}")
                total_errors += 1
            
            total_replacements += replacements
    
    print("\n" + "=" * 50)
    print(f"Summary:")
    print(f"  Mode: {args.mode}")
    print(f"  Total replacements: {total_replacements}")
    if total_errors > 0:
        print(f"  Errors: {total_errors}")
    if args.dry_run:
        print("  DRY RUN COMPLETED - No changes were made")
    print("=" * 50)

if __name__ == "__main__":
    main()
