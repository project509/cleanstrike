namespace Cleanstrike.Services;

/// <summary>
/// Cleanstrike.exe [mod files] --silent: installs the bundled mods and any
/// given mod files into the game without showing a window, then exits.
/// Used by development tooling so nothing pops up on the desktop.
/// Exit code: 0 ok, 1 some files failed, 2 game not found.
/// </summary>
public static class SilentInstall
{
    public static int Run(string[] args)
    {
        var config = Store.LoadConfig();
        var game = GameLocator.TryValidate(config.GamePath) ?? GameLocator.AutoDetect();
        if (game == null)
        {
            Log.Write("Silent install: Road to Vostok not found.");
            return 2;
        }
        ModLibrary.InstallBundled(game);

        var files = args.Where(a => !a.StartsWith("--") && File.Exists(a)
            && ModLibrary.Extensions.Contains(Path.GetExtension(a).ToLowerInvariant())).ToList();
        var installed = ModLibrary.Scan(game);
        var fresh = new List<string>();
        int failures = 0;
        foreach (var file in files)
        {
            try
            {
                var r = ModLibrary.Install(game, file, installed);
                installed.RemoveAll(m => m.Id == r.Mod.Id);
                installed.Add(r.Mod);
                if (r.Replaced == null) fresh.Add(r.Mod.Id);
                Log.Write($"Silent install: {r.Mod.Id} {r.Mod.Version}");
            }
            catch (Exception e)
            {
                failures++;
                Log.Write($"Silent install failed for {file}: {e.Message}");
            }
        }

        // Same rule as the app: new mods are on in the active profile, off elsewhere.
        foreach (var name in Store.ProfileNames())
        {
            var p = Store.LoadProfile(name);
            bool changed = Store.Reconcile(p, installed, enableNew: false);
            if (name == config.ActiveProfile)
                foreach (var e in p.Mods.Where(m => fresh.Contains(m.Id) && !m.Enabled))
                {
                    e.Enabled = true;
                    changed = true;
                }
            if (name == config.ActiveProfile)
            {
                // Same as the app: a mod that can't run with one already on stays off.
                var on = p.Mods.Where(m => m.Enabled).Select(m => installed.FirstOrDefault(i => i.Id == m.Id)).OfType<Cleanstrike.Models.ModInfo>().ToList();
                foreach (var fix in ModRules.PlanLaunch(on, installed))
                {
                    var e = p.Mods.First(m => m.Id == fix.Mod.Id);
                    if (fresh.Contains(e.Id))
                    {
                        e.Enabled = false;
                        changed = true;
                        Log.Write($"Silent install: {fix.Mod.Name} left off ({fix.Reason})");
                    }
                }
            }
            if (changed) Store.SaveProfile(p);
        }
        return failures == 0 ? 0 : 1;
    }
}
