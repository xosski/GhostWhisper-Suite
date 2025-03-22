#include <windows.h>
#include <tlhelp32.h>
#include <tchar.h>
#include <iostream>

DWORD GetProcessIdByName(const std::wstring& processName) {
    PROCESSENTRY32W entry;
    entry.dwSize = sizeof(PROCESSENTRY32W);
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (Process32FirstW(snapshot, &entry)) {
        do {
            if (!_wcsicmp(entry.szExeFile, processName.c_str())) {
                CloseHandle(snapshot);
                return entry.th32ProcessID;
            }
        } while (Process32NextW(snapshot, &entry));
    }
    CloseHandle(snapshot);
    return 0;
}

bool InjectDLL(DWORD pid, const std::wstring& dllPath) {
    HANDLE hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
    if (!hProcess) return false;

    void* pRemotePath = VirtualAllocEx(hProcess, nullptr, (dllPath.size() + 1) * sizeof(wchar_t), MEM_COMMIT, PAGE_READWRITE);
    WriteProcessMemory(hProcess, pRemotePath, dllPath.c_str(), (dllPath.size() + 1) * sizeof(wchar_t), nullptr);
    HMODULE hKernel32 = GetModuleHandleW(L"Kernel32");
    FARPROC pLoadLibraryW = GetProcAddress(hKernel32, "LoadLibraryW");

    HANDLE hThread = CreateRemoteThread(hProcess, nullptr, 0, (LPTHREAD_START_ROUTINE)pLoadLibraryW, pRemotePath, 0, nullptr);
    if (!hThread) return false;
    WaitForSingleObject(hThread, INFINITE);
    VirtualFreeEx(hProcess, pRemotePath, 0, MEM_RELEASE);
    CloseHandle(hThread);
    CloseHandle(hProcess);
    return true;
}

int wmain(int argc, wchar_t* argv[]) {
    if (argc != 2) {
        std::wcout << L"Usage: WraithTap.exe <FullPathToDLL>" << std::endl;
        return 1;
    }
    std::wstring dllPath = argv[1];
    DWORD pid = GetProcessIdByName(L"Shell.exe");
    if (pid == 0) return 1;
    return InjectDLL(pid, dllPath) ? 0 : 1;
}