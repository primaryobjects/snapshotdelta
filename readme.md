PostRunCheck — Lightweight Post‑Execution Triage Script for Sandbox VMs
====

A small, hardened PowerShell triage script designed for virtual machines used to test suspicious software.
It collects targeted, high‑value indicators after running an installer, EXE, or game — without dumping huge logs or weakening VM security.

This script is ideal for:
- Malware‑analysis VMs
- Suspicious installers
- Unsafe software evaluation
- Hardened VirtualBox / VMware environments

It runs safely using ExecutionPolicy Bypass (per‑run), which does not persist or weaken the VM.

## What the script checks

The script gathers only the most relevant forensic indicators:

**Processes & Services**
Running processes (sorted by CPU)

**Running services**
Useful for spotting anything that stays resident after execution.

**Startup & Persistence**
HKCU/HKLM Run keys

**Scheduled tasks (filtered to essentials)**
Helps detect persistence mechanisms.

**Network Activity**
Established TCP connections
Shows if the program phoned home.

**Hosts File**
Detects tampering or redirection.

**Windows Defender**
Current protection status

Any threat detections logged during execution

**Installed Programs**
Quick list of newly installed software

All results are saved into a timestamped folder like:
```
C:\PostRunChecks_20261004_1217\
```

## Quick Start

### Use the graphical app

On Windows, double-click `dist\PostRunCheck.exe` to open the GUI; you do not
need to run either triage PowerShell script manually. Keep the `scripts` folder
beside `dist` so the app can find its GUI and triage scripts. Run the app as
Administrator so it can save snapshots in `C:\PostRunChecks_...` and collect
all indicators. The launcher source is in `src`.

The executable can be rebuilt on Windows with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-PostRunCheck.ps1
```

In VS Code, press **F5** to build and launch the app (requires the PowerShell
extension). The launch configuration runs the **Build PostRunCheck** task
first. To build without launching, press **Ctrl+Shift+B**; **Build PostRunCheck**
is the default build task. You can also use **Terminal → Run Task → Run
PostRunCheck**.

1. Click **Take Snapshot** before running the software you want to inspect.
2. Run the software, then click **Take Snapshot** again.
3. Select the earlier snapshot as the baseline and the later one as the after
   snapshot, then click **Compare Snapshots**. The report appears in the app and
   is also saved in the after-snapshot folder.

Comparison results open to an **Overview** of all categories. Red X cards and
tabs indicate changes; green checks indicate no changes. Click a card or tab to
see that category's findings, or open **Full Report** for the original report.

The snapshot list is refreshed after taking a snapshot; **Refresh Snapshots**
can be used to find folders created outside the app. **Open Selected Snapshot**
opens the selected after-snapshot folder in Explorer.

### Run the scripts manually

1. Inside your VM, run PowerShell as Administrator and run the script.
    ```bash
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\PostRunCheck.ps1
    ```
2. Run suspect program.
3. Run the script again.
    ```bash
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\PostRunCheck.ps1
    ```
4. Run a diff between the logs and compare results.
    ```bash
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Compare-Triage.ps1 -BaselinePath "C:\PostRunChecks_20261004_1230" -AfterPath "C:\PostRunChecks_20261004_1245"
    ```

## Script Output
The script creates a folder containing:

```
processes.txt
services.txt
startup_hklm.txt
startup_hkcu.txt
schtasks.txt
netstat.txt
hosts.txt
defender_status.txt
defender_detections.txt
installed_programs.txt
```

These files provide a fast, focused snapshot of system state after running suspicious software.

## Recommended VM Usage

This script is designed for hardened VMs.

- No Guest Additions
- No shared folders
- No clipboard integration
- No drag‑and‑drop
- No GPU acceleration
- No host integration
- Snapshots enabled

Run suspicious software → run this script → review output → revert snapshot.