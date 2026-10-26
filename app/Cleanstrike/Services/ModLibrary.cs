using System.IO.Compression;
using System.Text.Json;
using Cleanstrike.Models;

namespace Cleanstrike.Services;

/// <summary>Reads, installs and removes mod archives in &lt;game&gt;/Cleanstrike/mods.</summary>
public static class ModLibrary
{
    public static readonly string[] Extensions = { ".csmod", ".vmz", ".zip", ".pck" };
    public const string SettingsFile = "cleanstrike.settings.json";
    public static readonly string[] ThumbnailNames = { "icon.png", "icon.jpg", "thumbnail.png", "thumbnail.jpg" };

    // Installs the mods bundled in the app. Each bundled version is installed
    // once: if the player removes a mod, it stays removed until a newer
    // version ships with Cleanstrike.
    public static void InstallBundled(GameInstall game)
    {
        var asm = System.Reflection.Assembly.GetExecutingAssembly();
        var seenPath = Path.Combine(Log.AppDataDir, "bundled.txt");
        var seen = File.Exists(seenPath) ? File.ReadAllLines(seenPath).ToHashSet() : new HashSet<string>();
        bool changed = false;
        foreach (var name in asm.GetManifestResourceNames().Where(n => n.StartsWith("bundled/")))
        {
            var tmp = Path.Combine(Path.GetTempPath(), "cleanstrike-bundled-" + Path.GetFileName(name));
            try
            {
                using (var src = asm.GetManifestResourceStream(name)!)
                using (var dst = File.Create(tmp)) src.CopyTo(dst);
                var info = Read(tmp);
                var key = info.Id + "@" + info.Version;
                if (seen.Contains(key)) continue;
                var installed = Scan(game);
                var current = installed.FirstOrDefault(m => m.Id == info.Id);
                if (current == null || CompareVersions(current.Version, info.Version) < 0)
                {
                    Install(game, tmp, installed);
                    Log.Write($"Installed bundled {key}");
                }
                seen.Add(key); changed = true;
            }
            catch (Exception ex) { Log.Write($"Bundled {name} failed: {ex.Message}"); }
            finally { try { File.Delete(tmp); } catch { } }
        }
        if (changed) File.WriteAllLines(seenPath, seen);
    }

    public static List<ModInfo> Scan(GameInstall game)
    {
        var list = new List<ModInfo>();
        if (!Directory.Exists(game.ModsDir)) return list;
        foreach (var f in Directory.GetFiles(game.ModsDir))
        {
            if (!Extensions.Contains(Path.GetExtension(f).ToLowerInvariant())) continue;
            try { list.Add(Read(f)); }
            catch (Exception e) { Log.Write($"Skipping unreadable mod {f}: {e.Message}"); }
        }
        return list;
    }

    public static ModInfo Read(string path)
    {
        var info = new ModInfo
        {
            FileName = Path.GetFileName(path),
            FullPath = path,
            Id = Path.GetFileNameWithoutExtension(path),
            Name = Path.GetFileNameWithoutExtension(path),
            SizeBytes = new FileInfo(path).Length,
        };
        if (Path.GetExtension(path).Equals(".pck", StringComparison.OrdinalIgnoreCase))
        {
            info.Description = "Resource pack (no manifest).";
            return info;
        }
        using var zip = ZipFile.OpenRead(path);
        var manifest = zip.GetEntry("mod.txt");
        if (manifest != null)
        {
            using var r = new StreamReader(manifest.Open());
            ApplyManifest(info, GodotConfig.Parse(r.ReadToEnd()));
        }
        var icon = ThumbnailNames.Select(zip.GetEntry).FirstOrDefault(e => e != null && e.Length is > 0 and < 4_000_000);
        if (icon != null)
        {
            using var ms = new MemoryStream();
            using (var s = icon.Open()) s.CopyTo(ms);
            info.Thumbnail = ms.ToArray();
        }
        var schema = zip.GetEntry(SettingsFile);
        if (schema != null)
        {
            using var s = schema.Open();
            info.Settings = ParseSettings(s);
        }
        return info;
    }

