using System;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;
using ThoughtRecorder.Windows.Services;
using ThoughtRecorder.Windows.UI;

namespace ThoughtRecorder.Windows;

internal sealed class RecorderApplicationController : IDisposable
{
    private enum AppState
    {
        Idle,
        Recording,
        Processing,
        ReadyToPaste,
        Pasting,
        Error
    }

    private sealed record TranscriptBuffer(string Text, DateTimeOffset CreatedAt);

    private const string RecordShortcutLabel = "Ctrl + Alt + Shift + Space";

    private readonly Dispatcher dispatcher;
    private readonly SpeechController speechController = new();
    private readonly ClipboardService clipboardService = new();
    private readonly LaunchAtLoginManager launchAtLoginManager = new();
    private readonly UserSettingsStore userSettingsStore = new();
    private readonly OverlayWindow overlayWindow = new();
    private readonly TrayIconController trayIconController;
    private readonly WindowsHotKeyManager hotKeyManager;

    private AppState state = AppState.Idle;
    private TranscriptBuffer? latestTranscript;
    private bool disposed;

    public RecorderApplicationController(Dispatcher dispatcher)
    {
        this.dispatcher = dispatcher;

        trayIconController = new TrayIconController(RecordShortcutLabel)
        {
            PasteLatestRequested = () => HandlePasteRequest("tray"),
            CopyLatestRequested = CopyLatestTranscript,
            ClearLatestRequested = ClearLatestTranscript,
            ShowLatestRequested = ShowLatestTranscript,
            ToggleLaunchAtLoginRequested = ToggleLaunchAtLogin,
            ShowInstructionsRequested = ShowInstructions,
            QuitRequested = Quit
        };

        hotKeyManager = new WindowsHotKeyManager(eventKind =>
        {
            dispatcher.BeginInvoke(() => HandleHotKeyEvent(eventKind));
        });
    }

    public void Start()
    {
        try
        {
            hotKeyManager.Start();
            TransitionTo(SteadyStateAfterCycle(), "startup");
            ShowWelcomeIfNeeded();
        }
        catch (Exception ex)
        {
            TransitionTo(AppState.Error, "hotkey startup failed");
            overlayWindow.ShowStatus($"Shortcut error: {ex.Message}", StatusDuration.Error);
            TransitionTo(SteadyStateAfterCycle(), "recover after hotkey error");
        }
    }

    private void HandleHotKeyEvent(WindowsHotKeyManager.EventKind eventKind)
    {
        switch (eventKind)
        {
            case WindowsHotKeyManager.EventKind.RecordKeyDown:
                HandleRecordKeyDown();
                break;
            case WindowsHotKeyManager.EventKind.RecordKeyUp:
                _ = HandleRecordKeyUpAsync();
                break;
            case WindowsHotKeyManager.EventKind.Cancel:
                HandleCancelRequest();
                break;
        }
    }

    private void HandleRecordKeyDown()
    {
        if (state is not (AppState.Idle or AppState.ReadyToPaste))
        {
            return;
        }

        try
        {
            speechController.StartRecording();
            TransitionTo(AppState.Recording, "record key down");
            overlayWindow.ShowStatus("Listening...", StatusDuration.LongRunning);
        }
        catch (Exception ex)
        {
            TransitionTo(AppState.Error, "recording start failed");
            overlayWindow.ShowStatus(ex.Message, StatusDuration.Error);
            TransitionTo(SteadyStateAfterCycle(), "recover after recording start error");
        }
    }

    private async Task HandleRecordKeyUpAsync()
    {
        if (state != AppState.Recording)
        {
            return;
        }

        TransitionTo(AppState.Processing, "record key up");
        overlayWindow.ShowStatus("Processing...", StatusDuration.LongRunning);

        string transcript;
        try
        {
            transcript = (await speechController.StopRecordingAsync()).Trim();
        }
        catch (Exception ex)
        {
            TransitionTo(AppState.Error, "recording stop failed");
            overlayWindow.ShowStatus(ex.Message, StatusDuration.Error);
            TransitionTo(SteadyStateAfterCycle(), "recover after recording stop error");
            return;
        }

        if (string.IsNullOrWhiteSpace(transcript))
        {
            overlayWindow.ShowStatus("No new speech detected - latest unchanged", StatusDuration.Short);
            TransitionTo(SteadyStateAfterCycle(), "empty transcript");
            return;
        }

        latestTranscript = new TranscriptBuffer(transcript, DateTimeOffset.Now);
        if (clipboardService.WriteTextToClipboard(transcript))
        {
            overlayWindow.ShowStatus("Copied", StatusDuration.Short);
        }
        else
        {
            overlayWindow.ShowStatus("Clipboard update failed", StatusDuration.Error);
        }

        TransitionTo(SteadyStateAfterCycle(), "processing completed");
    }

