#!/bin/bash

# Script to search and replace IP addresses in files
# Searches for: http://192.168.235.130:8000
# Replaces with: http://127.0.0.1:69

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SEARCH_STRING="http://192.168.235.130:8000"
REPLACE_STRING="http://127.0.0.1:69"
EXCLUDE_PATTERNS=("*.md" "*.exe" "*.bin")
BACKUP_EXTENSION=".bak"

echo -e "${BLUE}=== URL Search and Replace Tool ===${NC}"
echo "Searching for: $SEARCH_STRING"
echo "Replacing with: $REPLACE_STRING"
echo ""

# Function to check if a file should be excluded
should_exclude_file() {
    local file="$1"
    
    # Check excluded extensions
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ $(basename "$file") == $pattern ]]; then
            return 0  # True - should exclude
        fi
    done
    
    return 1  # False - should process
}

# Function to process a single file
process_file() {
    local file="$1"
    local mode="$2"  # "search", "replace", "interactive"
    
    if should_exclude_file "$file"; then
        return 1
    fi
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Count occurrences
    local count
    count=$(grep -c "$SEARCH_STRING" "$file" 2>/dev/null || echo 0)
    
    if [ "$count" -gt 0 ]; then
        case "$mode" in
            "search")
                echo -e "${GREEN}Found in:${NC} $file (${count} occurrences)"
                # Show first 3 occurrences with line numbers
                grep -n "$SEARCH_STRING" "$file" 2>/dev/null | head -3 | while IFS= read -r line; do
                    echo "  Line $line"
                done
                if [ "$count" -gt 3 ]; then
                    echo "  ... and $((count - 3)) more"
                fi
                echo ""
                ;;
            "replace")
                # Create backup
                cp "$file" "${file}${BACKUP_EXTENSION}"
                # Perform replacement
                if sed -i '' "s|$SEARCH_STRING|$REPLACE_STRING|g" "$file" 2>/dev/null; then
                    # Check if replacement was successful
                    local new_count
                    new_count=$(grep -c "$SEARCH_STRING" "$file" 2>/dev/null || echo 0)
                    echo -e "${GREEN}✓${NC} Replaced in $file (${count} → ${new_count} remaining)"
                else
                    echo -e "${RED}✗${NC} Failed to process $file"
                fi
                ;;
            "interactive")
                echo -e "${YELLOW}Found in:${NC} $file (${count} occurrences)"
                # Show preview
                echo "Preview of first occurrence:"
                grep -n "$SEARCH_STRING" "$file" 2>/dev/null | head -1 | while IFS= read -r line; do
                    echo "  Line: $line"
                done
                echo ""
                read -p "Replace in this file? (y/n): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    cp "$file" "${file}${BACKUP_EXTENSION}"
                    if sed -i '' "s|$SEARCH_STRING|$REPLACE_STRING|g" "$file" 2>/dev/null; then
                        echo -e "${GREEN}✓ Replaced${NC}"
                    else
                        echo -e "${RED}✗ Failed${NC}"
                    fi
                else
                    echo "Skipped"
                fi
                echo ""
                ;;
        esac
        return 0
    fi
    
    return 1
}

# Function to find all files recursively
find_all_files() {
    # Use find to get all files (excluding hidden directories)
    find . -type f ! -path "*/\.*" ! -name ".*" | while IFS= read -r file; do
        echo "$file"
    done
}

# Mode 1: Search only mode
if [[ "$1" == "--search-only" ]] || [[ "$1" == "-s" ]]; then
    echo -e "${YELLOW}SEARCH ONLY MODE (no replacement)${NC}"
    echo ""
    
    total_occurrences=0
    files_found=0
    
    while IFS= read -r file; do
        if process_file "$file" "search"; then
            files_found=$((files_found + 1))
            occurrences_in_file=$(grep -c "$SEARCH_STRING" "$file" 2>/dev/null || echo 0)
            total_occurrences=$((total_occurrences + occurrences_in_file))
        fi
    done < <(find_all_files)
    
    echo "="*50
    echo -e "${BLUE}SUMMARY:${NC}"
    echo "Files searched: $(find_all_files | wc -l)"
    echo "Files containing pattern: $files_found"
    echo "Total occurrences found: $total_occurrences"
    echo ""