    private static void ApplyManifest(ModInfo info, GodotConfig cfg)
    {
        info.HasManifest = true;
        info.Id = cfg.GetString("mod", "id", info.Id);
        info.Name = cfg.GetString("mod", "name", info.Id);
        info.Version = cfg.GetString("mod", "version");
        info.Author = cfg.GetString("mod", "author");
        info.Description = cfg.GetString("mod", "description");
        info.Priority = cfg.GetInt("mod", "priority");
        info.Api = cfg.GetInt("cleanstrike", "api", 1);
        info.GameMin = cfg.GetString("cleanstrike", "game_min");
        info.GameMax = cfg.GetString("cleanstrike", "game_max");
        info.Tags = cfg.GetList("cleanstrike", "tags");
        info.Premium = cfg.GetBool("cleanstrike", "premium");
        info.OptIn = cfg.GetBool("cleanstrike", "opt_in");
        info.Incompatible = cfg.Entries("incompatible")
            .GroupBy(e => e.Key).ToDictionary(g => g.Key, g => Convert.ToString(g.First().Value, System.Globalization.CultureInfo.InvariantCulture) ?? "");
        info.Requires = cfg.GetList("dependencies", "required");
        info.Supersedes = cfg.Entries("supersedes")
            .GroupBy(e => e.Key).ToDictionary(g => g.Key, g => Convert.ToString(g.First().Value, System.Globalization.CultureInfo.InvariantCulture) ?? "");
        info.Autoloads = cfg.Entries("autoload")
            .Select(e => new KeyValuePair<string, string>(e.Key, Convert.ToString(e.Value) ?? ""))
            .Where(e => e.Value.Length > 0).ToList();
    }

    private static List<SettingDef> ParseSettings(Stream s)
    {
        var result = new List<SettingDef>();
        using var doc = JsonDocument.Parse(s);
        if (!doc.RootElement.TryGetProperty("settings", out var arr) || arr.ValueKind != JsonValueKind.Array) return result;
        foreach (var e in arr.EnumerateArray())
        {
            var d = new SettingDef
            {
                Key = Str(e, "key"),
                Type = Str(e, "type", "bool"),
                Label = Str(e, "label"),
                Description = Str(e, "description"),
                Min = Num(e, "min", 0),
                Max = Num(e, "max", 1),
                Step = Num(e, "step", 0.1),
            };
            if (d.Key.Length == 0) continue;
            if (d.Label.Length == 0) d.Label = d.Key;
            if (e.TryGetProperty("options", out var opts) && opts.ValueKind == JsonValueKind.Array)
                d.Options = opts.EnumerateArray().Select(o => o.ToString()).ToList();
            if (e.TryGetProperty("default", out var def))
                d.Default = def.ValueKind switch
                {
                    JsonValueKind.True => true,
                    JsonValueKind.False => false,
                    JsonValueKind.Number => def.GetDouble(),
                    _ => def.ToString(),
                };
            result.Add(d);
        }
        return result;
    }

    private static string Str(JsonElement e, string k, string fallback = "") =>
        e.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() ?? fallback : fallback;

    private static double Num(JsonElement e, string k, double fallback) =>
        e.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.Number ? v.GetDouble() : fallback;

    public sealed record InstallResult(ModInfo Mod, ModInfo? Replaced, bool Repaired);

    /// <summary>
    /// Copies a mod archive into the library. Fixes the most common packaging
    /// mistake (mod.txt one folder down) and backslash paths by repacking.
    /// Replaces an installed mod with the same id.
    /// </summary>
    public static InstallResult Install(GameInstall game, string source, IEnumerable<ModInfo> installed)
    {
        Directory.CreateDirectory(game.ModsDir);
        var ext = Path.GetExtension(source).ToLowerInvariant();
        if (!Extensions.Contains(ext))
            throw new UserFacingException($"\"{Path.GetFileName(source)}\" isn't a mod file. Cleanstrike installs .csmod, .vmz, .zip and .pck files.");

        string staged = Path.Combine(Path.GetTempPath(), "cleanstrike-" + Guid.NewGuid().ToString("N") + ext);
        bool repaired = false;
        try
        {
            if (ext == ".pck") File.Copy(source, staged);
            else repaired = Normalize(source, staged);

            var mod = Read(staged);
            if (ext != ".pck" && !mod.HasManifest)
                throw new UserFacingException($"\"{Path.GetFileName(source)}\" has no mod.txt, so it isn't a mod Cleanstrike can load.");

            var replaced = installed.FirstOrDefault(m => string.Equals(m.Id, mod.Id, StringComparison.OrdinalIgnoreCase));
            var targetName = SafeFileName(mod.Id) + (ext == ".pck" ? ".pck" : ".csmod");
            var target = Path.Combine(game.ModsDir, targetName);
            if (replaced != null && !string.Equals(replaced.FullPath, target, StringComparison.OrdinalIgnoreCase))
                File.Delete(replaced.FullPath);
            File.Copy(staged, target, overwrite: true);
            var final = Read(target);
            Log.Write($"Installed {final.Id} {final.Version} from {source}{(repaired ? " (repacked)" : "")}");
            return new InstallResult(final, replaced, repaired);
        }
        catch (InvalidDataException)
        {
            throw new UserFacingException($"\"{Path.GetFileName(source)}\" is damaged or isn't a zip archive.");
        }
        finally
        {
            try { File.Delete(staged); } catch { }
        }
    }

