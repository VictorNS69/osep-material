#!/usr/bin/env python3
"""
Binary file XOR encryption
Usage: python xor_encrypt.py <input_file> <output_file> <key>
"""

import sys
import argparse
from pathlib import Path

def xor_encrypt_file(input_file: str, output_file: str, key: str):
    """
    Perform XOR encryption on a binary file
    
    Args:
        input_file: Path to input file
        output_file: Path to output file
        key: XOR key (string, hex, or integer)
    """
    try:
        # Convert key to bytes
        key_bytes = convert_key_to_bytes(key)
        
        print(f"Input file: {input_file}")
        print(f"Output file: {output_file}")
        print(f"Key: {key} (as bytes: {key_bytes})")
        
        # Read input file
        with open(input_file, 'rb') as f:
            data = f.read()
        
        print(f"File size: {len(data):,} bytes")
        
        # Perform XOR operation
        encrypted_data = bytearray()
        key_len = len(key_bytes)
        
        for i, byte in enumerate(data):
            encrypted_data.append(byte ^ key_bytes[i % key_len])
        
        # Write output file
        with open(output_file, 'wb') as f:
            f.write(encrypted_data)
        
        print(f"Success! Encrypted/decrypted {len(data):,} bytes")
        
    except FileNotFoundError:
        print(f"Error: Input file '{input_file}' not found")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {str(e)}")
        sys.exit(1)

def convert_key_to_bytes(key: str) -> bytes:
    """Convert various key formats to bytes"""
    key = key.strip()
    
    # Try hex format (0x... or just hex digits)
    if key.startswith('0x'):
        key = key[2:]
    
    # Check if it's a hex string
    if all(c in '0123456789abcdefABCDEF' for c in key) and len(key) % 2 == 0:
        try:
            return bytes.fromhex(key)
        except:
            pass
    
    # Check if it's a decimal integer
    try:
        key_int = int(key)
        # Convert to single byte if small, or multi-byte representation
        if key_int < 256:
            return bytes([key_int])
        else:
            # Convert to bytes (big-endian)
            return key_int.to_bytes((key_int.bit_length() + 7) // 8, 'big')
    except ValueError:
        pass
    
    # Treat as plain text string
    return key.encode('utf-8')

def main():
    parser = argparse.ArgumentParser(
        description='XOR encrypt/decrypt binary files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python xor_encrypt.py secret.bin encrypted.bin mysecretkey
  python xor_encrypt.py secret.bin encrypted.bin 0x41
  python xor_encrypt.py secret.bin encrypted.bin 65
  python xor_encrypt.py secret.bin encrypted.bin 414243
        """
    )
    
    parser.add_argument('input_file', help='Input binary file')
    parser.add_argument('output_file', help='Output binary file')
    parser.add_argument('key', help='XOR key (string, hex, or integer)')
    
    # Parse command line arguments
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)
    
    args = parser.parse_args()
    
    # Check if input file exists
    if not Path(args.input_file).exists():
        print(f"Error: Input file '{args.input_file}' does not exist")
        sys.exit(1)
    
    # Perform XOR encryption
    xor_encrypt_file(args.input_file, args.output_file, args.key)

if __name__ == '__main__':
    main()
