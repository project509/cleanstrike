using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace Cleanstrike;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        DispatcherUnhandledException += OnUnhandled;
        base.OnStartup(e);
        var window = new Views.MainWindow();
        MainWindow = window;

        // Dev aid: Cleanstrike.exe --screenshot out.png [--delay 3]
        // renders the window off-screen to a PNG and exits.
        var args = e.Args;
        int shot = Array.IndexOf(args, "--screenshot");
        if (shot >= 0 && shot + 1 < args.Length)
        {
            double delay = 3;
            int d = Array.IndexOf(args, "--delay");
            if (d >= 0 && d + 1 < args.Length) double.TryParse(args[d + 1], System.Globalization.CultureInfo.InvariantCulture, out delay);
            window.WindowStartupLocation = WindowStartupLocation.Manual;
            window.Left = -30000;
            window.ShowActivated = false;
            window.ShowInTaskbar = false;
            window.Show();
            var t = new DispatcherTimer { Interval = TimeSpan.FromSeconds(delay) };
            t.Tick += (_, _) =>
            {
                t.Stop();
                var root = (FrameworkElement)window.Content;
                var scale = 1.5;
                var bmp = new RenderTargetBitmap((int)(root.ActualWidth * scale), (int)(root.ActualHeight * scale), 96 * scale, 96 * scale, PixelFormats.Pbgra32);
                var bg = new DrawingVisual();
                using (var dc = bg.RenderOpen()) dc.DrawRectangle((Brush)FindResource("Bg"), null, new Rect(0, 0, root.ActualWidth, root.ActualHeight));
                bmp.Render(bg);
                bmp.Render(root);
                var enc = new PngBitmapEncoder();
                enc.Frames.Add(BitmapFrame.Create(bmp));
                using (var f = File.Create(args[shot + 1])) enc.Save(f);
                Shutdown();
            };
            t.Start();
            return;
        }
        window.Show();

        var files = args.Where(a => !a.StartsWith("--") && File.Exists(a)
            && Services.ModLibrary.Extensions.Contains(Path.GetExtension(a).ToLowerInvariant())).ToList();
        if (files.Count > 0 || args.Contains("--play"))
            ((ViewModels.MainViewModel)window.DataContext).QueueStartupRequests(files, args.Contains("--play"));
    }

    private static void OnUnhandled(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        Services.Log.Write("Unhandled: " + e.Exception);
        Views.Dialog.Show(Current.MainWindow, "Something went wrong",
            e.Exception.Message + "\n\nDetails were saved to the Cleanstrike log.", "OK");
        e.Handled = true;
    }
}
