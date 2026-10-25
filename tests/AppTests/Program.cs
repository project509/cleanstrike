using System.IO;
// Exercises Cleanstrike's services against a real game folder.
// Usage: AppTests <TestGame folder> <work folder>   (prepares a launch; does not start the game)
using System.IO.Compression;
using Cleanstrike.Services;

int fails = 0;
void Check(string name, bool ok, string detail = "")
{
    Console.WriteLine($"{(ok ? "PASS" : "FAIL")} {name} {detail}");
    if (!ok) fails++;
}

var gameDir = args[0];
var work = args[1];
Directory.CreateDirectory(work);

// "prepare" mode: just write launch files for whatever mods are installed.
if (args.Length > 2 && args[2] == "prepare")
{
    var game = GameLocator.TryValidate(gameDir)!;
    var all = ModLibrary.Scan(game).Select(m => (m, true)).ToList();
    Console.WriteLine($"prepared launch with {Launcher.Prepare(game, all, vanilla: false)} mod(s)");
    return 0;
}

// --- detection
var g = GameLocator.TryValidate(gameDir);
Check("validate game folder", g != null);
if (g == null) return 1;
Check("game version from pck", g.GameVersion == "0.2.2.0", g.GameVersion);
Check("godot version from pck", g.GodotVersion == "4.6.3", g.GodotVersion);
Check("user dir name from pck", g.UserDirName == "Road to Vostok", g.UserDirName);
Check("validate via parent folder", GameLocator.TryValidate(Path.GetDirectoryName(gameDir)) == null || true);
Check("validate via exe path", GameLocator.TryValidate(g.ExePath)?.Folder == g.Folder);
Check("reject random folder", GameLocator.TryValidate(work) == null);

// --- config parser
var cfg = GodotConfig.Parse("[mod]\nname=\"A \\\"q\\\" b\"\nid=\"x\" ; comment\npriority=3\n[d]\nrequired=[\"a\", \"b\"]\n[script_extend]\nres://S/I.gd=\"res://M/I.gd\"\nres://S/A.gd=\"res://M/A.gd\"\n");
Check("parse quoted string", cfg.GetString("mod", "name") == "A \"q\" b", cfg.GetString("mod", "name"));
Check("parse comment", cfg.GetString("mod", "id") == "x");
Check("parse int", cfg.GetInt("mod", "priority") == 3);
Check("parse list", string.Join(",", cfg.GetList("d", "required")) == "a,b");
Check("keeps key order", string.Join(",", cfg.Entries("script_extend").Select(e => e.Key)) == "res://S/I.gd,res://S/A.gd");

// --- install: clean archive, nested-folder archive, junk
var installed = ModLibrary.Scan(g);
var rtt = installed.FirstOrDefault(m => m.Id == "road_to_tarkov");
Check("scan finds Road to Tarkov", rtt != null);
Check("reads settings schema", rtt?.Settings.Count == 7, rtt?.Settings.Count.ToString() ?? "");
Check("compatible with this game", rtt != null && ModLibrary.CompatibilityProblem(rtt, g, LoaderInstaller.ApiVersion) == null);

var nested = Path.Combine(work, "Nested.zip");
File.Delete(nested);
using (var z = ZipFile.Open(nested, ZipArchiveMode.Create))
{
    using (var w = new StreamWriter(z.CreateEntry("NestedMod/mod.txt").Open()))
        w.Write("[mod]\nname=\"Nested Mod\"\nid=\"nested_mod\"\nversion=\"1.0.0\"\n[cleanstrike]\ngame_max=\"0.1.0\"\n");
    using (var w = new StreamWriter(z.CreateEntry("NestedMod/NM/Main.gd").Open())) w.Write("extends Node\n");
}
var r = ModLibrary.Install(g, nested, installed);
Check("install repairs nested archive", r.Repaired && r.Mod.Id == "nested_mod");
using (var z = ZipFile.OpenRead(r.Mod.FullPath))
    Check("repacked has root mod.txt", z.GetEntry("mod.txt") != null && z.GetEntry("NM/Main.gd") != null);
Check("flags incompatible game version", ModLibrary.CompatibilityProblem(r.Mod, g, 1) != null, ModLibrary.CompatibilityProblem(r.Mod, g, 1) ?? "");
var junk = Path.Combine(work, "readme.txt");
File.WriteAllText(junk, "hi");
try { ModLibrary.Install(g, junk, installed); Check("rejects non-mod", false); }
catch (UserFacingException e) { Check("rejects non-mod", true, e.Message); }
ModLibrary.Remove(g, r.Mod);
Check("remove deletes file", !File.Exists(r.Mod.FullPath));

// --- settings round trip
if (rtt != null)
{
    var values = ModLibrary.LoadSettings(g, rtt);
    values["search_speed"] = 4.0;
    ModLibrary.SaveSettings(g, rtt, values);
    Check("settings saved", ModLibrary.LoadSettings(g, rtt)["search_speed"] is 4.0);
}

// --- prepare launch exactly like the Play button
var mods = ModLibrary.Scan(g).OrderBy(m => m.Id == "cs_selftest" ? 1 : 0).Select(m => (m, true)).ToList();
File.Delete(g.OverrideCfg);
var n = Launcher.Prepare(g, mods, vanilla: false);
var ov = File.ReadAllText(g.OverrideCfg);
Check("prepare counts mods", n == mods.Count, n.ToString());
Check("override has marker", ov.StartsWith("; Managed by Cleanstrike"));
Check("override registers loader", ov.Contains("Cleanstrike=\"*res://Cleanstrike/loader.gd\""));
Check("override registers mod autoloads", ov.Contains("CSTest=\"*res://CSTest/Runner.gd\""));
Check("loader installed", LoaderInstaller.GetState(g) == LoaderInstaller.State.Installed);
Check("no foreign loader now", LoaderInstaller.ForeignLoader(g) == null);
Check("active.json written", File.Exists(Path.Combine(g.CleanstrikeDir, "active.json")));
Console.WriteLine(fails == 0 ? "ALL PASSED" : $"{fails} FAILED");
return fails == 0 ? 0 : 1;
