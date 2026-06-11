using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using MediaBrushes = System.Windows.Media.Brushes;
using MediaColor = System.Windows.Media.Color;

namespace ThoughtRecorder.Windows.UI;

internal enum StatusDuration
{
    Short,
    Error,
    LongRunning
}

internal sealed class OverlayWindow : Window
{
    private readonly TextBlock label = new();
    private readonly DispatcherTimer hideTimer = new();

    public OverlayWindow()
    {
        Width = 300;
        Height = 58;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = MediaBrushes.Transparent;
        ShowInTaskbar = false;
        Topmost = true;
        ResizeMode = ResizeMode.NoResize;
        IsHitTestVisible = false;
        Focusable = false;

        label.Foreground = MediaBrushes.White;
        label.FontSize = 16;
        label.FontWeight = FontWeights.SemiBold;
        label.HorizontalAlignment = System.Windows.HorizontalAlignment.Center;
        label.VerticalAlignment = System.Windows.VerticalAlignment.Center;
        label.TextAlignment = TextAlignment.Center;
        label.TextTrimming = TextTrimming.CharacterEllipsis;
        label.Margin = new Thickness(16, 0, 16, 0);

        Content = new Border
        {
            Background = new SolidColorBrush(MediaColor.FromArgb(218, 0, 0, 0)),
            CornerRadius = new CornerRadius(14),
            Child = label
        };

        hideTimer.Tick += (_, _) =>
        {
            hideTimer.Stop();
            Hide();
        };
    }

    public void ShowStatus(string message, StatusDuration duration)
    {
        hideTimer.Stop();
        label.Text = message;
        PositionNearTopCenter();
        Show();

        hideTimer.Interval = duration switch
        {
            StatusDuration.LongRunning => TimeSpan.FromSeconds(60),
            StatusDuration.Error => TimeSpan.FromSeconds(1.8),
            _ => TimeSpan.FromSeconds(1.1)
        };
        hideTimer.Start();
    }

    private void PositionNearTopCenter()
    {
        var workArea = SystemParameters.WorkArea;
        Left = workArea.Left + (workArea.Width - Width) / 2;
        Top = workArea.Top + 44;
    }
}
