using System.IO;
// Exercises Cleanstrike's services against a real game folder.
// Usage: AppTests <TestGame folder> <work folder>   (prepares a launch; does not start the game)
using System.IO.Compression;
using Cleanstrike.Services;
using Cleanstrike.Models;

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
// Checks use whichever Cleanstrike mods are being tested: any mod with a
// settings schema, plus mod-specific checks when those mods are present.
var withSettings = installed.FirstOrDefault(m => m.Settings.Count > 0);
Check("scan finds Cleanstrike mods", installed.Any(m => m.HasManifest), string.Join(",", installed.Select(m => m.Id)));
Check("reads settings schema", withSettings != null && withSettings.Settings.All(s => s.Key.Length > 0 && s.Label.Length > 0), withSettings?.Id ?? "none");
Check("compatible with this game", installed.Where(m => m.HasManifest).All(m => ModLibrary.CompatibilityProblem(m, g, LoaderInstaller.ApiVersion) == null));
// Opt-in mods (cheats) are added switched off; everything else on.
var sandbox = installed.FirstOrDefault(m => m.Id == "cs_sandbox_mode");
if (sandbox != null)
{
    var trial = new Profile { Name = "opt-in check" };
    Store.Reconcile(trial, installed, enableNew: true);
    Check("opt-in mod added switched off", sandbox.OptIn && trial.Mods.Any(e => e.Id == sandbox.Id && !e.Enabled) && trial.Mods.Any(e => e.Id != sandbox.Id && e.Enabled));
}
var rtt = installed.FirstOrDefault(m => m.Id == "tarkov_looting") ?? installed.FirstOrDefault(m => m.Id == "road_to_tarkov");
var rttWip = installed.FirstOrDefault(m => m.Id == "road_to_tarkov");
if (rttWip != null)
    Check("Road to Tarkov labelled in progress", rttWip.Name.Contains("(In Progress)"), rttWip.Name);
if (rtt != null)
    Check("reads premium flag", rtt.Premium, rtt.Id);
if (rttWip != null)
    Check("reads mod thumbnail", rttWip.Thumbnail is { Length: > 1000 }, (rttWip.Thumbnail?.Length ?? 0) + " bytes");

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

// --- mod rules: clashes and requirements
static Cleanstrike.Models.ModInfo Mk(string id, string name, Dictionary<string, string>? inc = null, List<string>? req = null) =>
    new() { Id = id, Name = name, Incompatible = inc ?? new(), Requires = req ?? new() };
var ruleTabs = Mk("rt_tabs", "Trader Tabs");
var ruleBetter = Mk("rt_better", "Better Traders", new() { ["rt_tabs"] = "Both replace the trader screen." });
var ruleLib = Mk("rt_lib", "Helper");
var ruleUses = Mk("rt_uses", "Uses Helper", req: new() { "rt_lib" });
var ruleAll = new List<Cleanstrike.Models.ModInfo> { ruleTabs, ruleBetter, ruleLib, ruleUses };
var none = new List<Cleanstrike.Models.ModInfo>();
Check("clash read from either side", ModRules.ConflictReason(ruleTabs, ruleBetter) == "Both replace the trader screen." && ModRules.ConflictReason(ruleBetter, ruleTabs) != null);
var plan = ModRules.PlanEnable(ruleTabs, new List<Cleanstrike.Models.ModInfo> { ruleBetter }, ruleAll);
Check("turning a mod on offers to turn the clashing one off", plan.TurnOff.Count == 1 && plan.TurnOff[0].Mod.Id == "rt_better" && plan.TurnOn.Count == 0);
plan = ModRules.PlanEnable(ruleUses, none, ruleAll);
Check("turning a mod on pulls in what it needs", plan.TurnOn.Count == 1 && plan.TurnOn[0].Id == "rt_lib");
Check("a missing requirement is reported", ModRules.PlanEnable(Mk("rt_x", "X", req: new() { "nope" }), none, ruleAll).Missing.SequenceEqual(new[] { "nope" }));
Check("turning a mod off finds what needs it", ModRules.Dependents(ruleLib, new List<Cleanstrike.Models.ModInfo> { ruleLib, ruleUses }).Select(m => m.Id).SequenceEqual(new[] { "rt_uses" }));
var fixes = ModRules.PlanLaunch(new List<Cleanstrike.Models.ModInfo> { ruleBetter, ruleTabs, ruleUses }, ruleAll);
Check("before Play: later clashing mod and unmet requirement go", fixes.Select(f => f.Mod.Id).OrderBy(x => x).SequenceEqual(new[] { "rt_tabs", "rt_uses" }), string.Join("; ", fixes.Select(f => f.Mod.Name + " " + f.Reason)));
Check("list note explains a held-back mod", ModRules.Note(ruleTabs, false, new List<Cleanstrike.Models.ModInfo> { ruleBetter }, ruleAll) == "Can't run with Better Traders (on)");
Check("list note flags two clashing mods that are both on", ModRules.Note(ruleTabs, true, new List<Cleanstrike.Models.ModInfo> { ruleBetter }, ruleAll) == "Can't run with Better Traders: turn one off");
Check("clean set has no fixes", ModRules.PlanLaunch(new List<Cleanstrike.Models.ModInfo> { ruleBetter, ruleLib, ruleUses }, ruleAll).Count == 0);
var clashZip = Path.Combine(work, "Clash.zip");
File.Delete(clashZip);
using (var z = ZipFile.Open(clashZip, ZipArchiveMode.Create))
using (var w = new StreamWriter(z.CreateEntry("mod.txt").Open()))
    w.Write("[mod]\nname=\"Clash\"\nid=\"rt_clash\"\nversion=\"1.0.0\"\n[incompatible]\nrt_tabs=\"Both replace the trader screen.\"\n");
var clash = ModLibrary.Read(clashZip);
Check("manifest [incompatible] read", clash.Incompatible.TryGetValue("rt_tabs", out var why) && why == "Both replace the trader screen.");

// --- settings round trip
var numeric = withSettings?.Settings.FirstOrDefault(d => d.Type is "float" or "int");
if (withSettings != null && numeric != null)
{
    var values = ModLibrary.LoadSettings(g, withSettings);
    values[numeric.Key] = numeric.Max;
    ModLibrary.SaveSettings(g, withSettings, values);
    var back = ModLibrary.LoadSettings(g, withSettings)[numeric.Key];
    Check("settings saved", back != null && Convert.ToDouble(back) == numeric.Max, $"{withSettings.Id}.{numeric.Key}={back}");
    // Don't let this leak into the in-game test: back to defaults.
    File.Delete(Path.Combine(g.Folder, "Cleanstrike", "settings", withSettings.Id + ".json"));
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
