using System.Globalization;
using System.Text;

namespace Cleanstrike.Services;

/// <summary>
/// Minimal reader for Godot ConfigFile text (mod.txt, override.cfg).
/// Keeps section and key order, which matters for script_extend.
/// Values: "strings", numbers, true/false, and [arrays] of those.
/// </summary>
public sealed class GodotConfig
{
    public List<(string Name, List<(string Key, object? Value)> Entries)> Sections { get; } = new();

    public static GodotConfig Parse(string text)
    {
        var cfg = new GodotConfig();
        List<(string, object?)>? current = null;
        foreach (var raw in text.Replace("\r", "").Split('\n'))
        {
            var line = raw.Trim();
            if (line.Length == 0 || line[0] == ';' || line[0] == '#') continue;
            if (line[0] == '[' && line.EndsWith(']'))
            {
                current = new List<(string, object?)>();
                cfg.Sections.Add((line[1..^1].Trim(), current));
                continue;
            }
            var eq = line.IndexOf('=');
            if (eq <= 0) continue;
            var key = line[..eq].Trim().Trim('"');
            var value = ParseValue(line[(eq + 1)..].Trim());
            if (current == null)
            {
                current = new List<(string, object?)>();
                cfg.Sections.Add(("", current));
            }
            current.Add((key, value));
        }
        return cfg;
    }

    public object? Get(string section, string key)
    {
        foreach (var s in Sections)
            if (s.Name == section)
                foreach (var e in s.Entries)
                    if (e.Key == key) return e.Value;
        return null;
    }

    public string GetString(string section, string key, string fallback = "") =>
        Get(section, key) is { } v ? Convert.ToString(v, CultureInfo.InvariantCulture) ?? fallback : fallback;

    public int GetInt(string section, string key, int fallback = 0) =>
        Get(section, key) switch { double d => (int)d, string s when int.TryParse(s, out var i) => i, _ => fallback };

    public List<string> GetList(string section, string key) =>
        Get(section, key) is List<object?> l ? l.Select(x => Convert.ToString(x, CultureInfo.InvariantCulture) ?? "").ToList() : new();

    public IEnumerable<(string Key, object? Value)> Entries(string section) =>
        Sections.Where(s => s.Name == section).SelectMany(s => s.Entries);

    public bool HasSection(string section) => Sections.Any(s => s.Name == section);

    private static object? ParseValue(string v)
    {
        // Strip a trailing comment outside quotes.
        var inStr = false;
        for (int i = 0; i < v.Length; i++)
        {
            if (v[i] == '"' && (i == 0 || v[i - 1] != '\\')) inStr = !inStr;
            else if (!inStr && (v[i] == ';' || v[i] == '#')) { v = v[..i].TrimEnd(); break; }
        }
        int pos = 0;
        return ReadValue(v, ref pos);
    }

    private static object? ReadValue(string s, ref int i)
    {
        SkipWs(s, ref i);
        if (i >= s.Length) return "";
        char c = s[i];
        if (c == '"') return ReadString(s, ref i);
        if (c == '[')
        {
            i++;
            var list = new List<object?>();
            while (true)
            {
                SkipWs(s, ref i);
                if (i >= s.Length) break;
                if (s[i] == ']') { i++; break; }
                if (s[i] == ',') { i++; continue; }
                list.Add(ReadValue(s, ref i));
            }
            return list;
        }
        int start = i;
        while (i < s.Length && s[i] != ',' && s[i] != ']') i++;
        var tok = s[start..i].Trim();
        if (tok == "true") return true;
        if (tok == "false") return false;
        if (tok == "null") return null;
        if (double.TryParse(tok, NumberStyles.Float, CultureInfo.InvariantCulture, out var d)) return d;
        return tok; // unquoted literal, keep as text
    }

    private static string ReadString(string s, ref int i)
    {
        var sb = new StringBuilder();
        i++; // opening quote
        while (i < s.Length && s[i] != '"')
        {
            if (s[i] == '\\' && i + 1 < s.Length)
            {
                i++;
                sb.Append(s[i] switch { 'n' => '\n', 't' => '\t', _ => s[i] });
            }
            else sb.Append(s[i]);
            i++;
        }
        i++; // closing quote
        return sb.ToString();
    }

    private static void SkipWs(string s, ref int i)
    {
        while (i < s.Length && char.IsWhiteSpace(s[i])) i++;
    }

    public static string Quote(string s) => "\"" + s.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
}
