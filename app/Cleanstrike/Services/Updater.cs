using System.Diagnostics;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;

namespace Cleanstrike.Services;

/// <summary>
/// Keeps Cleanstrike current. On launch it asks GitHub for the latest release;
/// if it is newer, it downloads Cleanstrike.exe next to the running one, swaps
/// the files (a running .exe can be renamed on Windows, not overwritten) and
/// restarts into the new version. Anything that goes wrong leaves the current
/// version in place. CLEANSTRIKE_NO_UPDATE=1 turns it off (dev builds).
/// </summary>
public static class Updater
{
    public const string Repo = "project509/cleanstrike";
    const string AssetName = "Cleanstrike.exe";

    public static Version Current => Assembly.GetExecutingAssembly().GetName().Version ?? new Version(0, 0);

    static string? ExePath => Environment.ProcessPath;
    static string OldPath(string exe) => exe + ".old";
    static string NewPath(string exe) => exe + ".download";

    /// <summary>Remove what an earlier update left behind.</summary>
    public static void Cleanup()
    {
        var exe = ExePath;
        if (exe == null) return;
        foreach (var p in new[] { OldPath(exe), NewPath(exe) })
        {
            try { if (File.Exists(p)) File.Delete(p); } catch { /* still in use: next time */ }
        }
    }

    public static bool Enabled()
    {
        if (Environment.GetEnvironmentVariable("CLEANSTRIKE_NO_UPDATE") == "1") return false;
        var exe = ExePath;
        // Only the published single-file app updates itself (not `dotnet run`, not dev builds).
        return exe != null && Path.GetFileName(exe).Equals(AssetName, StringComparison.OrdinalIgnoreCase)
            && !exe.Contains(Path.DirectorySeparatorChar + "bin" + Path.DirectorySeparatorChar);
    }

    public sealed record Release(Version Version, string Url, long Size);

    /// <summary>"v1.2.0" / "1.2" -> 1.2.0; null when it isn't a version.</summary>
    public static Version? ParseTag(string tag)
    {
        var t = tag.Trim().TrimStart('v', 'V');
        return Version.TryParse(t, out var v) ? new Version(v.Major, v.Minor, Math.Max(0, v.Build)) : null;
    }

    public static bool IsNewer(Version latest, Version current) =>
        latest > new Version(current.Major, current.Minor, Math.Max(0, current.Build));

    /// <summary>Reads a GitHub "latest release" document.</summary>
    public static Release? ParseRelease(string json)
    {
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        if (!root.TryGetProperty("tag_name", out var tag) || ParseTag(tag.GetString() ?? "") is not { } v) return null;
        if (root.TryGetProperty("draft", out var d) && d.GetBoolean()) return null;
        if (root.TryGetProperty("prerelease", out var p) && p.GetBoolean()) return null;
        if (!root.TryGetProperty("assets", out var assets)) return null;
        foreach (var a in assets.EnumerateArray())
            if (a.GetProperty("name").GetString() == AssetName)
                return new Release(v, a.GetProperty("browser_download_url").GetString() ?? "", a.GetProperty("size").GetInt64());
        return null;
    }

    static HttpClient Client()
    {
        var c = new HttpClient { Timeout = TimeSpan.FromMinutes(10) };
        c.DefaultRequestHeaders.UserAgent.ParseAdd("Cleanstrike-Updater/" + Current);
        return c;
    }

    /// <summary>
    /// Checks, downloads and swaps in a newer version. Returns the new version
    /// once it is in place (the caller restarts), or null when there is nothing
    /// to do or something failed.
    /// </summary>
    public static async Task<Version?> UpdateAsync(Action<string>? progress = null)
    {
        if (!Enabled()) return null;
        var exe = ExePath!;
        try
        {
            using var http = Client();
            string json;
            using (var cts = new CancellationTokenSource(TimeSpan.FromSeconds(15)))
                json = await http.GetStringAsync($"https://api.github.com/repos/{Repo}/releases/latest", cts.Token);
            var rel = ParseRelease(json);
            if (rel == null || !IsNewer(rel.Version, Current)) return null;
            Log.Write($"Update: {Current} -> {rel.Version}, downloading");
            progress?.Invoke($"Updating Cleanstrike to {rel.Version}…");

            var tmp = NewPath(exe);
            using (var resp = await http.GetAsync(rel.Url, HttpCompletionOption.ResponseHeadersRead))
            {
                resp.EnsureSuccessStatusCode();
                await using var src = await resp.Content.ReadAsStreamAsync();
                await using var dst = File.Create(tmp);
                await src.CopyToAsync(dst);
            }
            if (new FileInfo(tmp).Length != rel.Size)
            {
                Log.Write("Update: download size mismatch, keeping the current version");
                File.Delete(tmp);
                return null;
            }
            Swap(exe, tmp);
            Log.Write($"Update: {rel.Version} installed");
            return rel.Version;
        }
        catch (Exception e)
        {
            Log.Write("Update check failed: " + e.Message);
            try { File.Delete(NewPath(exe)); } catch { }
            return null;
        }
    }

    /// <summary>Running exe -> .old, download -> exe; undone if the second step fails.</summary>
    public static void Swap(string exe, string downloaded)
    {
        var old = OldPath(exe);
        if (File.Exists(old)) File.Delete(old);
        File.Move(exe, old);
        try { File.Move(downloaded, exe); }
        catch
        {
            File.Move(old, exe);
            throw;
        }
    }

    /// <summary>Start the new version with the same arguments.</summary>
    public static void Restart(string[] args)
    {
        var exe = ExePath;
        if (exe == null) return;
        var psi = new ProcessStartInfo(exe) { UseShellExecute = false, WorkingDirectory = Path.GetDirectoryName(exe) ?? "" };
        foreach (var a in args) psi.ArgumentList.Add(a);
        psi.ArgumentList.Add("--updated");
        Process.Start(psi);
    }
}
