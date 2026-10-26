using System.Text.Json.Serialization;

namespace Cleanstrike.Models;

/// <summary>A Road to Vostok install folder that Cleanstrike can manage.</summary>
public sealed class GameInstall
{
    public required string Folder { get; init; }
    public required string ExePath { get; init; }
    public string? PckPath { get; init; }
    public bool IsSteam { get; init; }
    public string GameVersion { get; set; } = "unknown";
    public string GodotVersion { get; set; } = "unknown";
    /// <summary>Folder name under %APPDATA% the game writes to (project custom_user_dir_name).</summary>
    public string UserDirName { get; set; } = "Road to Vostok";

    public string CleanstrikeDir => Path.Combine(Folder, "Cleanstrike");
    public string ModsDir => Path.Combine(CleanstrikeDir, "mods");
    public string SettingsDir => Path.Combine(CleanstrikeDir, "settings");
    public string OverrideCfg => Path.Combine(Folder, "override.cfg");
    public string UserDir => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), UserDirName);
    public string ReportPath => Path.Combine(UserDir, "cleanstrike", "last_launch.json");
    public string GameLogPath => Path.Combine(UserDir, "cleanstrike", "cleanstrike.log");
    public string ProcessName => Path.GetFileNameWithoutExtension(ExePath);
}

public sealed class SettingDef
{
    public string Key { get; set; } = "";
    public string Type { get; set; } = "bool";        // bool | float | int | choice | string
    public string Label { get; set; } = "";
    public string Description { get; set; } = "";
    public object? Default { get; set; }
    public double Min { get; set; }
    public double Max { get; set; } = 1;
    public double Step { get; set; } = 0.1;
    public List<string> Options { get; set; } = new();
}

/// <summary>Everything Cleanstrike knows about one installed mod archive.</summary>
public sealed class ModInfo
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Version { get; set; } = "";
    public string Author { get; set; } = "";
    public string Description { get; set; } = "";
    public string FileName { get; set; } = "";
    public string FullPath { get; set; } = "";
    public int Priority { get; set; }
    public int Api { get; set; } = 1;
    public string GameMin { get; set; } = "";
    public string GameMax { get; set; } = "";
    public List<string> Tags { get; set; } = new();
    public List<string> Requires { get; set; } = new();
    /// <summary>[supersedes] other_id="reason": that mod still runs but has nothing to do while this one is on.</summary>
    public Dictionary<string, string> Supersedes { get; set; } = new();
    public List<KeyValuePair<string, string>> Autoloads { get; set; } = new();
    public List<SettingDef> Settings { get; set; } = new();
    public bool HasManifest { get; set; }
    public long SizeBytes { get; set; }
    public byte[]? Thumbnail { get; set; }
    public bool Premium { get; set; }
    /// <summary>Added switched off (e.g. cheats): the player turns it on.</summary>
    public bool OptIn { get; set; }
    public Dictionary<string, string> Incompatible { get; set; } = new();   // [incompatible] other_id="reason"          // [cleanstrike] premium=true: Cleanstrike's flagship mods     // icon.png / icon.jpg at the mod's root
}

public sealed class ProfileEntry
{
    public string Id { get; set; } = "";
    public string File { get; set; } = "";
    public bool Enabled { get; set; } = true;
}

public sealed class Profile
{
    public string Name { get; set; } = "Default";
    public List<ProfileEntry> Mods { get; set; } = new();
}

public sealed class AppConfig
{
    public string? GamePath { get; set; }
    public bool LaunchViaSteam { get; set; } = true;
    public bool CloseOnLaunch { get; set; }
    public string ActiveProfile { get; set; } = "Default";
}

public sealed class LaunchReport
{
    [JsonPropertyName("loader_version")] public string LoaderVersion { get; set; } = "";
    [JsonPropertyName("game_version")] public string GameVersion { get; set; } = "";
    [JsonPropertyName("safe_mode")] public bool SafeMode { get; set; }
    [JsonPropertyName("safe_mode_reason")] public string SafeModeReason { get; set; } = "";
    [JsonPropertyName("time")] public string Time { get; set; } = "";
    [JsonPropertyName("mods")] public List<LaunchReportMod> Mods { get; set; } = new();
}

public sealed class LaunchReportMod
{
    [JsonPropertyName("id")] public string Id { get; set; } = "";
    [JsonPropertyName("name")] public string Name { get; set; } = "";
    [JsonPropertyName("status")] public string Status { get; set; } = "";
    [JsonPropertyName("reason")] public string Reason { get; set; } = "";
}
