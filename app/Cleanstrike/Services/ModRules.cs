using Cleanstrike.Models;

namespace Cleanstrike.Services;

/// <summary>
/// Which mods can run together. A mod lists the ones it can't run with in
/// its manifest ([incompatible] other_id="reason"); either side declaring it
/// is enough. Mods can also need others ([dependencies] required=[...]).
/// Pure logic: the app turns these plans into friendly prompts.
/// </summary>
public static class ModRules
{
    public sealed record Clash(ModInfo Mod, ModInfo Other, string Reason);

    /// <summary>Why a and b can't run together, or null if they can.</summary>
    public static string? ConflictReason(ModInfo a, ModInfo b)
    {
        if (a.Id == b.Id) return null;
        if (a.Incompatible.TryGetValue(b.Id, out var r)) return Explain(a, b, r);
        if (b.Incompatible.TryGetValue(a.Id, out r)) return Explain(b, a, r);
        return null;
    }

    private static string Explain(ModInfo declaring, ModInfo other, string reason) =>
        reason.Trim().Length > 0 ? reason.Trim() : $"{declaring.Name} doesn't work alongside {other.Name}.";

    /// <summary>What turning a mod on involves.</summary>
    public sealed record EnablePlan(List<Clash> TurnOff, List<ModInfo> TurnOn, List<string> Missing)
    {
        public bool IsSimple => TurnOff.Count == 0 && TurnOn.Count == 0 && Missing.Count == 0;
    }

    /// <summary>
    /// Turning <paramref name="mod"/> on: the mods it needs (turned on too,
    /// or missing if not installed) and the enabled mods it can't run with
    /// (to be turned off), including clashes with the mods it pulls in.
    /// </summary>
    public static EnablePlan PlanEnable(ModInfo mod, IReadOnlyList<ModInfo> enabled, IReadOnlyList<ModInfo> installed)
    {
        var turnOn = new List<ModInfo>();
        var missing = new List<string>();
        var seen = new HashSet<string> { mod.Id };
        var stack = new Stack<ModInfo>();
        stack.Push(mod);
        while (stack.Count > 0)
        {
            foreach (var req in stack.Pop().Requires)
            {
                if (!seen.Add(req) || enabled.Any(e => e.Id == req)) continue;
                var found = installed.FirstOrDefault(i => i.Id == req);
                if (found == null) { missing.Add(req); continue; }
                turnOn.Add(found);
                stack.Push(found);
            }
        }
        var incoming = new List<ModInfo> { mod };
        incoming.AddRange(turnOn);
        var turnOff = new List<Clash>();
        foreach (var e in enabled)
        {
            if (incoming.Any(i => i.Id == e.Id)) continue;
            foreach (var i in incoming)
            {
                var reason = ConflictReason(i, e);
                if (reason == null) continue;
                turnOff.Add(new Clash(e, i, reason));
                break;
            }
        }
        // Enabled mods that need something being turned off have to go too.
        foreach (var gone in turnOff.ToList())
            foreach (var dep in Dependents(gone.Mod, enabled))
                if (turnOff.All(t => t.Mod.Id != dep.Id) && incoming.All(i => i.Id != dep.Id))
                    turnOff.Add(new Clash(dep, gone.Mod, $"{dep.Name} needs {gone.Mod.Name}."));
        return new EnablePlan(turnOff, turnOn, missing);
    }

    /// <summary>Enabled mods that need <paramref name="mod"/>, directly or through others.</summary>
    public static List<ModInfo> Dependents(ModInfo mod, IReadOnlyList<ModInfo> enabled)
    {
        var result = new List<ModInfo>();
        var frontier = new Queue<string>();
        frontier.Enqueue(mod.Id);
        while (frontier.Count > 0)
        {
            var id = frontier.Dequeue();
            foreach (var e in enabled)
                if (e.Requires.Contains(id) && e.Id != mod.Id && result.All(r => r.Id != e.Id))
                {
                    result.Add(e);
                    frontier.Enqueue(e.Id);
                }
        }
        return result;
    }

    public sealed record LaunchFix(ModInfo Mod, string Reason);

    /// <summary>
    /// Problems in a set of enabled mods (in load order), each with the mod
    /// to turn off to fix it: of two clashing mods the later one goes; a mod
    /// whose requirement is off or missing goes.
    /// </summary>
    public static List<LaunchFix> PlanLaunch(IReadOnlyList<ModInfo> enabledInOrder, IReadOnlyList<ModInfo> installed)
    {
        var fixes = new List<LaunchFix>();
        var keep = new List<ModInfo>();
        foreach (var m in enabledInOrder)
        {
            var clash = keep.Select(k => (k, reason: ConflictReason(m, k))).FirstOrDefault(x => x.reason != null);
            if (clash.reason != null)
            {
                fixes.Add(new LaunchFix(m, $"can't run with {clash.k.Name}: {clash.reason}"));
                continue;
            }
            keep.Add(m);
        }
        bool changed = true;
        while (changed)
        {
            changed = false;
            foreach (var m in keep.ToList())
            {
                var need = m.Requires.FirstOrDefault(r => keep.All(k => k.Id != r));
                if (need == null) continue;
                var name = installed.FirstOrDefault(i => i.Id == need)?.Name ?? need;
                var on = installed.Any(i => i.Id == need);
                fixes.Add(new LaunchFix(m, on ? $"needs {name}, which is off" : $"needs {name}, which isn't installed"));
                keep.Remove(m);
                changed = true;
            }
        }
        return fixes;
    }

    /// <summary>A short note for the mod list, or null.</summary>
    public static string? Note(ModInfo mod, bool isEnabled, IReadOnlyList<ModInfo> enabled, IReadOnlyList<ModInfo> installed)
    {
        if (!isEnabled)
        {
            var clash = enabled.Select(e => (e, reason: ConflictReason(mod, e))).FirstOrDefault(x => x.reason != null);
            return clash.reason != null ? $"Can't run with {clash.e.Name} (on)" : null;
        }
        var both = enabled.Select(e => (e, reason: ConflictReason(mod, e))).FirstOrDefault(x => x.reason != null);
        if (both.reason != null) return $"Can't run with {both.e.Name}: turn one off";
        var over = enabled.FirstOrDefault(e => e.Supersedes.ContainsKey(mod.Id));
        if (over != null) return $"No effect while {over.Name} is on: {over.Supersedes[mod.Id]}";
        var need = mod.Requires.FirstOrDefault(r => enabled.All(e => e.Id != r));
        if (need == null) return null;
        var name = installed.FirstOrDefault(i => i.Id == need)?.Name;
        return name != null ? $"Needs {name}, which is off" : $"Needs {need}, which isn't installed";
    }
}
