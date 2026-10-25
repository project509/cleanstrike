namespace Cleanstrike.Services;

/// <summary>App data locations and a small rolling log.</summary>
public static class Log
{
    // CLEANSTRIKE_HOME lets tests run with their own config and profiles.
    public static string AppDataDir { get; } = Environment.GetEnvironmentVariable("CLEANSTRIKE_HOME") is { Length: > 0 } home
        ? home
        : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Cleanstrike");

    public static string LogPath => Path.Combine(AppDataDir, "cleanstrike-app.log");

    private static readonly object Gate = new();

    public static void Write(string text)
    {
        try
        {
            lock (Gate)
            {
                Directory.CreateDirectory(AppDataDir);
                var fi = new FileInfo(LogPath);
                if (fi.Exists && fi.Length > 1_000_000) fi.Delete();
                File.AppendAllText(LogPath, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss}  {text}{Environment.NewLine}");
            }
        }
        catch { /* logging must never crash the app */ }
    }
}
