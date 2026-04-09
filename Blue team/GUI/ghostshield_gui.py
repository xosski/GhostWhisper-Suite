from __future__ import annotations

import json
import os
import queue
import subprocess
import sys
import threading
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Dict, List, Optional

import tkinter as tk
from tkinter import filedialog, messagebox, scrolledtext, ttk


APP_TITLE = "GhostShield Blue Team Console"
DEFAULT_MODULE_DIR = Path(__file__).resolve().parent / "modules"


@dataclass
class ModuleAction:
    label: str
    function_name: str
    args_builder: Optional[Callable[["GhostShieldGUI"], str]] = None
    destructive: bool = False


@dataclass
class ModuleDefinition:
    display_name: str
    script_name: str
    actions: List[ModuleAction] = field(default_factory=list)


MODULES: List[ModuleDefinition] = [
    ModuleDefinition(
        display_name="Env Audit",
        script_name="envaudit.ps1",
        actions=[
            ModuleAction("Get Environment Assessment", "Get-EnvironmentAssessment"),
            ModuleAction("Get Security Baseline", "Get-SecurityBaseline"),
            ModuleAction("Test Admin Context", "Test-AdminContext"),
        ],
    ),
    ModuleDefinition(
        display_name="EDR Audit",
        script_name="edraudit.ps1",
        actions=[
            ModuleAction("Run EDR Audit", "Start-EDRAudit"),
            ModuleAction("Get EDR Presence", "Get-EDRPresence"),
            ModuleAction("Get Defender Status", "Get-DefenderStatus"),
        ],
    ),
    ModuleDefinition(
        display_name="Threat Hunt",
        script_name="threathunt.ps1",
        actions=[
            ModuleAction("Start Threat Hunt", "Start-ThreatHunt"),
            ModuleAction("Quick Threat Hunt", "Start-ThreatHunt -Quick"),
        ],
    ),
    ModuleDefinition(
        display_name="Persistence Audit",
        script_name="PersistenceAudit.ps1",
        actions=[
            ModuleAction("Get Persistence Findings", "Get-PersistenceFindings"),
            ModuleAction("Quick Persistence Findings", "Get-PersistenceFindings -Quick"),
            ModuleAction("Get Persistence Summary", "Get-PersistenceSummary"),
        ],
    ),
    ModuleDefinition(
        display_name="Memory Triage",
        script_name="memory_triage.ps1",
        actions=[
            ModuleAction("Start Memory Triage", "Start-MemoryTriage"),
            ModuleAction("Memory Triage (No Browser)", "Start-MemoryTriage -IncludeBrowserChecks:$false"),
            ModuleAction("Get Browser Artifact Summary", "Get-BrowserArtifactSummary"),
        ],
    ),
    ModuleDefinition(
        display_name="Network Audit",
        script_name="network_audit.ps1",
        actions=[
            ModuleAction("Start Network Audit", "Start-NetworkAudit"),
            ModuleAction("Network Audit + Discovery", "Start-NetworkAudit -IncludeDiscovery"),
            ModuleAction("Network Discovery", "Invoke-NetworkDiscovery -IncludeHostnames"),
        ],
    ),
    ModuleDefinition(
        display_name="Artifact Collector",
        script_name="artifactcollector.ps1",
        actions=[
            ModuleAction("Start Artifact Collection", "Start-ArtifactCollection", destructive=False),
            ModuleAction("Export IR Bundle", "Export-IRBundle", destructive=False),
        ],
    ),
    ModuleDefinition(
        display_name="Containment",
        script_name="containment.ps1",
        actions=[
            ModuleAction("Get Containment Status", "Get-ContainmentStatus"),
            ModuleAction("Start Host Isolation", "Start-HostIsolation", destructive=True),
            ModuleAction("Remove Containment Rules", "Remove-ContainmentRules", destructive=True),
        ],
    ),
    ModuleDefinition(
        display_name="Remediation",
        script_name="remediation.ps1",
        actions=[
            ModuleAction("Initialize Remediation Paths", "Initialize-RemediationPaths"),
            ModuleAction("Start Remediation", "Start-Remediation", destructive=True),
        ],
    ),
    ModuleDefinition(
        display_name="Evidence Seal",
        script_name="evidence_seal.ps1",
        actions=[
            ModuleAction("Protect Evidence Bundle", "Protect-EvidenceBundle"),
            ModuleAction("Get Evidence Hashes (Case Dir)", "Get-EvidenceHashes", destructive=False),
        ],
    ),
    ModuleDefinition(
        display_name="Compliance Guard",
        script_name="compliance_guard.ps1",
        actions=[
            ModuleAction("Get Compliance Policy", "Get-CompliancePolicy"),
            ModuleAction("Set Audit Mode", "Set-ComplianceMode -Mode Audit"),
            ModuleAction("Set Response Mode", "Set-ComplianceMode -Mode Response"),
        ],
    ),
    ModuleDefinition(
        display_name="Ghost Logger",
        script_name="GhostLogger_BlueTeam.ps1",
        actions=[
            ModuleAction("Initialize Logger", "Initialize-GhostLogger"),
            ModuleAction("Start Monitoring", "Start-GhostMonitoring"),
            ModuleAction("Stop Monitoring", "Stop-GhostMonitoring"),
            ModuleAction("Logger Status", "Get-GhostLoggerStatus"),
        ],
    ),
    ModuleDefinition(
        display_name="Reporting",
        script_name="reporting.ps1",
        actions=[
            ModuleAction("New Incident Report", "New-IncidentReport"),
            ModuleAction("New Case Summary", "New-CaseSummary"),
        ],
    ),
]


