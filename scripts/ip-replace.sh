#!/bin/bash

# Script to search and replace URLs in files
# Allows custom search and replace URLs as arguments

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_SEARCH_URL="http://192.168.235.130:8000"
DEFAULT_REPLACE_URL="http://127.0.0.1:69"
EXCLUDE_PATTERNS=("*.md" "*.exe" "*.bin")
BACKUP_DIR=""
SEARCH_URL=""
REPLACE_URL=""
MODE="search"  # Default mode

# Function to print usage
print_usage() {
    echo -e "${BLUE}=== URL Search and Replace Tool ===${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] --backup-dir DIR"
    echo ""
    echo "Required:"
    echo "  -b, --backup-dir DIR   Backup directory (required)"
    echo ""
    echo "URL Options:"
    echo "  -s, --search URL       URL to search for (default: $DEFAULT_SEARCH_URL)"
    echo "  -r, --replace URL      URL to replace with (default: $DEFAULT_REPLACE_URL)"
    echo ""
    echo "Mode Options:"
    echo "  -m, --mode MODE        Operation mode: search, interactive, direct (default: search)"
    echo "      --search-only      Alias for --mode search"
    echo "      --interactive      Alias for --mode interactive"
    echo "      --direct           Alias for --mode direct"
    echo ""
    echo "Other Options:"
    echo "  -e, --exclude PAT      Add file pattern to exclude (can be used multiple times)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -b ./backups --search http://old.com --replace http://new.com"
    echo "  $0 --backup-dir /tmp/backups --mode direct"
    echo "  $0 -b ./backups --search-only --search http://192.168.1.100:8080 --replace http://localhost:80"
    echo "  $0 -b ./backups --interactive -e '*.log' -e '*.tmp'"
    echo ""
}

# Parse command line arguments
parse_arguments() {
    if [ $# -eq 0 ]; then
        print_usage
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -s|--search)
                SEARCH_URL="$2"
                shift 2
                ;;
            -r|--replace)
                REPLACE_URL="$2"
                shift 2
                ;;
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            --search-only)
                MODE="search"
                shift
                ;;
            --interactive)
                MODE="interactive"
                shift
                ;;
            --direct)
                MODE="direct"
                shift
                ;;
            -e|--exclude)
                EXCLUDE_PATTERNS+=("$2")
                shift 2
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}"
                print_usage
                exit 1
                ;;
        esac
    done

    # Validate backup directory
    if [ -z "$BACKUP_DIR" ]; then
        echo -e "${RED}Error: Backup directory is required${NC}"
        print_usage
        exit 1
    fi

    # Set default URLs if not provided
    if [ -z "$SEARCH_URL" ]; then
        SEARCH_URL="$DEFAULT_SEARCH_URL"
    fi
    if [ -z "$REPLACE_URL" ]; then
        REPLACE_URL="$DEFAULT_REPLACE_URL"
    fi

    # Validate mode
    case "$MODE" in
        search|interactive|direct)
            # Valid mode
            ;;
        *)
            echo -e "${RED}Error: Invalid mode: $MODE${NC}"
            echo "Valid modes: search, interactive, direct"
            exit 1
            ;;
    esac
}

# Function to check if a file should be excluded
should_exclude_file() {
    local file="$1"
    local filename
    
    filename=$(basename "$file")
    
    # EXCLUDE THIS SCRIPT AND ip-replace.sh
    # This prevents the script from modifying itself
    if [[ "$filename" == $0 ]] || [[ "$filename" == "$(basename "$0")" ]]; then
        return 0  # True - should exclude
    fi
    
    # Check excluded patterns
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$filename" == $pattern ]]; then
            return 0  # True - should exclude
        fi
    done
    
    return 1  # False - should process
}

# Function to create backup directory
setup_backup_dir() {
    local backup_dir="$1"
    
    if [ ! -d "$backup_dir" ]; then
        echo -e "${YELLOW}Creating backup directory: $backup_dir${NC}"
        mkdir -p "$backup_dir"
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to create backup directory${NC}"
            exit 1
        fi
    fi
    
    # Make sure it's writable
    if [ ! -w "$backup_dir" ]; then
        echo -e "${RED}Error: Backup directory is not writable${NC}"
        exit 1
    fi
}

