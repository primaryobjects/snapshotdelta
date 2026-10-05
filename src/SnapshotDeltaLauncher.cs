using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows.Forms;

internal static class SnapshotDeltaLauncher
{
    private static int Main()
    {
        try
        {
            string appDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string guiScript = Path.Combine(
                appDirectory,
                @"scripts\SnapshotDelta-GUI.ps1");
            if (!File.Exists(guiScript))
            {
                guiScript = Path.GetFullPath(Path.Combine(
                    appDirectory,
                    @"..\scripts\SnapshotDelta-GUI.ps1"));
            }
            if (!File.Exists(guiScript))
            {
                throw new FileNotFoundException(
                    "SnapshotDelta could not find its GUI file: " + guiScript,
                    guiScript);
            }

            string windowsDirectory = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
            string powerShellDirectory = Environment.Is64BitOperatingSystem && !Environment.Is64BitProcess
                ? Path.Combine(windowsDirectory, "Sysnative")
                : Path.Combine(windowsDirectory, "System32");
            string powerShell = Path.Combine(
                powerShellDirectory,
                @"WindowsPowerShell\v1.0\powershell.exe");
            if (!File.Exists(powerShell))
            {
                throw new FileNotFoundException("Windows PowerShell could not be found.", powerShell);
            }

            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = powerShell;
            startInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File " +
                QuoteArgument(guiScript);
            startInfo.UseShellExecute = false;
            startInfo.CreateNoWindow = true;
            startInfo.RedirectStandardOutput = true;
            startInfo.RedirectStandardError = true;

            using (Process process = new Process())
            {
                process.StartInfo = startInfo;
                if (!process.Start())
                {
                    throw new InvalidOperationException("Windows PowerShell could not be started.");
                }

                var standardOutput = process.StandardOutput.ReadToEndAsync();
                var standardError = process.StandardError.ReadToEndAsync();
                process.WaitForExit();

                string output = standardOutput.Result.Trim();
                string errors = standardError.Result.Trim();
                if (process.ExitCode != 0 || !String.IsNullOrWhiteSpace(errors))
                {
                    StringBuilder details = new StringBuilder();
                    if (!String.IsNullOrWhiteSpace(errors))
                    {
                        details.AppendLine(errors);
                    }
                    if (!String.IsNullOrWhiteSpace(output))
                    {
                        details.AppendLine(output);
                    }

                    MessageBox.Show(
                        details.Length == 0
                            ? "SnapshotDelta exited with code " + process.ExitCode + "."
                            : details.ToString(),
                        "SnapshotDelta",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                    return process.ExitCode == 0 ? 1 : process.ExitCode;
                }
            }

            return 0;
        }
        catch (Exception exception)
        {
            MessageBox.Show(
                exception.Message,
                "SnapshotDelta could not start",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 1;
        }
    }

    private static string QuoteArgument(string value)
    {
        StringBuilder quoted = new StringBuilder();
        quoted.Append('"');
        int backslashes = 0;

        foreach (char character in value)
        {
            if (character == '\\')
            {
                backslashes++;
            }
            else if (character == '"')
            {
                quoted.Append('\\', backslashes * 2 + 1);
                quoted.Append('"');
                backslashes = 0;
            }
            else
            {
                quoted.Append('\\', backslashes);
                quoted.Append(character);
                backslashes = 0;
            }
        }

        quoted.Append('\\', backslashes * 2);
        quoted.Append('"');
        return quoted.ToString();
    }
}
