# Shellcode Runner with XOR

## How To
1. Generate your `.bin` shellcode
2. Encrypt with XOR and your _KEY_
3. Update _URL_ and _KEY_ in the `xorLoader.c` file
4. Compile with `gcc xorLoader.c -o xorLoader.elf -lcurl`
5. Run on the victim


