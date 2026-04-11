# Simple Applocker Runspace
Simple AppLocker runspace bypass where you can dinamically run commands.

## Args
- `/cmd:"your command"`: the command you want tu run
> [!NOTE]
> Important, remember to use double quotes (`"`) in your command
- `/output`: if you want the output to be shown when running

## Compilation
```powershell
 . 'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\Roslyn\csc.exe' /t:exe /out:sar.exe /platform:x64 /r:"C:\windows\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\v4.0_3.0.0.0__31bf3856ad364e35\System.Management.Automation.dll" .\SimpleApplockerRunspace.cs
```
> [!NOTE]
> If you are comiling from Visual Studio Code, use _Console Application (.NET Framework)_ for _C#_ and add the following references: 
> - `Right-click on References in the Solution Explorer > Add Reference > Search for "System.Configuration.Install"`.
> - Also click in _browsing_ and add `C:\Windows\assembly\GAC_MSIL\System.Management.Automation\1.0.0.0__31bf3856ad364e35\System.Management.Automation.dll`.

## Usage
```powershell
C:\\windows\\Microsoft.NET\\Framework64\\v4.0.30319\\InstallUtil.exe /logfile= /LogToConsole=false /U /cmd="whoami /priv" /output .\sar.exe
```