# Mode 2: Interactive mode
elif [[ "$1" == "--interactive" ]] || [[ "$1" == "-i" ]]; then
    echo -e "${YELLOW}INTERACTIVE MODE${NC}"
    echo ""
    
    # First, find all files with occurrences
    files_with_matches=()
    while IFS= read -r file; do
        if ! should_exclude_file "$file" && grep -q "$SEARCH_STRING" "$file" 2>/dev/null; then
            files_with_matches+=("$file")
        fi
    done < <(find_all_files)
    
    if [ ${#files_with_matches[@]} -eq 0 ]; then
        echo "No files found containing the search string."
        exit 0
    fi
    
    echo "Found ${#files_with_matches[@]} file(s) containing '$SEARCH_STRING':"
    echo ""
    
    for file in "${files_with_matches[@]}"; do
        process_file "$file" "interactive"
    done

# Mode 3: Direct replace mode
elif [[ "$1" == "--direct" ]] || [[ "$1" == "-d" ]]; then
    echo -e "${YELLOW}DIRECT REPLACE MODE${NC}"
    echo -e "${RED}Warning: This will replace ALL occurrences without confirmation!${NC}"
    echo ""
    
    read -p "Are you sure you want to proceed? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Starting replacement process..."
        echo ""
        
        files_processed=0
        total_replacements=0
        
        while IFS= read -r file; do
            if ! should_exclude_file "$file"; then
                count_before=$(grep -c "$SEARCH_STRING" "$file" 2>/dev/null || echo 0)
                if [ "$count_before" -gt 0 ]; then
                    # Create backup and replace
                    cp "$file" "${file}${BACKUP_EXTENSION}"
                    if sed -i '' "s|$SEARCH_STRING|$REPLACE_STRING|g" "$file" 2>/dev/null; then
                        count_after=$(grep -c "$SEARCH_STRING" "$file" 2>/dev/null || echo 0)
                        replacements_made=$((count_before - count_after))
                        echo -e "${GREEN}✓${NC} $file: ${replacements_made} replacements"
                        files_processed=$((files_processed + 1))
                        total_replacements=$((total_replacements + replacements_made))
                    else
                        echo -e "${RED}✗${NC} $file: Failed to process"
                    fi
                fi
            fi
        done < <(find_all_files)
        
        echo ""
        echo "="*50
        echo -e "${BLUE}REPLACEMENT COMPLETE${NC}"
        echo "Files processed: $files_processed"
        echo "Total replacements made: $total_replacements"
        echo "Backup files created with extension: $BACKUP_EXTENSION"
        echo ""
        
    else
        echo "Operation cancelled."
    fi

# Help mode or no mode specified
else
    echo -e "${BLUE}=== URL Search and Replace Tool ===${NC}"
    echo ""
    echo "Usage: $0 [MODE]"
    echo ""
    echo "Modes:"
    echo "  -s, --search-only    Search for files containing the string (no replacement)"
    echo "  -i, --interactive    Interactive mode (ask before each replacement)"
    echo "  -d, --direct         Direct replace mode (replace all without asking)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --search-only     # Just search, don't replace"
    echo "  $0 -i                # Interactive replacement"
    echo "  $0 --direct          # Replace all occurrences"
    echo ""
    echo "Configuration:"
    echo "  Search string:  $SEARCH_STRING"
    echo "  Replace string: $REPLACE_STRING"
    echo "  Excluded:       ${EXCLUDE_PATTERNS[*]}"
    echo ""
    
    # Quick search without parameters
    echo -e "${YELLOW}Quick search (will show first 5 matches):${NC}"
    echo ""
    
    count=0
    while IFS= read -r file && [ $count -lt 5 ]; do
        if ! should_exclude_file "$file"; then
            if grep -q "$SEARCH_STRING" "$file" 2>/dev/null; then
                occurrences=$(grep -c "$SEARCH_STRING" "$file" 2>/dev/null || echo 0)
                echo -e "${GREEN}Found:${NC} $file ($occurrences occurrences)"
                count=$((count + 1))
            fi
        fi
    done < <(find_all_files)
    
    if [ $count -eq 0 ]; then
        echo "No files found containing the search string."
    elif [ $count -ge 5 ]; then
        echo "... and possibly more (use --search-only to see all)"
    fi
fi
