using System;
using System.Diagnostics;
using System.IO;

namespace LinuxPDF
{
    class Program
    {
        static void Main(string[] args)
        {
            // Default to the local script-based "exorcism" approach
            bool runLocalScript = true;
            string isoPath = null;
            string mode = "exorcism"; // your existing default
            string targetPath = Environment.GetEnvironmentVariable("TEMP");
            bool offline = false;
            bool log = false;

            // Parse arguments
            // e.g.  --boot=ghost_boot.iso --mode=bind --target="C:\some\path" --offline --log
            foreach (var arg in args)
            {
                if (arg.StartsWith("--boot="))
                {
                    isoPath = arg.Substring("--boot=".Length);
                    runLocalScript = false;
                }
                else if (arg.StartsWith("--mode="))
                {
                    mode = arg.Substring("--mode=".Length);
                }
                else if (arg.StartsWith("--target="))
                {
                    targetPath = arg.Substring("--target=".Length);
                }
                else if (arg == "--offline") offline = true;
                else if (arg == "--log") log = true;
            }

            // If we have an ISO path, attempt to run QEMU
            if (!string.IsNullOrEmpty(isoPath))
            {
                // Full path to QEMU exe, placed next to LinuxPDF.exe
                string baseDir = AppContext.BaseDirectory;
                string qemuExe = Path.Combine(baseDir, "qemu-system-x86_64.exe");

                if (!File.Exists(qemuExe))
                {
                    Console.Error.WriteLine("[LinuxPDF] QEMU exe not found, can't boot ISO. Will fallback to local script.");
                    runLocalScript = true;
                }
                else
                {
                    // Also check if isoPath is relative
                    if (!Path.IsPathRooted(isoPath))
                        isoPath = Path.Combine(baseDir, isoPath);

                    if (!File.Exists(isoPath))
                    {
                        Console.Error.WriteLine($"[LinuxPDF] ISO file not found: {isoPath}. Fallback to local script.");
                        runLocalScript = true;
                    }
                    else
                    {
                        // We have qemu + iso => run the VM
                        string qemuArgs = $"-m 512 -cdrom \"{isoPath}\" -boot d -enable-kvm";
                        Console.WriteLine($"[LinuxPDF] Launching QEMU with: {qemuArgs}");

                        var psi = new ProcessStartInfo(qemuExe, qemuArgs)
                        {
                            UseShellExecute = false,
                            RedirectStandardOutput = true,
                            RedirectStandardError = true,
                            CreateNoWindow = false
                        };

                        using (var proc = Process.Start(psi))
                        {
                            proc.BeginOutputReadLine();
                            proc.BeginErrorReadLine();
                            proc.WaitForExit();
                        }

                        Console.WriteLine("[LinuxPDF] QEMU run complete.");
                    }
                }
            }

            // If no ISO or QEMU not found => fallback to local script
            if (runLocalScript)
            {
                // same logic you had before, e.g. call LinuxPDF_Runtime.ps1
                string baseDir = AppContext.BaseDirectory;
                string psPath = Path.Combine(baseDir, "LinuxPDF_Runtime.ps1");
                string psCommand = $"-ExecutionPolicy Bypass -NoLogo -NoProfile -File \"{psPath}\" -Mode {mode} -Path \"{targetPath}\"";

                if (offline) psCommand += " -Offline";
                if (log) psCommand += " -Log";

                Console.WriteLine($"[LinuxPDF] Fallback to local script with mode='{mode}', path='{targetPath}', offline={offline}, log={log}");

                Process.Start("powershell.exe", psCommand);
            }
        }
    }
}
