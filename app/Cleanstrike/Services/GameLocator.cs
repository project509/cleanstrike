using System.Text.RegularExpressions;
using Cleanstrike.Models;
using Microsoft.Win32;

namespace Cleanstrike.Services;

/// <summary>Finds Road to Vostok on this PC and validates a chosen folder.</summary>
public static class GameLocator
{
    public const string SteamAppId = "1963610";
    private const string FolderName = "Road to Vostok";
    private static readonly string[] KnownExeNames = { "RTV.exe", "RoadToVostok.exe", "Road to Vostok.exe" };

    public static GameInstall? AutoDetect()
    {
        if (Environment.GetEnvironmentVariable("CLEANSTRIKE_NO_AUTODETECT") == "1") return null; // tests
        foreach (var folder in CandidateFolders())
        {
            var g = TryValidate(folder);
            if (g != null)
            {
                Log.Write("Detected game at " + g.Folder);
                return g;
            }
        }
        Log.Write("Game not found automatically.");
        return null;
    }

    /// <summary>
    /// Accepts the game folder, its parent, or the exe itself. Returns null
    /// when no Godot game executable with its pack is found there.
    /// </summary>
    public static GameInstall? TryValidate(string? path)
    {
        if (string.IsNullOrWhiteSpace(path)) return null;
        try
        {
            if (File.Exists(path)) path = Path.GetDirectoryName(path)!;
            if (!Directory.Exists(path)) return null;
            var g = Validate(path);
            if (g != null) return g;
            var child = Path.Combine(path, FolderName);
            if (Directory.Exists(child)) return Validate(child);
            var steamChild = Path.Combine(path, "steamapps", "common", FolderName);
            if (Directory.Exists(steamChild)) return Validate(steamChild);
        }
        catch (Exception e)
        {
            Log.Write("Validate failed for " + path + ": " + e.Message);
        }
        return null;
    }

    private static GameInstall? Validate(string folder)
    {
        // Prefer an exe whose sibling .pck is a Godot pack (largest pack wins).
        var packs = Directory.GetFiles(folder, "*.pck")
            .Select(p => new FileInfo(p))
            .OrderByDescending(f => f.Length);
        foreach (var pck in packs)
        {
            var exe = Path.ChangeExtension(pck.FullName, ".exe");
            if (!File.Exists(exe)) continue;
            var info = PckReader.Read(pck.FullName);
            if (info == null) continue;
            var name = info.Settings.GetValueOrDefault("application/config/name", "");
            if (name.Length > 0 && !name.Contains("Vostok", StringComparison.OrdinalIgnoreCase)) continue;
            var g = new GameInstall
            {
                Folder = Path.GetFullPath(folder),
                ExePath = exe,
                PckPath = pck.FullName,
                IsSteam = IsSteamPath(folder),
                GodotVersion = info.GodotVersion,
            };
            if (info.Settings.TryGetValue("application/config/version", out var v)) g.GameVersion = v;
            if (info.Settings.TryGetValue("application/config/custom_user_dir_name", out var u) && u.Length > 0) g.UserDirName = u;
            return g;
        }
        // Packs embedded in the exe: accept a known exe name.
        foreach (var n in KnownExeNames)
        {
            var exe = Path.Combine(folder, n);
            if (File.Exists(exe))
                return new GameInstall { Folder = Path.GetFullPath(folder), ExePath = exe, IsSteam = IsSteamPath(folder) };
        }
        return null;
    }

    private static bool IsSteamPath(string folder) =>
        folder.Replace('/', '\\').Contains(@"\steamapps\common\", StringComparison.OrdinalIgnoreCase);

    public static IEnumerable<string> CandidateFolders()
    {
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var lib in SteamLibraries())
        {
            var manifest = Path.Combine(lib, "steamapps", $"appmanifest_{SteamAppId}.acf");
            if (File.Exists(manifest))
            {
                var m = Regex.Match(File.ReadAllText(manifest), "\"installdir\"\\s+\"([^\"]+)\"");
                if (m.Success && seen.Add(Path.Combine(lib, "steamapps", "common", m.Groups[1].Value)))
                    yield return Path.Combine(lib, "steamapps", "common", m.Groups[1].Value);
            }
            var guess = Path.Combine(lib, "steamapps", "common", FolderName);
            if (seen.Add(guess)) yield return guess;
        }
        foreach (var drive in SafeDrives())
        {
            foreach (var rel in new[] {
                @"SteamLibrary\steamapps\common\" + FolderName,
                @"Steam\steamapps\common\" + FolderName,
                @"Program Files (x86)\Steam\steamapps\common\" + FolderName,
                @"Program Files\Steam\steamapps\common\" + FolderName,
                @"Games\Steam\steamapps\common\" + FolderName,
                @"Games\SteamLibrary\steamapps\common\" + FolderName,
                @"Games\" + FolderName,
                FolderName,
            })
            {
                var p = Path.Combine(drive, rel);
                if (seen.Add(p)) yield return p;
            }
        }
    }

    private static IEnumerable<string> SafeDrives()
    {
        DriveInfo[] drives;
        try { drives = DriveInfo.GetDrives(); } catch { yield break; }
        foreach (var d in drives)
        {
            bool ok;
            try { ok = d.IsReady && d.DriveType is DriveType.Fixed or DriveType.Removable; } catch { ok = false; }
            if (ok) yield return d.RootDirectory.FullName;
        }
    }

    public static string? SteamRoot()
    {
        foreach (var (hive, key, value) in new[] {
            (Registry.CurrentUser, @"Software\Valve\Steam", "SteamPath"),
            (Registry.LocalMachine, @"SOFTWARE\WOW6432Node\Valve\Steam", "InstallPath"),
            (Registry.LocalMachine, @"SOFTWARE\Valve\Steam", "InstallPath"),
        })
        {
            try
            {
                if (hive.OpenSubKey(key)?.GetValue(value) is string s && Directory.Exists(s))
                    return Path.GetFullPath(s);
            }
            catch { /* registry may be locked down */ }
        }
        return null;
    }

    public static IEnumerable<string> SteamLibraries()
    {
        var root = SteamRoot();
        if (root == null) yield break;
        yield return root;
        var vdf = Path.Combine(root, "steamapps", "libraryfolders.vdf");
        if (!File.Exists(vdf)) yield break;
        string text;
        try { text = File.ReadAllText(vdf); } catch { yield break; }
        foreach (Match m in Regex.Matches(text, "\"path\"\\s+\"([^\"]+)\""))
        {
            var p = m.Groups[1].Value.Replace(@"\\", @"\");
            if (Directory.Exists(p) && !string.Equals(Path.GetFullPath(p), root, StringComparison.OrdinalIgnoreCase))
                yield return p;
        }
    }

    public static bool IsSteamRunning() =>
        System.Diagnostics.Process.GetProcessesByName("steam").Length > 0;
}
