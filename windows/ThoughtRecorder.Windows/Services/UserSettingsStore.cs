using Microsoft.Win32;

namespace ThoughtRecorder.Windows.Services;

internal sealed class UserSettingsStore
{
    private const string SettingsKeyPath = @"Software\VesselSystems\ThoughtRecorder";
    private const string HasShownWelcomeValueName = "HasShownWelcome";

    public bool HasShownWelcome
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(SettingsKeyPath, writable: false);
            return key?.GetValue(HasShownWelcomeValueName) is int value && value == 1;
        }
        set
        {
            using var key = Registry.CurrentUser.CreateSubKey(SettingsKeyPath);
            key?.SetValue(HasShownWelcomeValueName, value ? 1 : 0, RegistryValueKind.DWord);
        }
    }
}