    // Returns true if the archive had to be rewritten.
    private static bool Normalize(string source, string dest)
    {
        using (var zip = ZipFile.OpenRead(source))
        {
            bool rootManifest = zip.GetEntry("mod.txt") != null;
            bool clean = zip.Entries.All(e => !e.FullName.Contains('\\'));
            if (rootManifest && clean)
            {
                zip.Dispose();
                File.Copy(source, dest);
                return false;
            }
            // Look for mod.txt exactly one folder down.
            var nested = zip.Entries.FirstOrDefault(e =>
            {
                var n = e.FullName.Replace('\\', '/');
                return n.EndsWith("/mod.txt", StringComparison.OrdinalIgnoreCase) && n.Count(c => c == '/') == 1;
            });
            string prefix = rootManifest || nested == null ? "" : nested.FullName.Replace('\\', '/')[..^"mod.txt".Length];
            using var outFs = File.Create(dest);
            using var outZip = new ZipArchive(outFs, ZipArchiveMode.Create);
            foreach (var e in zip.Entries)
            {
                var name = e.FullName.Replace('\\', '/');
                if (prefix.Length > 0)
                {
                    if (!name.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) continue;
                    name = name[prefix.Length..];
                }
                if (name.Length == 0 || name.EndsWith('/')) continue;
                var ne = outZip.CreateEntry(name, CompressionLevel.Optimal);
                using var src = e.Open();
                using var dst = ne.Open();
                src.CopyTo(dst);
            }
        }
        return true;
    }

    public static void Remove(GameInstall game, ModInfo mod)
    {
        if (File.Exists(mod.FullPath)) File.Delete(mod.FullPath);
        var settings = Path.Combine(game.SettingsDir, mod.Id + ".json");
        if (File.Exists(settings)) File.Delete(settings);
        Log.Write("Removed " + mod.Id);
    }

    private static string SafeFileName(string s)
    {
        foreach (var c in Path.GetInvalidFileNameChars()) s = s.Replace(c, '_');
        return s.Length == 0 ? "mod" : s;
    }

    // ---------------------------------------------------------- settings values

    public static Dictionary<string, object?> LoadSettings(GameInstall game, ModInfo mod)
    {
        var values = mod.Settings.ToDictionary(s => s.Key, s => s.Default);
        var path = Path.Combine(game.SettingsDir, mod.Id + ".json");
        if (!File.Exists(path)) return values;
        try
        {
            using var doc = JsonDocument.Parse(File.ReadAllText(path));
            foreach (var p in doc.RootElement.EnumerateObject())
                values[p.Name] = p.Value.ValueKind switch
                {
                    JsonValueKind.True => true,
                    JsonValueKind.False => false,
                    JsonValueKind.Number => p.Value.GetDouble(),
                    _ => p.Value.ToString(),
                };
        }
        catch (Exception e) { Log.Write($"Bad settings file for {mod.Id}: {e.Message}"); }
        return values;
    }

    public static void SaveSettings(GameInstall game, ModInfo mod, Dictionary<string, object?> values)
    {
        Directory.CreateDirectory(game.SettingsDir);
        File.WriteAllText(Path.Combine(game.SettingsDir, mod.Id + ".json"),
            JsonSerializer.Serialize(values, new JsonSerializerOptions { WriteIndented = true }));
    }

    // ---------------------------------------------------------- compatibility

    /// <summary>Null when the mod should work on this game version, otherwise why not.</summary>
    public static string? CompatibilityProblem(ModInfo mod, GameInstall game, int loaderApi)
    {
        if (mod.Api > loaderApi) return "Needs a newer version of Cleanstrike.";
        if (game.GameVersion == "unknown") return null;
        if (mod.GameMin.Length > 0 && CompareVersions(game.GameVersion, mod.GameMin) < 0)
            return $"Needs game version {mod.GameMin} or newer.";
        if (mod.GameMax.Length > 0 && CompareVersions(game.GameVersion, mod.GameMax) > 0)
            return $"Made for game versions up to {mod.GameMax}.";
        return null;
    }

    public static int CompareVersions(string a, string b)
    {
        var pa = a.Split('.');
        var pb = b.Split('.');
        for (int i = 0; i < Math.Max(pa.Length, pb.Length); i++)
        {
            int x = i < pa.Length && int.TryParse(pa[i], out var xi) ? xi : 0;
            int y = i < pb.Length && int.TryParse(pb[i], out var yi) ? yi : 0;
            if (x != y) return x < y ? -1 : 1;
        }
        return 0;
    }
}

/// <summary>An error whose message is written for the player.</summary>
public sealed class UserFacingException(string message) : Exception(message);
