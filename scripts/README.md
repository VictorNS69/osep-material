# ip-replace.py
**URL/IP Search & Replace Tool** - Recursively searches and replaces URLs/IPs in source files with mandatory backup protection and colored diff preview.

## Overview
A safety-focused Python script that searches through common source code files and replaces URL patterns. Features per-file confirmation, mandatory backups (except dry-run), and colored output showing exactly what will change before modification.

## Key Features
- **Interactive Mode (Default)**: Shows changes and asks for confirmation per file
- **Dry-Run Mode**: Preview changes without any modifications (no backup required)
- **Automatic Mode**: Replace without confirmation (backup still required)
- **Mandatory Backups**: Timestamped backups created before any modification
- **Colored Diff Output**: Old lines in red (`-`), new lines in green (`+`)
- **Smart Exclusion**: Automatically excludes sensitive directories and the script itself

## Target File Types
```py
TARGET_EXTENSIONS = {'.ps1', '.hta', '.cs', '.sh', '.py', '.aspx', '.c', '.vba'}
```
### Excluded Directories
```py
DEFAULT_EXCLUDED_DIRS = {'backup', '.git', '.gitmodules', 'Tools', 'tunneling/ligolo'}
```
### Excluded Files
```py
DEFAULT_EXCLUDED_FILES = {'ip-replace.py', 'ip-replace.pyc', '__pycache__', 'simple-http-post-server.py', 'Invoke-ConPtyShell.ps1'}
```

## Usage Examples
> [!NOTE]
> Always run in the root directory.

**Basic Replacement (Interactive Mode)**

Replace a specific URL with confirmation prompt before each file:
```bash
scripts/ip-replace.py --search "http://192.168.235.130:8000" --replace-url "http://192.168.45.1:80" --backup-dir ./backups
```
**Dry-Run Mode (Preview Only)**

See what would change without modifying any files:
```bash
scripts/ip-replace.py --search "http://192.168.235.130" --replace-url "http://10.0.0.1" --dry-run
```
**Generic URL Replacement**

Replace any URL found with a new URL:
```bash
scripts/ip-replace.py --replace-url "http://192.168.45.1:443" --backup-dir ./backups
```
**Automatic Mode (No Confirmation)**

Replace in all files without asking (backup still required):
```bash
scripts/ip-replace.py --search "http://old-server.com" --replace-url "https://new-server.com" --backup-dir ./backups --no-confirm
```
> [!CAUTION]
> Always run with --dry-run first to prevent unwanted modifications.

**Custom Excluded Directories**

Add additional directories to exclude:
```bash
scripts/ip-replace.py --search "http://192.168.1.100" --replace-url "http://10.0.0.1" --backup-dir ./backups --exclude-dirs "test" "temp" ".venv"
```
# cRawToBin.py
CipherText Array to Binary Converter - Extracts hex bytes from C unsigned char arrays and saves them directly to binary files.

## Overview
A simple utility that parses C source files containing `unsigned char cipherText[]` arrays, extracts all hex bytes (format: `0x??`), and writes them as raw binary data to an output file. Perfect for extracting embedded payloads, shellcode, or encrypted data from C source files.

## Usage
```bash
python cRawToBin.py source.c out.bin
```
> [!NOTE]
> If you encounter encoding errors, convert the file first:
> ```bash
> iconv -f UTF-16 -t UTF-8 source.c > source_utf8.c
> ```
