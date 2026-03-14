import os
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.backends import default_backend
import argparse

def encrypt_file(input_file, output_file=None):
    """
    Encrypt a binary file using AES-CBC with PKCS7 padding
    """
    # Generate random key and IV
    key = os.urandom(32)  # AES-256
    iv = os.urandom(16)   # AES block size
    
    # Read input file
    with open(input_file, 'rb') as f:
        plaintext = f.read()
    
    # Create AES cipher
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    encryptor = cipher.encryptor()
    
    # Apply PKCS7 padding
    padder = padding.PKCS7(128).padder()
    padded_data = padder.update(plaintext) + padder.finalize()
    
    # Encrypt
    ciphertext = encryptor.update(padded_data) + encryptor.finalize()
        
    # Write encrypted file
    with open(output_file, 'wb') as f:
        f.write(ciphertext)
    
    return key, iv, ciphertext

def bytes_to_c_array(data, name="data"):
    """
    Convert bytes to C-style array format
    """
    hex_bytes = [f"0x{b:02X}" for b in data]
    lines = []
    
    # Format in lines of 16 bytes (like typical array initialization)
    for i in range(0, len(hex_bytes), 16):
        line = hex_bytes[i:i+16]
        lines.append(", ".join(line))
    
    result = f"uint8_t {name}[{len(data)}] = {{\n"
    result += ",\n".join([f"        {line}" for line in lines])
    result += "\n    };"
    return result

def main():
    parser = argparse.ArgumentParser(description='Encrypt binary file with AES-CBC')
    parser.add_argument('input_file', help='Input binary file (.bin)')
    parser.add_argument('-o', '--output', help='Output encrypted file (default: input.enc)')
    
    args = parser.parse_args()
    
    # Determine output filename
    if args.output is None:
        args.output = args.input_file + '.enc'
    
    # Encrypt the file
    key, iv, ciphertext = encrypt_file(args.input_file, args.output)
    
    # Print key and IV in requested format
    print("AES Key (256-bit):")
    print(bytes_to_c_array(key, "AesKey"))
    print("\n" + "="*60 + "\n")
    
    print("AES IV (128-bit):")
    print(bytes_to_c_array(iv, "AesIV"))
    print("\n" + "="*60 + "\n")
    
    '''
    # Also print as Python bytes for easy copying
    print("Python bytes format (for reference):")
    print(f"key = {key}")
    print(f"iv = {iv}")
    print("\n" + "="*60 + "\n")
    '''
    # Print encryption info
    print(f"Input file: {args.input_file} ({len(open(args.input_file, 'rb').read())} bytes)")
    print(f"Output file: {args.output} ({len(ciphertext)} bytes)")
    print("Encryption: AES-256-CBC with PKCS7 padding")

if __name__ == "__main__":
    main()
