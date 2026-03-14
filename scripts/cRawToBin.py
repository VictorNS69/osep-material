#!/usr/bin/env python3
"""
Simple CipherText Array to Binary Converter
Extrae bytes de unsigned char cipherText[] y los guarda en un archivo .bin
Uso: python3 script.py archivo.c salida.bin
"""

import sys
import re

def main():
    # Verificar argumentos
    if len(sys.argv) != 3:
        print("Uso: python3 script.py archivo.c salida.bin")
        return
    
    archivo_c = sys.argv[1]
    archivo_bin = sys.argv[2]
    
    try:
        # Leer archivo C
        with open(archivo_c, 'r') as f:
            contenido = f.read()
        
        # Buscar la variable cipherText
        inicio = contenido.find("unsigned char cipherText[] = {")
        if inicio == -1:
            print("Error: No se encontró 'unsigned char cipherText[] = {'")
            return
        
        # Encontrar el final del array (buscar '};' después del inicio)
        fin = contenido.find("};", inicio)
        if fin == -1:
            print("Error: No se encontró el final del array '};'")
            return
        
        # Extraer solo el contenido del array
        array_texto = contenido[inicio:fin+2]
        
        # Buscar todos los bytes hex (0xXX)
        bytes_hex = re.findall(r'0x([0-9A-Fa-f]{2})', array_texto)
        
        if not bytes_hex:
            print("Error: No se encontraron bytes en el array")
            return
        
        # Convertir a bytes y escribir archivo
        with open(archivo_bin, 'wb') as f:
            for hex_byte in bytes_hex:
                f.write(bytes.fromhex(hex_byte))
        
        print(f"OK: {len(bytes_hex)} bytes escritos en {archivo_bin}")
        
    except FileNotFoundError:
        print(f"Error: No se encontró el archivo '{archivo_c}'")
    except UnicodeDecodeError:
        print(f"Error: El archivo '{archivo_c}' no esta en UTF-8.")
        print(f"\nPuedes utilizar el siguiente comando para corregirlo:")
        print(f"\ticonv -f UTF-16 -t UTF-8 {archivo_c} > {archivo_c}_utf8")
    except Exception as e:
        print(f"Error: {type(e).__name__}")
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