# Function to create backup of a file
create_backup() {
    local source_file="$1"
    local backup_dir="$2"
    local timestamp
    
    # Get absolute path for consistency
    source_file=$(realpath "$source_file" 2>/dev/null || echo "$source_file")
    
    # Create relative path for backup
    local relative_path="${source_file#$(pwd)/}"
    if [ "$relative_path" = "$source_file" ]; then
        # File is not under current directory
        relative_path=$(basename "$source_file")
    fi
    
    # Replace slashes with underscores for safe filename
    local safe_name=$(echo "$relative_path" | sed 's|/|_|g' | sed 's|\.\.|__|g')
    
    # Add timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${backup_dir}/${safe_name}_${timestamp}.bak"
    
    # Create parent directory in backup location if needed
    mkdir -p "$(dirname "$backup_file")" 2>/dev/null
    
    # Copy file to backup location
    cp "$source_file" "$backup_file" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Backup: $backup_file"
        return 0
    else
        echo -e "${RED}✗${NC} Failed to backup: $source_file"
        return 1
    fi
}

# Function to find all files recursively
find_all_files() {
    # Use find to get all files (excluding hidden directories)
    # Search in parent directory (../)
    find ../ -type f ! -path "*/\.*" ! -name ".*" | while IFS= read -r file; do
        echo "$file"
    done
}

# Function to process a single file
process_file() {
    local file="$1"
    local mode="$2"
    local backup_dir="$3"
    
    if should_exclude_file "$file"; then
        return 1
    fi
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Count occurrences
    local count
    count=$(grep -c "$SEARCH_URL" "$file" 2>/dev/null | awk '{print $1}' || echo 0)
    if [ "$count" -gt 0 ]; then
        case "$mode" in
            "search")
                echo -e "${CYAN}Found in:${NC} $file (${count} occurrences)"
                # Show first 2 occurrences with line numbers
                grep -n "$SEARCH_URL" "$file" 2>/dev/null | head -2 | while IFS= read -r line; do
                    echo "  Line $line"
                done
                if [ "$count" -gt 2 ]; then
                    echo "  ... and $((count - 2)) more"
                fi
                echo ""
                ;;
            "replace")
                # Create backup before modification
                if create_backup "$file" "$backup_dir"; then
                    # Perform replacement
                    if sed -i '' "s|$SEARCH_URL|$REPLACE_URL|g" "$file" 2>/dev/null; then
                        # Check if replacement was successful
                        local new_count
                        new_count=$(grep -c "$SEARCH_URL" "$file" 2>/dev/null || echo 0)
                        local replacements_made=$((count - new_count))
                        echo -e "${GREEN}✓${NC} Replaced in $file (${replacements_made} replacements)"
                        return 0
                    else
                        echo -e "${RED}✗${NC} Failed to process $file"
                        return 1
                    fi
                else
                    return 1
                fi
                ;;
            "interactive")
                echo -e "${PURPLE}File:${NC} $file"
                echo -e "  ${YELLOW}Occurrences:${NC} $count"
                echo ""
                echo "First occurrence preview:"
                grep -n "$SEARCH_URL" "$file" 2>/dev/null | head -1 | while IFS= read -r line; do
                    echo "  Line: $line"
                done
                echo ""
                
                # Show context
                echo "Context (before → after):"
                grep -B1 -A1 "$SEARCH_URL" "$file" 2>/dev/null | head -5 | while IFS= read -r context_line; do
                    if [[ "$context_line" == *"$SEARCH_URL"* ]]; then
                        echo -e "  ${RED}-${NC} $context_line"
                        echo -e "  ${GREEN}+${NC} ${context_line//$SEARCH_URL/$REPLACE_URL}"
                    else
                        echo "    $context_line"
                    fi
                done
                echo ""
                
                read -p "Replace in this file? (y/n/s=skip all/q=quit): " -n 1 -r
                echo ""
                case $REPLY in
                    [Yy]*)
                        if create_backup "$file" "$backup_dir"; then
                            if sed -i '' "s|$SEARCH_URL|$REPLACE_URL|g" "$file" 2>/dev/null; then
                                echo -e "${GREEN}✓ Replaced successfully${NC}"
                            else
                                echo -e "${RED}✗ Replacement failed${NC}"
                            fi
                        fi
                        ;;
                    [Nn]*)
                        echo "Skipped"
                        ;;
                    [Ss]*)
                        echo -e "${YELLOW}Skipping all remaining files${NC}"
                        return 2  # Special code to stop processing
                        ;;
                    [Qq]*)
                        echo -e "${YELLOW}Quitting...${NC}"
                        exit 0
                        ;;
                    *)
                        echo "Invalid choice, skipping"
                        ;;
                esac
                echo ""
                ;;
        esac
        return 0
    fi
    
    return 1
}

