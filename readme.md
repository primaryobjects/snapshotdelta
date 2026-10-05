# PostRunCheck

PostRunCheck is a Windows desktop app for capturing and comparing system
snapshots in a sandbox VM before and after testing software.

Ideal for:

- Malware‑analysis VMs
- Suspicious installers
- Unsafe software evaluation
- Hardened VirtualBox / VMware environments

## Start the app

1. Run `dist\PostRunCheck.exe` as Administrator for the most complete results.
2. Click **Take Snapshot** before testing the software.
3. Run the software, then click **Take Snapshot** again.
4. Choose the earlier snapshot as the baseline and the later one as the after
   snapshot, then click **Compare Snapshots**.

Keep the project folders together so the app can find its supporting files.
Snapshots are saved in timestamped folders under `C:\PostRunChecks_...`.

## Review results

The comparison overview shows each category with a red X when changes are
found, or a green check when none are detected. Select a category card or tab
to review its findings, or open **Full Report** to see the complete comparison.
Reports are also saved in the after-snapshot folder.

PostRunCheck checks processes, services, startup entries, scheduled tasks,
network connections, the hosts file, Defender status and detections, and
installed programs.

## Develop in VS Code

- Press **F5** to build and run the app.
- Press **Ctrl+Shift+B** to build the app without launching it.

## Sandbox guidance

Use a disposable VM with snapshots enabled. Disable shared folders, clipboard
integration, drag-and-drop, Guest Additions, and other host integrations where
possible. After reviewing results, revert the VM to its clean snapshot.