    private void HandlePasteRequest(string trigger)
    {
        if (state is AppState.Recording or AppState.Processing or AppState.Pasting)
        {
            return;
        }

        if (latestTranscript is null)
        {
            overlayWindow.ShowStatus("Nothing to paste", StatusDuration.Short);
            TransitionTo(SteadyStateAfterCycle(), $"paste requested from {trigger} with empty buffer");
            return;
        }

        TransitionTo(AppState.Pasting, $"paste requested from {trigger}");
        try
        {
            var result = clipboardService.PasteTranscript(latestTranscript.Text);
            overlayWindow.ShowStatus(result == ClipboardService.PasteResult.Pasted ? "Pasted" : "Copied", StatusDuration.Short);
        }
        catch (Exception ex)
        {
            if (clipboardService.WriteTextToClipboard(latestTranscript.Text))
            {
                overlayWindow.ShowStatus("Copied", StatusDuration.Short);
            }
            else
            {
                overlayWindow.ShowStatus(ex.Message, StatusDuration.Error);
                TransitionTo(AppState.Error, "paste failed");
            }
        }

        TransitionTo(SteadyStateAfterCycle(), "paste completed");
    }

    private void HandleCancelRequest()
    {
        if (state is not (AppState.Recording or AppState.Processing))
        {
            return;
        }

        speechController.CancelRecording();
        overlayWindow.ShowStatus("Canceled", StatusDuration.Short);
        TransitionTo(SteadyStateAfterCycle(), "recording canceled");
    }

    private void CopyLatestTranscript()
    {
        if (latestTranscript is null)
        {
            overlayWindow.ShowStatus("Nothing to paste", StatusDuration.Short);
            return;
        }

        overlayWindow.ShowStatus(
            clipboardService.WriteTextToClipboard(latestTranscript.Text) ? "Copied" : "Clipboard update failed",
            StatusDuration.Short);
    }

    private void ClearLatestTranscript()
    {
        latestTranscript = null;
        TransitionTo(AppState.Idle, "buffer cleared");
    }

    private void ShowLatestTranscript()
    {
        var text = latestTranscript?.Text ?? "No latest transcript stored.";
        System.Windows.MessageBox.Show(
            text,
            "Latest Transcript",
            System.Windows.MessageBoxButton.OK,
            System.Windows.MessageBoxImage.Information);
    }

    private void ToggleLaunchAtLogin()
    {
        try
        {
            if (launchAtLoginManager.IsEnabled)
            {
                launchAtLoginManager.Disable();
            }
            else
            {
                launchAtLoginManager.Enable();
            }
        }
        catch (Exception ex)
        {
            overlayWindow.ShowStatus(ex.Message, StatusDuration.Error);
        }

        RefreshTrayState();
    }

    private void ShowWelcomeIfNeeded()
    {
        if (userSettingsStore.HasShownWelcome)
        {
            return;
        }

        userSettingsStore.HasShownWelcome = true;
        ShowInstructions();
    }

    private void ShowInstructions()
    {
        System.Windows.MessageBox.Show(
            $"ThoughtRecorder is a tiny voice buffer.{Environment.NewLine}{Environment.NewLine}" +
            $"1. Hold {RecordShortcutLabel} to record.{Environment.NewLine}" +
            $"2. Release to finalize and copy the transcript to the clipboard.{Environment.NewLine}" +
            $"3. Press normal Ctrl+V anywhere to paste it.{Environment.NewLine}{Environment.NewLine}" +
            "The tray menu also includes Paste Latest Transcript and Copy Latest Transcript actions.",
            "ThoughtRecorder",
            System.Windows.MessageBoxButton.OK,
            System.Windows.MessageBoxImage.Information);
    }

    private void TransitionTo(AppState newState, string reason)
    {
        Debug.WriteLine($"ThoughtRecorder state {state} -> {newState}: {reason}");
        state = newState;
        RefreshTrayState();
    }

    private AppState SteadyStateAfterCycle() => latestTranscript is null ? AppState.Idle : AppState.ReadyToPaste;

    private void RefreshTrayState()
    {
        trayIconController.Update(new TrayIconState(
            StateLabel: state.ToString(),
            HasTranscript: latestTranscript is not null,
            IsBusy: state is AppState.Recording or AppState.Processing or AppState.Pasting,
            IsLaunchAtLoginEnabled: launchAtLoginManager.IsEnabled));
    }

    private void Quit()
    {
        dispatcher.BeginInvoke(() => System.Windows.Application.Current.Shutdown());
    }

    public void Dispose()
    {
        if (disposed)
        {
            return;
        }

        disposed = true;
        hotKeyManager.Dispose();
        speechController.Dispose();
        trayIconController.Dispose();
        overlayWindow.Close();
    }
}
