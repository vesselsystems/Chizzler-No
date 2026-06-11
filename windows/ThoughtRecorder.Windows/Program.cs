using System;

namespace ThoughtRecorder.Windows;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        using var app = new ThoughtRecorderApp();
        app.Run();
    }
}
