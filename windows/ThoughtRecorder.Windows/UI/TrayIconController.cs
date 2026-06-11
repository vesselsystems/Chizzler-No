using System;
using System.Drawing;
using System.Windows.Forms;

namespace ThoughtRecorder.Windows.UI;

internal sealed record TrayIconState(
    string StateLabel,
    bool HasTranscript,
    bool IsBusy,
    bool IsLaunchAtLoginEnabled);

internal sealed class TrayIconController : IDisposable
{
    private readonly NotifyIcon notifyIcon = new();
    private readonly ToolStripMenuItem pasteLatestMenuItem;
    private readonly ToolStripMenuItem copyLatestMenuItem;
    private readonly ToolStripMenuItem showLatestMenuItem;
    private readonly ToolStripMenuItem clearLatestMenuItem;
    private readonly ToolStripMenuItem openAtLoginMenuItem;
    private readonly Icon trayIcon;

    public Action? PasteLatestRequested { get; init; }
    public Action? CopyLatestRequested { get; init; }
    public Action? ClearLatestRequested { get; init; }
    public Action? ShowLatestRequested { get; init; }
    public Action? ToggleLaunchAtLoginRequested { get; init; }
    public Action? ShowInstructionsRequested { get; init; }
    public Action? QuitRequested { get; init; }

    public TrayIconController(string recordShortcutLabel)
    {
        pasteLatestMenuItem = new ToolStripMenuItem("Paste Latest Transcript", null, (_, _) => PasteLatestRequested?.Invoke());
        copyLatestMenuItem = new ToolStripMenuItem("Copy Latest Transcript", null, (_, _) => CopyLatestRequested?.Invoke());
        showLatestMenuItem = new ToolStripMenuItem("Show Latest Transcript", null, (_, _) => ShowLatestRequested?.Invoke());
        clearLatestMenuItem = new ToolStripMenuItem("Clear Latest Transcript", null, (_, _) => ClearLatestRequested?.Invoke());
        openAtLoginMenuItem = new ToolStripMenuItem("Open at Login", null, (_, _) => ToggleLaunchAtLoginRequested?.Invoke());

        var menu = new ContextMenuStrip();
        menu.Items.Add(new ToolStripMenuItem($"Hold to Talk: {recordShortcutLabel}") { Enabled = false });
        menu.Items.Add(new ToolStripMenuItem("Paste: Ctrl+V after capture") { Enabled = false });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(pasteLatestMenuItem);
        menu.Items.Add(copyLatestMenuItem);
        menu.Items.Add(showLatestMenuItem);
        menu.Items.Add(clearLatestMenuItem);
        menu.Items.Add(openAtLoginMenuItem);
        menu.Items.Add(new ToolStripMenuItem("Show Instructions", null, (_, _) => ShowInstructionsRequested?.Invoke()));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("Quit", null, (_, _) => QuitRequested?.Invoke()));

        trayIcon = AppIconFactory.CreateTrayIcon();
        notifyIcon.Icon = trayIcon;
        notifyIcon.Text = "ThoughtRecorder";
        notifyIcon.ContextMenuStrip = menu;
        notifyIcon.Visible = true;
        notifyIcon.DoubleClick += (_, _) => ShowInstructionsRequested?.Invoke();
    }

    public void Update(TrayIconState state)
    {
        notifyIcon.Text = $"ThoughtRecorder - {state.StateLabel}";
        pasteLatestMenuItem.Enabled = state.HasTranscript && !state.IsBusy;
        copyLatestMenuItem.Enabled = state.HasTranscript;
        showLatestMenuItem.Enabled = state.HasTranscript;
        clearLatestMenuItem.Enabled = state.HasTranscript;
        openAtLoginMenuItem.Checked = state.IsLaunchAtLoginEnabled;
    }

    public void Dispose()
    {
        notifyIcon.Visible = false;
        notifyIcon.Dispose();
        trayIcon.Dispose();
    }
}
