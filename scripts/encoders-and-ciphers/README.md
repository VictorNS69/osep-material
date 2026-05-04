# aesCipher.py
AES-CBC Binary Encryptor with C Array Output - Encrypts binary files using AES-256-CBC and generates C array definitions for keys and IVs.
## Overview
A cryptographic tool that encrypts binary files using AES-256 in CBC mode with PKCS7 padding. The script automatically generates random keys and IVs, then outputs them in ready-to-use C array format (uint8_t arrays) for easy integration into C/C++ projects, embedded systems, or payload development.

## Usage
> [!NOTE]
> The script generates NEW random keys and IVs with every execution. **Save the output for decryption!**

```bash
python3 aesCipher.py shellcode.bin -o shellcode.enc
```

# xorCipher.py
Binary File XOR Encryption Tool - Encrypts or decrypts binary files using XOR cipher with flexible key formats (string, hex, or integer).

## Overview
A versatile XOR encryption utility that works with binary files. Since XOR encryption is symmetric (same operation for encryption and decryption), this single tool handles both. Supports multiple key formats including plain text, hexadecimal strings, and decimal integers, with automatic key repeat for variable-length data.

## Usage
```bash
# Using "mysecretkey" as the key
python xor_encrypt.py shellcode.bin encrypted.enc mysecretkey
```
