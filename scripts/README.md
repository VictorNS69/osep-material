# ip-replace.py
Search & Replace URLs/IPs: Finds and replaces text patterns (supports regex) in files

**Three Operation Modes**:
- `search` (default): Only searches and displays matches without making changes
- `interactive`: Shows each match and asks for confirmation before replacing
- `direct`: Automatically replaces all matches (requires backup)

**Safety Features**:
- Mandatory backup directory for interactive/direct modes
- Dry-run (`--dry-run`) option to preview changes
- Automatic exclusion of backup files and critical directories
- File backups before any modifications

**Smart Filtering**:
- Excludes common file types (`*.md`, `*.exe`, `*.bak`, `*.bin`)
- Excludes common directories (`.git`, `node_modules`, `venv`, etc.)
- Custom extension filtering
- Interactive mode with per-match confirmation

## Usage
>[!NOTE]
> Always run in the root directory.

**Basic Search (Safe - No Changes)**
```bash
# Find all occurrences of old IP addresses
scripts/ip-replace.py --search-url "192\.168\.1\.[0-9]+" --replace-url "10.0.0.1"

# Search for HTTP URLs to replace with HTTPS
scripts/ip-replace.py --search-url "http://example\.com" --replace-url "https://example.com"
```
**Interactive Mode (Safe - Confirm Each Change)**
```bash
# Interactive replacement with backup
scripts/ip-replace.py --mode interactive --search-url "http://old-server\.com" --replace-url "https://new-server.com" --backup-dir ./backups

# Interactive with file type filtering
scripts/ip-replace.py --mode interactive --search-url "localhost:8080" --replace-url "production.example.com" --extensions .js .html .css --backup-dir ./backups
```
**Direct Mode (Automatic - Use with Caution)**
```bash
# Direct replacement with backup (required)
scripts/ip-replace.py --mode direct --search-url "dev\.internal\.net" --replace-url "api.company.com" --backup-dir ./backups

# Direct mode with dry-run (preview only)
scripts/ip-replace.py --mode direct --search-url "test-environment" --replace-url "production" --backup-dir ./backups --dry-run
```
**Advanced Options**
```bash
# Process specific directory
scripts/ip-replace.py --search-url "temp-ip" --replace-url "permanent-host" --directory /path/to/project

# Exclude additional patterns
scripts/ip-replace.py --search-url "old-domain\.com" --replace-url "new-domain.com" --exclude "*.tmp" "*.log" "cache"

# Process only specific file types
scripts/ip-replace.py --search-url "192\.168\.[0-9]+\.[0-9]+" --replace-url "10.0.0.0" --extensions .py .json .yaml .yml
```
**Complex Pattern Matching (Regex)**
```bash
# Match multiple URL patterns
scripts/ip-replace.py --search-url "(http://|https://)?old-site\.(com|net)" --replace-url "https://new-site.com"

# Replace IP ranges
scripts/ip-replace.py --search-url "10\.0\.0\.[0-9]{1,3}"  --replace-url "192.168.0.0"
```
