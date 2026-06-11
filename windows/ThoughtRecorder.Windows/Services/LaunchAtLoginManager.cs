using System;
using System.Diagnostics;
using Microsoft.Win32;

namespace ThoughtRecorder.Windows.Services;

internal sealed class LaunchAtLoginManager
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunValueName = "ThoughtRecorder";

    public bool IsEnabled
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: false);
            return string.Equals(key?.GetValue(RunValueName) as string, QuotedExecutablePath, StringComparison.OrdinalIgnoreCase);
        }
    }

    public void Enable()
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath, writable: true)
            ?? throw new InvalidOperationException("Could not open the current-user Run registry key.");
        key.SetValue(RunValueName, QuotedExecutablePath, RegistryValueKind.String);
    }

    public void Disable()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: true);
        key?.DeleteValue(RunValueName, throwOnMissingValue: false);
    }

    private static string QuotedExecutablePath => $"\"{ExecutablePath}\"";

    private static string ExecutablePath =>
        Environment.ProcessPath
        ?? Process.GetCurrentProcess().MainModule?.FileName
        ?? throw new InvalidOperationException("Could not determine the app executable path.");
}
