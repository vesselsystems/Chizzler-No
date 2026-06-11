using System;

namespace ThoughtRecorder.Windows;

internal sealed class ThoughtRecorderApp : System.Windows.Application, IDisposable
{
    private RecorderApplicationController? controller;

    protected override void OnStartup(System.Windows.StartupEventArgs e)
    {
        base.OnStartup(e);

        ShutdownMode = System.Windows.ShutdownMode.OnExplicitShutdown;
        controller = new RecorderApplicationController(Dispatcher);
        controller.Start();
    }

    protected override void OnExit(System.Windows.ExitEventArgs e)
    {
        Dispose();
        base.OnExit(e);
    }

    public void Dispose()
    {
        controller?.Dispose();
        controller = null;
    }
}