# Function to print summary
print_summary() {
    local start_time="$1"
    local files_processed="$2"
    local files_found="$3"
    local total_replacements="$4"
    local backup_dir="$5"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "="*60
    echo -e "${BLUE}OPERATION SUMMARY${NC}"
    echo "="*60
    echo -e "Search URL:    ${CYAN}$SEARCH_URL${NC}"
    echo -e "Replace URL:   ${GREEN}$REPLACE_URL${NC}"
    echo -e "Mode:          $MODE"
    echo -e "Backup dir:    $backup_dir"
    echo "="*60
    echo -e "Files searched:      $(find_all_files | wc -l)"
    echo -e "Files with matches:  $files_found"
    echo -e "Files processed:     $files_processed"
    echo -e "Total replacements:  $total_replacements"
    echo -e "Backups created:     $(find "$backup_dir" -name "*.bak" 2>/dev/null | wc -l)"
    echo -e "Time elapsed:        ${duration}s"
    echo "="*60
    
    if [ "$MODE" = "search" ]; then
        echo -e "${YELLOW}Note: Run with --mode direct or --mode interactive to make changes${NC}"
    fi
}

# Main execution function
main() {
    parse_arguments "$@"
    
    # Setup backup directory
    setup_backup_dir "$BACKUP_DIR"
    
    # Display configuration
    echo -e "${BLUE}=== URL Search and Replace Tool ===${NC}"
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    echo -e "  Search URL:    ${CYAN}$SEARCH_URL${NC}"
    echo -e "  Replace URL:   ${GREEN}$REPLACE_URL${NC}"
    echo -e "  Mode:          $MODE"
    echo -e "  Backup dir:    $BACKUP_DIR"
    echo -e "  Excluded:      ${EXCLUDE_PATTERNS[*]}"
    echo ""
    
    start_time=$(date +%s)
    files_processed=0
    files_found=0
    total_replacements=0
    
    case "$MODE" in
        "search")
            echo -e "${YELLOW}SEARCH MODE (read-only)${NC}"
            echo ""
            
            while IFS= read -r file; do
                if process_file "$file" "search" "$BACKUP_DIR"; then
                    files_found=$((files_found + 1))
                    occurrences=$(grep -c "$SEARCH_URL" "$file" 2>/dev/null || echo 0)
                    total_replacements=$((total_replacements + occurrences))
                fi
            done < <(find_all_files)
            
            files_processed=$files_found
            ;;
            
        "interactive")
            echo -e "${YELLOW}INTERACTIVE MODE${NC}"
            echo -e "${CYAN}You will be prompted for each file${NC}"
            echo ""
            
            skip_all=false
            while IFS= read -r file && [ "$skip_all" = false ]; do
                if ! should_exclude_file "$file" && grep -q "$SEARCH_URL" "$file" 2>/dev/null; then
                    files_found=$((files_found + 1))
                    process_file "$file" "interactive" "$BACKUP_DIR"
                    result=$?
                    if [ $result -eq 0 ]; then
                        files_processed=$((files_processed + 1))
                        # Count replacements made
                        count_before=$(grep -c "$SEARCH_URL" "${BACKUP_DIR}/$(basename "$file")"* 2>/dev/null | head -1 || echo 0)
                        count_after=$(grep -c "$SEARCH_URL" "$file" 2>/dev/null || echo 0)
                        replacements=$((count_before - count_after))
                        total_replacements=$((total_replacements + replacements))
                    elif [ $result -eq 2 ]; then
                        skip_all=true
                        echo -e "${YELLOW}Skipping all remaining files${NC}"
                    fi
                fi
            done < <(find_all_files)
            ;;
            
        "direct")
            echo -e "${YELLOW}DIRECT REPLACE MODE${NC}"
            echo -e "${RED}Warning: This will replace ALL occurrences without confirmation!${NC}"
            echo ""
            
            read -p "Are you sure you want to proceed? (y/n): " -n 1 -r
            echo ""
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Starting replacement process..."
                echo ""
                
                while IFS= read -r file; do
                    if ! should_exclude_file "$file"; then
                        count_before=$(grep -c "$SEARCH_URL" "$file" 2>/dev/null || echo 0)
                        if [ "$count_before" -gt 0 ]; then
                            files_found=$((files_found + 1))
                            if process_file "$file" "replace" "$BACKUP_DIR"; then
                                files_processed=$((files_processed + 1))
                                count_after=$(grep -c "$SEARCH_URL" "$file" 2>/dev/null || echo 0)
                                replacements_made=$((count_before - count_after))
                                total_replacements=$((total_replacements + replacements_made))
                            fi
                        fi
                    fi
                done < <(find_all_files)
            else
                echo "Operation cancelled."
                exit 0
            fi
            ;;
    esac
    
    print_summary "$start_time" "$files_processed" "$files_found" "$total_replacements" "$BACKUP_DIR"
}

# Run main function with all arguments
main "$@"
