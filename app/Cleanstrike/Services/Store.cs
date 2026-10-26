using System.Text.Json;
using Cleanstrike.Models;

namespace Cleanstrike.Services;

/// <summary>App config and profiles under %APPDATA%\Cleanstrike.</summary>
public static class Store
{
    private static readonly JsonSerializerOptions Json = new() { WriteIndented = true };
    private static string ConfigPath => Path.Combine(Log.AppDataDir, "config.json");
    private static string ProfilesDir => Path.Combine(Log.AppDataDir, "profiles");

    public static AppConfig LoadConfig() => ReadJson<AppConfig>(ConfigPath) ?? new AppConfig();

    public static void SaveConfig(AppConfig c) => WriteJson(ConfigPath, c);

    public static List<string> ProfileNames()
    {
        Directory.CreateDirectory(ProfilesDir);
        var names = Directory.GetFiles(ProfilesDir, "*.json")
            .Select(f => ReadJson<Profile>(f)?.Name)
            .Where(n => !string.IsNullOrWhiteSpace(n))
            .Select(n => n!)
            .OrderBy(n => n, StringComparer.OrdinalIgnoreCase)
            .ToList();
        if (names.Count == 0)
        {
            SaveProfile(new Profile());
            names.Add("Default");
        }
        return names;
    }

    public static Profile LoadProfile(string name) =>
        ReadJson<Profile>(PathFor(name)) ?? new Profile { Name = name };

    public static void SaveProfile(Profile p) => WriteJson(PathFor(p.Name), p);

    public static void DeleteProfile(string name)
    {
        var path = PathFor(name);
        if (File.Exists(path)) File.Delete(path);
    }

    private static string PathFor(string name)
    {
        var safe = string.Concat(name.Select(c => Path.GetInvalidFileNameChars().Contains(c) ? '_' : c));
        return Path.Combine(ProfilesDir, safe + ".json");
    }

    /// <summary>
    /// Brings a profile in line with what's installed: drops entries whose
    /// file is gone and appends newly found mods (disabled unless asked).
    /// </summary>
    public static bool Reconcile(Profile p, IReadOnlyList<ModInfo> mods, bool enableNew)
    {
        bool changed = false;
        var byId = mods.GroupBy(m => m.Id, StringComparer.OrdinalIgnoreCase).ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);
        for (int i = p.Mods.Count - 1; i >= 0; i--)
        {
            if (byId.TryGetValue(p.Mods[i].Id, out var m))
            {
                if (p.Mods[i].File != m.FileName) { p.Mods[i].File = m.FileName; changed = true; }
            }
            else
            {
                p.Mods.RemoveAt(i);
                changed = true;
            }
        }
        foreach (var m in mods.OrderBy(m => m.Priority).ThenBy(m => m.Name, StringComparer.OrdinalIgnoreCase))
        {
            if (p.Mods.Any(e => string.Equals(e.Id, m.Id, StringComparison.OrdinalIgnoreCase))) continue;
            p.Mods.Add(new ProfileEntry { Id = m.Id, File = m.FileName, Enabled = enableNew && !m.OptIn });
            changed = true;
        }
        return changed;
    }

    public static T? ReadJson<T>(string path) where T : class
    {
        try
        {
            return File.Exists(path) ? JsonSerializer.Deserialize<T>(File.ReadAllText(path)) : null;
        }
        catch (Exception e)
        {
            Log.Write($"Could not read {path}: {e.Message}");
            return null;
        }
    }

    public static void WriteJson<T>(string path, T value)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var tmp = path + ".tmp";
        File.WriteAllText(tmp, JsonSerializer.Serialize(value, Json));
        File.Move(tmp, path, overwrite: true);
    }
}
