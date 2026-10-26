using System.Collections.ObjectModel;
using System.Globalization;
using Cleanstrike.Models;
using Cleanstrike.Services;

namespace Cleanstrike.ViewModels;

public enum ModStatusKind { None, Loaded, Problem, Disabled }

public sealed class ModItemViewModel : ObservableObject
{
    private readonly Action _onToggled;
    private readonly GameInstall _game;
    private bool _enabled;
    private string _statusText = "";
    private ModStatusKind _statusKind;

    public ModItemViewModel(ModInfo mod, GameInstall game, bool enabled, Action onToggled)
    {
        Mod = mod;
        _game = game;
        _enabled = enabled;
        _onToggled = onToggled;
        Compatibility = ModLibrary.CompatibilityProblem(mod, game, LoaderInstaller.ApiVersion);
        var values = ModLibrary.LoadSettings(game, mod);
        foreach (var def in mod.Settings)
            Settings.Add(new SettingViewModel(def, values.GetValueOrDefault(def.Key, def.Default), () => SaveSettings()));
    }

    public ModInfo Mod { get; }
    public string Name => Mod.Name;
    public string Initial => Mod.Name.Length > 0 ? Mod.Name[..1].ToUpperInvariant() : "?";
    public bool HasThumbnail => Thumbnail != null;
    private System.Windows.Media.ImageSource? _thumb;
    private bool _thumbTried;
    public System.Windows.Media.ImageSource? Thumbnail
    {
        get
        {
            if (_thumbTried || Mod.Thumbnail == null)
                return _thumb;
            _thumbTried = true;
            try
            {
                var bmp = new System.Windows.Media.Imaging.BitmapImage();
                bmp.BeginInit();
                bmp.CacheOption = System.Windows.Media.Imaging.BitmapCacheOption.OnLoad;
                bmp.DecodePixelWidth = 320;
                bmp.StreamSource = new MemoryStream(Mod.Thumbnail);
                bmp.EndInit();
                bmp.Freeze();
                _thumb = bmp;
            }
            catch (Exception ex)
            {
                Log.Write($"Thumbnail for {Mod.Id} unreadable: {ex.Message}");
            }
            return _thumb;
        }
    }
    public string Version => Mod.Version.Length > 0 ? "v" + Mod.Version : "";
    public string Author => Mod.Author;
    public string Description => Mod.Description.Length > 0 ? Mod.Description : "No description.";
    public string Byline => string.Join("  ·  ", new[] { Version, Mod.Author.Length > 0 ? "by " + Mod.Author : "" }.Where(s => s.Length > 0));
    public IReadOnlyList<string> Tags => Mod.Tags;
    public bool HasTags => Mod.Tags.Count > 0;
    public string FileLine => $"{Mod.FileName}  ·  {FormatSize(Mod.SizeBytes)}";
    public string? Compatibility { get; }
    public bool IsCompatible => Compatibility == null;
    public ObservableCollection<SettingViewModel> Settings { get; } = new();
    public bool HasSettings => Settings.Count > 0;

    public bool IsEnabled
    {
        get => _enabled;
        set
        {
            if (Set(ref _enabled, value)) _onToggled();
        }
    }

    public string StatusText { get => _statusText; private set => Set(ref _statusText, value); }
    public ModStatusKind StatusKind { get => _statusKind; private set => Set(ref _statusKind, value); }
    public bool HasStatus => StatusText.Length > 0;

    public void ApplyReport(LaunchReportMod? r)
    {
        if (r == null) { StatusText = ""; StatusKind = ModStatusKind.None; }
        else
        {
            (StatusKind, StatusText) = r.Status switch
            {
                "loaded" => (ModStatusKind.Loaded, "Loaded last launch"),
                "disabled" => (ModStatusKind.Disabled, ""),
                "incompatible" or "failed" or "missing" => (ModStatusKind.Problem, r.Reason.Length > 0 ? r.Reason : "Didn't load last launch."),
                _ => (ModStatusKind.None, ""),
            };
        }
        Raise(nameof(HasStatus));
    }

    private void SaveSettings()
    {
        try
        {
            ModLibrary.SaveSettings(_game, Mod, Settings.ToDictionary(s => s.Key, s => s.RawValue));
        }
        catch (Exception e) { Log.Write("Saving settings failed: " + e.Message); }
    }

    private static string FormatSize(long b) => b switch
    {
        < 1024 => b + " B",
        < 1024 * 1024 => (b / 1024.0).ToString("0", CultureInfo.InvariantCulture) + " KB",
        _ => (b / 1024.0 / 1024.0).ToString("0.0", CultureInfo.InvariantCulture) + " MB",
    };
}

public sealed class SettingViewModel : ObservableObject
{
    private readonly Action _changed;
    private object? _value;

    public SettingViewModel(SettingDef def, object? value, Action changed)
    {
        Def = def;
        _changed = changed;
        _value = Coerce(value ?? def.Default);
    }

    public SettingDef Def { get; }
    public string Key => Def.Key;
    public string Label => Def.Label;
    public string Description => Def.Description;
    public bool HasDescription => Def.Description.Length > 0;
    public bool IsBool => Def.Type == "bool";
    public bool IsNumber => Def.Type is "float" or "int";
    public bool IsChoice => Def.Type == "choice";
    public bool IsText => Def.Type == "string";
    public double Min => Def.Min;
    public double Max => Def.Max;
    public double Step => Def.Type == "int" ? Math.Max(1, Math.Round(Def.Step)) : Def.Step;
    public IReadOnlyList<string> Options => Def.Options;
    public object? RawValue => _value;

    public bool BoolValue
    {
        get => _value is true;
        set => Update(value);
    }

    public double NumberValue
    {
        get => _value is double d ? d : 0;
        set => Update(Def.Type == "int" ? Math.Round(value) : Math.Round(value / Step) * Step);
    }

    public string NumberText => Def.Type == "int"
        ? NumberValue.ToString("0", CultureInfo.InvariantCulture)
        : NumberValue.ToString(Step >= 1 ? "0" : Step >= 0.1 ? "0.0#" : "0.00#", CultureInfo.InvariantCulture) + (Def.Key.EndsWith("speed") ? "×" : "");

    public string TextValue
    {
        get => _value?.ToString() ?? "";
        set => Update(value);
    }

    public bool IsDefault => Equals(_value, Coerce(Def.Default));

    public void Reset() => Update(Coerce(Def.Default));

    private void Update(object? v)
    {
        v = Coerce(v);
        if (Equals(v, _value)) return;
        _value = v;
        Raise(nameof(BoolValue));
        Raise(nameof(NumberValue));
        Raise(nameof(NumberText));
        Raise(nameof(TextValue));
        Raise(nameof(IsDefault));
        _changed();
    }

    private object? Coerce(object? v) => Def.Type switch
    {
        "bool" => v is true || (v is string s && s == "true"),
        "float" or "int" => Math.Clamp(v is double d ? d : double.TryParse(v?.ToString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var p) ? p : Def.Min, Def.Min, Def.Max),
        _ => v?.ToString() ?? "",
    };
}
