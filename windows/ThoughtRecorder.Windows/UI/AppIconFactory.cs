using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

namespace ThoughtRecorder.Windows.UI;

internal static class AppIconFactory
{
    public static Icon CreateTrayIcon()
    {
        using var bitmap = new Bitmap(64, 64);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        graphics.Clear(Color.Transparent);

        using var background = new SolidBrush(Color.FromArgb(17, 25, 29));
        graphics.FillRoundedRectangle(background, new Rectangle(2, 2, 60, 60), 14);

        using var ringPen = new Pen(Color.FromArgb(72, 40, 217, 194), 3);
        graphics.DrawEllipse(ringPen, 12, 12, 40, 40);

        using var micBrush = new SolidBrush(Color.FromArgb(238, 251, 245));
        graphics.FillRoundedRectangle(micBrush, new Rectangle(25, 15, 14, 28), 7);

        using var tealPen = new Pen(Color.FromArgb(57, 230, 202), 4)
        {
            StartCap = LineCap.Round,
            EndCap = LineCap.Round
        };
        graphics.DrawArc(tealPen, 18, 28, 28, 20, 20, 140);
        graphics.DrawLine(tealPen, 32, 45, 32, 52);
        graphics.DrawLine(tealPen, 25, 52, 39, 52);

        var handle = bitmap.GetHicon();
        try
        {
            return (Icon)Icon.FromHandle(handle).Clone();
        }
        finally
        {
            DestroyIcon(handle);
        }
    }

    private static void FillRoundedRectangle(this Graphics graphics, Brush brush, Rectangle bounds, int radius)
    {
        using var path = RoundedRectanglePath(bounds, radius);
        graphics.FillPath(brush, path);
    }

    private static GraphicsPath RoundedRectanglePath(Rectangle bounds, int radius)
    {
        var diameter = radius * 2;
        var path = new GraphicsPath();
        path.AddArc(bounds.Left, bounds.Top, diameter, diameter, 180, 90);
        path.AddArc(bounds.Right - diameter, bounds.Top, diameter, diameter, 270, 90);
        path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(bounds.Left, bounds.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyIcon(nint handle);
}
