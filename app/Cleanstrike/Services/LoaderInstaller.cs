using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using Cleanstrike.Models;

namespace Cleanstrike.Services;

/// <summary>
/// Puts the Cleanstrike in-game loader into the game folder and manages
/// override.cfg, the Godot file that tells the game to run it first.
/// Anything that was in override.cfg before is backed up and restored on removal.
/// </summary>
public static class LoaderInstaller
{
    public const int ApiVersion = 1;
    private const string Marker = "; Managed by Cleanstrike";

    public enum State { NotInstalled, Installed, Outdated }

    public static string BundledLoader { get; } = ReadBundled();
    public static string BundledVersion { get; } = VersionOf(BundledLoader) ?? "0";

    private static string LoaderPath(GameInstall g) => Path.Combine(g.CleanstrikeDir, "loader.gd");
    private static string BackupPath(GameInstall g) => Path.Combine(g.CleanstrikeDir, "backup", "override.cfg");

    public static State GetState(GameInstall g)
    {
        if (!File.Exists(LoaderPath(g)) || !IsOurs(g)) return State.NotInstalled;
        var v = VersionOf(File.ReadAllText(LoaderPath(g)));
        return v == BundledVersion ? State.Installed : State.Outdated;
    }

    /// <summary>The name of another mod loader currently wired into override.cfg, if any.</summary>
    public static string? ForeignLoader(GameInstall g)
    {
        if (!File.Exists(g.OverrideCfg) || IsOurs(g)) return null;
        var text = File.ReadAllText(g.OverrideCfg);
        if (text.Contains("modloader.gd", StringComparison.OrdinalIgnoreCase)) return "Metro Mod Loader";
        if (Regex.IsMatch(text, @"^\s*\[autoload", RegexOptions.Multiline)) return "another mod loader";
        return null;
    }

    private static bool IsOurs(GameInstall g) =>
        File.Exists(g.OverrideCfg) && File.ReadAllText(g.OverrideCfg).StartsWith(Marker);

    /// <summary>
    /// Writes the loader and override.cfg. Mod autoloads go into [autoload]
    /// so Godot creates them right after the game's own singletons.
    /// </summary>
    public static void Apply(GameInstall g, IEnumerable<KeyValuePair<string, string>> autoloads)
    {
        Directory.CreateDirectory(g.CleanstrikeDir);
        Directory.CreateDirectory(g.ModsDir);
        if (File.Exists(g.OverrideCfg) && !IsOurs(g) && !File.Exists(BackupPath(g)))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(BackupPath(g))!);
            File.Copy(g.OverrideCfg, BackupPath(g));
            Log.Write("Backed up existing override.cfg");
        }
        File.WriteAllText(LoaderPath(g), BundledLoader);

        var sb = new StringBuilder();
        sb.AppendLine(Marker + " (" + BundledVersion + "). It is rewritten every time you press Play.");
        sb.AppendLine("; Remove Cleanstrike from the game in the app to restore the original file.");
        sb.AppendLine();
        sb.AppendLine("[autoload_prepend]");
        sb.AppendLine("Cleanstrike=\"*res://Cleanstrike/loader.gd\"");
        sb.AppendLine();
        sb.AppendLine("[autoload]");
        var seen = new HashSet<string>();
        foreach (var (name, path) in autoloads)
        {
            if (!Regex.IsMatch(name, @"^[A-Za-z_][A-Za-z0-9_]*$") || !seen.Add(name)) continue;
            var p = path.TrimStart('!', '*');
            sb.AppendLine($"{name}={GodotConfig.Quote("*" + p)}");
        }
        foreach (var extra in ForeignSettings(g))
        {
            sb.AppendLine();
            sb.Append(extra);
        }
        File.WriteAllText(g.OverrideCfg, sb.ToString());
    }

    /// <summary>Takes Cleanstrike out of the game and restores the old override.cfg.</summary>
    public static void Uninstall(GameInstall g)
    {
        if (IsOurs(g)) File.Delete(g.OverrideCfg);
        if (File.Exists(BackupPath(g)))
        {
            File.Copy(BackupPath(g), g.OverrideCfg, overwrite: true);
            File.Delete(BackupPath(g));
        }
        if (File.Exists(LoaderPath(g))) File.Delete(LoaderPath(g));
        Log.Write("Removed Cleanstrike from " + g.Folder);
    }

    // Non-autoload sections of a backed-up override.cfg (player tweaks) are kept.
    // A backed-up mod loader config is not merged back in.
    private static IEnumerable<string> ForeignSettings(GameInstall g)
    {
        var path = BackupPath(g);
        if (!File.Exists(path)) yield break;
        var text = File.ReadAllText(path);
        if (text.Contains("modloader.gd", StringComparison.OrdinalIgnoreCase)) yield break;
        var current = new StringBuilder();
        string? section = null;
        foreach (var line in text.Replace("\r", "").Split('\n'))
        {
            var t = line.Trim();
            if (t.StartsWith('[') && t.EndsWith(']'))
            {
                if (section != null && !section.StartsWith("autoload")) yield return current.ToString();
                section = t[1..^1];
                current.Clear();
            }
            current.AppendLine(line);
        }
        if (section != null && !section.StartsWith("autoload")) yield return current.ToString();
    }

    private static string ReadBundled()
    {
        using var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("cleanstrike_loader.gd")
            ?? throw new InvalidOperationException("Bundled loader missing from the build.");
        using var r = new StreamReader(s);
        return r.ReadToEnd().Replace("\r\n", "\n");
    }

    private static string? VersionOf(string loaderSource)
    {
        var m = Regex.Match(loaderSource, @"cleanstrike-loader-version:\s*([0-9.]+)");
        return m.Success ? m.Groups[1].Value : null;
    }
}