class GhostShieldGUI:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title(APP_TITLE)
        self.root.geometry("1400x900")

        self.output_queue: "queue.Queue[str]" = queue.Queue()
        self.current_process: Optional[subprocess.Popen[str]] = None
        self.module_dir = tk.StringVar(value=str(DEFAULT_MODULE_DIR))
        self.case_id = tk.StringVar(value="")
        self.case_dir = tk.StringVar(value="")
        self.custom_args = tk.StringVar(value="")
        self.powershell_exe = tk.StringVar(value=self._detect_powershell())
        self.what_if = tk.BooleanVar(value=False)
        self.pretty_json = tk.BooleanVar(value=True)

        self.module_map: Dict[str, ModuleDefinition] = {m.display_name: m for m in MODULES}
        self.selected_module = tk.StringVar(value=MODULES[0].display_name)
        self.selected_action = tk.StringVar(value=MODULES[0].actions[0].label)

        self._build_ui()
        self._refresh_actions()
        self.root.after(100, self._poll_output_queue)

    def _detect_powershell(self) -> str:
        candidates = ["pwsh", "powershell"]
        for candidate in candidates:
            try:
                completed = subprocess.run(
                    [candidate, "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                if completed.returncode == 0:
                    return candidate
            except Exception:
                continue
        return "powershell"

    def _build_ui(self) -> None:
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(1, weight=1)

        top = ttk.Frame(self.root, padding=8)
        top.grid(row=0, column=0, sticky="nsew")
        top.columnconfigure(1, weight=1)
        top.columnconfigure(3, weight=1)
        top.columnconfigure(5, weight=1)

        ttk.Label(top, text="Module Directory").grid(row=0, column=0, sticky="w")
        ttk.Entry(top, textvariable=self.module_dir).grid(row=0, column=1, sticky="ew", padx=4)
        ttk.Button(top, text="Browse", command=self._browse_module_dir).grid(row=0, column=2, padx=4)

        ttk.Label(top, text="PowerShell").grid(row=0, column=3, sticky="w")
        ttk.Entry(top, textvariable=self.powershell_exe).grid(row=0, column=4, sticky="ew", padx=4)

        ttk.Label(top, text="Case ID").grid(row=1, column=0, sticky="w")
        ttk.Entry(top, textvariable=self.case_id).grid(row=1, column=1, sticky="ew", padx=4)

        ttk.Label(top, text="Case Directory").grid(row=1, column=3, sticky="w")
        ttk.Entry(top, textvariable=self.case_dir).grid(row=1, column=4, sticky="ew", padx=4)
        ttk.Button(top, text="Browse", command=self._browse_case_dir).grid(row=1, column=5, padx=4)

        middle = ttk.Panedwindow(self.root, orient=tk.HORIZONTAL)
        middle.grid(row=1, column=0, sticky="nsew")

        left = ttk.Frame(middle, padding=8)
        right = ttk.Frame(middle, padding=8)
        middle.add(left, weight=1)
        middle.add(right, weight=2)

        left.columnconfigure(0, weight=1)
        right.columnconfigure(0, weight=1)
        right.rowconfigure(3, weight=1)

        ttk.Label(left, text="Module").grid(row=0, column=0, sticky="w")
        module_combo = ttk.Combobox(
            left,
            textvariable=self.selected_module,
            values=list(self.module_map.keys()),
            state="readonly",
        )
        module_combo.grid(row=1, column=0, sticky="ew", pady=(0, 8))
        module_combo.bind("<<ComboboxSelected>>", lambda _e: self._refresh_actions())

        ttk.Label(left, text="Action").grid(row=2, column=0, sticky="w")
        self.action_combo = ttk.Combobox(left, textvariable=self.selected_action, state="readonly")
        self.action_combo.grid(row=3, column=0, sticky="ew", pady=(0, 8))

        ttk.Label(left, text="Custom PowerShell Args / Overrides").grid(row=4, column=0, sticky="w")
        ttk.Entry(left, textvariable=self.custom_args).grid(row=5, column=0, sticky="ew", pady=(0, 8))

        ttk.Checkbutton(left, text="-WhatIf for destructive actions", variable=self.what_if).grid(row=6, column=0, sticky="w")
        ttk.Checkbutton(left, text="Pretty-print JSON output", variable=self.pretty_json).grid(row=7, column=0, sticky="w")

        btn_frame = ttk.Frame(left)
        btn_frame.grid(row=8, column=0, sticky="ew", pady=12)
        btn_frame.columnconfigure((0, 1, 2), weight=1)
        ttk.Button(btn_frame, text="Run Action", command=self.run_selected_action).grid(row=0, column=0, padx=2, sticky="ew")
        ttk.Button(btn_frame, text="Stop", command=self.stop_current_process).grid(row=0, column=1, padx=2, sticky="ew")
        ttk.Button(btn_frame, text="Check Modules", command=self.check_modules).grid(row=0, column=2, padx=2, sticky="ew")

        ttk.Label(left, text="Module Status").grid(row=9, column=0, sticky="w")
        self.module_status = scrolledtext.ScrolledText(left, height=18, wrap=tk.WORD)
        self.module_status.grid(row=10, column=0, sticky="nsew")
        left.rowconfigure(10, weight=1)

        ttk.Label(right, text="Generated PowerShell Command").grid(row=0, column=0, sticky="w")
        self.command_preview = scrolledtext.ScrolledText(right, height=6, wrap=tk.WORD)
        self.command_preview.grid(row=1, column=0, sticky="ew", pady=(0, 8))

        ttk.Label(right, text="Output").grid(row=2, column=0, sticky="w")
        self.output = scrolledtext.ScrolledText(right, wrap=tk.WORD)
        self.output.grid(row=3, column=0, sticky="nsew")

        bottom = ttk.Frame(self.root, padding=8)
        bottom.grid(row=2, column=0, sticky="ew")
        bottom.columnconfigure(0, weight=1)
        self.status = tk.StringVar(value="Ready")
        ttk.Label(bottom, textvariable=self.status).grid(row=0, column=0, sticky="w")
        ttk.Button(bottom, text="Clear Output", command=lambda: self.output.delete("1.0", tk.END)).grid(row=0, column=1, padx=4)
        ttk.Button(bottom, text="Save Output", command=self.save_output).grid(row=0, column=2, padx=4)

    def _browse_module_dir(self) -> None:
        path = filedialog.askdirectory(initialdir=self.module_dir.get() or str(Path.cwd()))
        if path:
            self.module_dir.set(path)

    def _browse_case_dir(self) -> None:
        path = filedialog.askdirectory(initialdir=self.case_dir.get() or str(Path.cwd()))
        if path:
            self.case_dir.set(path)

    def _refresh_actions(self) -> None:
        module = self.module_map[self.selected_module.get()]
        labels = [action.label for action in module.actions]
        self.action_combo.configure(values=labels)
        if labels:
            self.selected_action.set(labels[0])
        self._update_command_preview()

    def _selected_action_obj(self) -> ModuleAction:
        module = self.module_map[self.selected_module.get()]
        for action in module.actions:
            if action.label == self.selected_action.get():
                return action
        return module.actions[0]

    def _update_command_preview(self) -> None:
        command = self.build_powershell_command(preview=True)
        self.command_preview.delete("1.0", tk.END)
        self.command_preview.insert(tk.END, command)

    def build_function_invocation(self, action: ModuleAction) -> str:
        invocation = action.function_name.strip()

        extra = self.custom_args.get().strip()
        if extra:
            invocation = f"{invocation} {extra}"

        case_id = self.case_id.get().strip()
        case_dir = self.case_dir.get().strip()

        if action.function_name.startswith("Initialize-GhostLogger") and case_id:
            invocation = f"{action.function_name} -CaseId '{case_id}'"
        elif action.function_name.startswith("Start-ArtifactCollection") and case_id:
            invocation = f"{action.function_name} -CaseId '{case_id}'"
        elif action.function_name.startswith("Export-IRBundle") and case_id:
            invocation = f"{action.function_name} -CaseId '{case_id}'"
        elif action.function_name.startswith("Protect-EvidenceBundle"):
            if case_dir:
                invocation = f"{action.function_name} -CaseDirectory '{case_dir}'"
            elif case_id:
                invocation = f"{action.function_name} -CaseId '{case_id}'"
        elif action.function_name.startswith("New-IncidentReport"):
            if case_dir:
                invocation = f"{action.function_name} -CaseDirectory '{case_dir}'"
            elif case_id:
                invocation = f"{action.function_name} -CaseId '{case_id}'"
        elif action.function_name.startswith("New-CaseSummary"):
            if case_dir:
                invocation = f"{action.function_name} -CaseDirectory '{case_dir}'"
            elif case_id:
                invocation = f"{action.function_name} -CaseId '{case_id}'"
        elif action.function_name.startswith("Get-EvidenceHashes") and case_dir:
            invocation = f"{action.function_name} -Path '{case_dir}' -Recurse"

        if action.destructive and self.what_if.get() and "-WhatIf" not in invocation:
            invocation = f"{invocation} -WhatIf"

        return invocation

    def build_powershell_command(self, preview: bool = False) -> str:
        module = self.module_map[self.selected_module.get()]
        action = self._selected_action_obj()
        module_path = Path(self.module_dir.get()) / module.script_name
        invocation = self.build_function_invocation(action)

        escaped_module_path = str(module_path).replace("'", "''")
        body = (
            "$ErrorActionPreference = 'Stop'; "
            f"$modulePath = '{escaped_module_path}'; "
            "$moduleContent = Get-Content -LiteralPath $modulePath -Raw; "
            "$moduleName = 'GhostShield.Gui.Dynamic'; "
            "if (Get-Module -Name $moduleName -ErrorAction SilentlyContinue) { Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue }; "
            "$module = New-Module -Name $moduleName -ScriptBlock ([scriptblock]::Create($moduleContent)); "
            "Import-Module -ModuleInfo $module -Force -ErrorAction Stop | Out-Null; "
            f"$result = {invocation}; "
            "if ($null -eq $result) { '' } elseif ($result -is [string]) { $result } else { $result | ConvertTo-Json -Depth 20 }"
        )
        if preview:
            return f"{self.powershell_exe.get()} -NoProfile -ExecutionPolicy Bypass -Command \"{body}\""
        return body

    def append_output(self, text: str) -> None:
        self.output.insert(tk.END, text)
        self.output.see(tk.END)

    def _poll_output_queue(self) -> None:
        try:
            while True:
                text = self.output_queue.get_nowait()
                self.append_output(text)
        except queue.Empty:
            pass
        self.root.after(100, self._poll_output_queue)

    def check_modules(self) -> None:
        self.module_status.delete("1.0", tk.END)
        module_dir = Path(self.module_dir.get())
        if not module_dir.exists():
            self.module_status.insert(tk.END, f"Module directory not found: {module_dir}\n")
            return

        for module in MODULES:
            path = module_dir / module.script_name
            status = "FOUND" if path.exists() else "MISSING"
            self.module_status.insert(tk.END, f"[{status}] {module.script_name}\n")

    def run_selected_action(self) -> None:
        if self.current_process and self.current_process.poll() is None:
            messagebox.showwarning(APP_TITLE, "A process is already running.")
            return

        self._update_command_preview()
        module = self.module_map[self.selected_module.get()]
        action = self._selected_action_obj()
        module_path = Path(self.module_dir.get()) / module.script_name

        if not module_path.exists():
            messagebox.showerror(APP_TITLE, f"Module not found:\n{module_path}")
            return

        if action.destructive and not self.what_if.get():
            confirmed = messagebox.askyesno(
                APP_TITLE,
                f"{action.label} is marked as a response/destructive action. Continue without -WhatIf?",
            )
            if not confirmed:
                return

        self.output.delete("1.0", tk.END)
        self.status.set(f"Running: {module.display_name} -> {action.label}")

        command_body = self.build_powershell_command(preview=False)
        args = [
            self.powershell_exe.get(),
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command_body,
        ]

        def runner() -> None:
            try:
                self.current_process = subprocess.Popen(
                    args,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                )
                assert self.current_process.stdout is not None
                for line in self.current_process.stdout:
                    self.output_queue.put(line)
                code = self.current_process.wait()
                self.output_queue.put(f"\n[exit code: {code}]\n")
                self.status.set("Completed" if code == 0 else f"Failed with exit code {code}")
                self._try_pretty_print_output()
            except Exception as exc:
                self.output_queue.put(f"\n[error] {exc}\n")
                self.status.set("Execution failed")
            finally:
                self.current_process = None

        threading.Thread(target=runner, daemon=True).start()

    def _try_pretty_print_output(self) -> None:
        if not self.pretty_json.get():
            return
        raw = self.output.get("1.0", tk.END).strip()
        if not raw:
            return
        try:
            parsed = json.loads(raw)
            pretty = json.dumps(parsed, indent=2)
            self.output.delete("1.0", tk.END)
            self.output.insert(tk.END, pretty)
        except Exception:
            pass

    def stop_current_process(self) -> None:
        if self.current_process and self.current_process.poll() is None:
            self.current_process.terminate()
            self.status.set("Stopping process...")
        else:
            self.status.set("No active process")

    def save_output(self) -> None:
        path = filedialog.asksaveasfilename(
            defaultextension=".txt",
            filetypes=[("Text files", "*.txt"), ("JSON files", "*.json"), ("All files", "*.*")],
        )
        if not path:
            return
        Path(path).write_text(self.output.get("1.0", tk.END), encoding="utf-8")
        self.status.set(f"Saved output to {path}")


def main() -> None:
    root = tk.Tk()
    app = GhostShieldGUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()
