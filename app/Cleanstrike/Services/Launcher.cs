using System.Diagnostics;
using System.Text.Json;
using Cleanstrike.Models;

namespace Cleanstrike.Services;

/// <summary>Writes the launch plan for the in-game loader and starts the game.</summary>
public static class Launcher
{
    public static bool IsRunning(GameInstall g) =>
        Process.GetProcessesByName(g.ProcessName).Length > 0;

    /// <summary>
    /// Writes Cleanstrike/active.json (load order) and override.cfg, then
    /// starts the game. Returns the time the launch was requested.
    /// </summary>
    public static DateTime Launch(GameInstall g, IReadOnlyList<(ModInfo Mod, bool Enabled)> order, bool vanilla, bool viaSteam)
    {
        var count = Prepare(g, order, vanilla);
        return Start(g, viaSteam, vanilla ? "vanilla" : count + " mods");
    }

    /// <summary>Writes loader, override.cfg and active.json. Returns how many mods will load.</summary>
    public static int Prepare(GameInstall g, IReadOnlyList<(ModInfo Mod, bool Enabled)> order, bool vanilla)
    {
        var enabled = vanilla ? new List<ModInfo>() :
            order.Where(o => o.Enabled && ModLibrary.CompatibilityProblem(o.Mod, g, LoaderInstaller.ApiVersion) == null)
                 .Select(o => o.Mod).ToList();

        LoaderInstaller.Apply(g, enabled.SelectMany(m => m.Autoloads));

        var plan = new
        {
            schema = 1,
            vanilla,
            written_by = "Cleanstrike " + typeof(Launcher).Assembly.GetName().Version?.ToString(3),
            mods = order.Select(o => new { id = o.Mod.Id, file = o.Mod.FileName, enabled = o.Enabled && !vanilla }),
        };
        File.WriteAllText(Path.Combine(g.CleanstrikeDir, "active.json"),
            JsonSerializer.Serialize(plan, new JsonSerializerOptions { WriteIndented = true }));
        return enabled.Count;
    }

    public static DateTime Start(GameInstall g, bool viaSteam, string what)
    {
        var started = DateTime.Now;
        if (viaSteam && g.IsSteam)
        {
            Process.Start(new ProcessStartInfo("steam://rungameid/" + GameLocator.SteamAppId) { UseShellExecute = true });
        }
        else
        {
            Process.Start(new ProcessStartInfo(g.ExePath) { WorkingDirectory = g.Folder, UseShellExecute = true });
        }
        Log.Write($"Launched ({what}, {(viaSteam && g.IsSteam ? "Steam" : "direct")})");
        return started;
    }

    public static LaunchReport? ReadReport(GameInstall g, DateTime? newerThan = null)
    {
        try
        {
            if (!File.Exists(g.ReportPath)) return null;
            if (newerThan is { } t && File.GetLastWriteTime(g.ReportPath) < t) return null;
            return JsonSerializer.Deserialize<LaunchReport>(File.ReadAllText(g.ReportPath));
        }
        catch (IOException) { return null; }  // game still writing it
        catch (JsonException) { return null; }
    }
}
