using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Threading;
using Cleanstrike.Models;
using Cleanstrike.Services;
using Cleanstrike.Views;
using Microsoft.Win32;

namespace Cleanstrike.ViewModels;

public enum AppState { Searching, NeedsGame, Ready }

public sealed class MainViewModel : ObservableObject
{
    private readonly AppConfig _config = Store.LoadConfig();
    private readonly DispatcherTimer _pollTimer = new() { Interval = TimeSpan.FromSeconds(1.5) };
    private readonly DispatcherTimer _toastTimer = new() { Interval = TimeSpan.FromSeconds(4.5) };
    private Profile _profile = new();
    private AppState _state = AppState.Searching;
    private GameInstall? _game;
    private ModItemViewModel? _selected;
    private string _activeProfile = "Default";
    private bool _isRunning;
    private DateTime? _awaitingReportSince;
    private string _toastText = "";
    private string _toastKind = "info";
    private bool _toastVisible;
    private string? _banner;
    private bool _switchingProfile;

    public MainViewModel()
    {
        PlayCommand = new RelayCommand(() => Play(false), () => CanPlay);
        PlayVanillaCommand = new RelayCommand(() => Play(true), () => CanPlay);
        AddModCommand = new RelayCommand(AddModsFromDialog, () => Game != null);
        RemoveModCommand = new RelayCommand(p => RemoveMod(p as ModItemViewModel ?? Selected), p => (p ?? Selected) != null);
        LocateGameCommand = new RelayCommand(LocateGame);
        SearchAgainCommand = new RelayCommand(() => _ = DetectGameAsync(ignoreSaved: true));
        OpenModsFolderCommand = new RelayCommand(() => OpenFolder(Game?.ModsDir), () => Game != null);
        OpenGameFolderCommand = new RelayCommand(() => OpenFolder(Game?.Folder), () => Game != null);
        OpenLogCommand = new RelayCommand(OpenLog, () => Game != null);
        NewProfileCommand = new RelayCommand(NewProfile, () => Game != null);
        RenameProfileCommand = new RelayCommand(RenameProfile, () => Game != null);
        DeleteProfileCommand = new RelayCommand(DeleteProfile, () => Profiles.Count > 1);
        UninstallCommand = new RelayCommand(UninstallFromGame, () => Game != null);
        DismissBannerCommand = new RelayCommand(() => Banner = null);
        ToggleSteamCommand = new RelayCommand(() => { _config.LaunchViaSteam = !_config.LaunchViaSteam; SaveConfig(); Raise(nameof(LaunchViaSteam)); });
        ToggleCloseOnLaunchCommand = new RelayCommand(() => { _config.CloseOnLaunch = !_config.CloseOnLaunch; SaveConfig(); Raise(nameof(CloseOnLaunch)); });

        _pollTimer.Tick += (_, _) => Poll();
        _toastTimer.Tick += (_, _) => { ToastVisible = false; _toastTimer.Stop(); };
        _ = DetectGameAsync(ignoreSaved: false);
    }

    // ------------------------------------------------------------ bindable state

    public AppState State { get => _state; private set { if (Set(ref _state, value)) { Raise(nameof(IsSearching)); Raise(nameof(NeedsGame)); Raise(nameof(IsReady)); } } }
    public bool IsSearching => State == AppState.Searching;
    public bool NeedsGame => State == AppState.NeedsGame;
    public bool IsReady => State == AppState.Ready;

    public GameInstall? Game
    {
        get => _game;
        private set
        {
            if (Set(ref _game, value))
            {
                Raise(nameof(GameTitle));
                Raise(nameof(GameDetail));
                Raise(nameof(LoaderStatus));
            }
        }
    }

    public string GameTitle => Game == null ? "Road to Vostok" : $"Road to Vostok {(Game.GameVersion == "unknown" ? "" : Game.GameVersion)}".Trim();
    public string GameDetail => Game == null ? "" : $"{(Game.IsSteam ? "Steam" : "Local copy")}  ·  Godot {Game.GodotVersion}  ·  {Game.Folder}";
    public string LoaderStatus => Game == null ? "" : LoaderInstaller.GetState(Game) switch
    {
        LoaderInstaller.State.Installed => $"Cleanstrike {LoaderInstaller.BundledVersion} is set up in this game",
        LoaderInstaller.State.Outdated => "Cleanstrike will update itself in the game when you press Play",
        _ => "Cleanstrike sets itself up in the game when you press Play",
    };

    public ObservableCollection<ModItemViewModel> Mods { get; } = new();
    public ObservableCollection<string> Profiles { get; } = new();

    public ModItemViewModel? Selected
    {
        get => _selected;
        set { if (Set(ref _selected, value)) Raise(nameof(HasSelection)); }
    }
    public bool HasSelection => Selected != null;
    public bool HasMods => Mods.Count > 0;

    public string ActiveProfile
    {
        get => _activeProfile;
        set
        {
            if (value == null || _activeProfile == value) return;
            _activeProfile = value;
            Raise();
            if (_switchingProfile) return;
            _config.ActiveProfile = value;
            SaveConfig();
            LoadLibrary();
        }
    }

    public bool IsRunning
    {
        get => _isRunning;
        private set { if (Set(ref _isRunning, value)) { Raise(nameof(PlayLabel)); Raise(nameof(CanPlay)); CommandManagerRefresh(); } }
    }

    public bool CanPlay => Game != null && !IsRunning && IsReady;
    public string PlayLabel => IsRunning ? "Running" : "Play";

    public string Summary
    {
        get
        {
            var on = Mods.Where(m => m.IsEnabled).ToList();
            if (Mods.Count == 0) return "No mods installed yet";
            if (on.Count == 0) return "All mods off. Play starts the game without mods";
            if (on.Count == 1) return on[0].Name + " is on";
            return $"{on.Count} of {Mods.Count} mods on";
        }
    }

    public bool LaunchViaSteam => _config.LaunchViaSteam;
    public bool CloseOnLaunch => _config.CloseOnLaunch;
    public bool CanLaunchViaSteam => Game?.IsSteam == true;

    public string? Banner { get => _banner; private set { if (Set(ref _banner, value)) Raise(nameof(HasBanner)); } }
    public bool HasBanner => Banner != null;

    public string ToastText { get => _toastText; private set => Set(ref _toastText, value); }
    public string ToastKind { get => _toastKind; private set => Set(ref _toastKind, value); }
    public bool ToastVisible { get => _toastVisible; private set => Set(ref _toastVisible, value); }

    public RelayCommand PlayCommand { get; }
    public RelayCommand PlayVanillaCommand { get; }
    public RelayCommand AddModCommand { get; }
    public RelayCommand RemoveModCommand { get; }
    public RelayCommand LocateGameCommand { get; }
    public RelayCommand SearchAgainCommand { get; }
    public RelayCommand OpenModsFolderCommand { get; }
    public RelayCommand OpenGameFolderCommand { get; }
    public RelayCommand OpenLogCommand { get; }
    public RelayCommand NewProfileCommand { get; }
    public RelayCommand RenameProfileCommand { get; }
    public RelayCommand DeleteProfileCommand { get; }
    public RelayCommand UninstallCommand { get; }
    public RelayCommand DismissBannerCommand { get; }
    public RelayCommand ToggleSteamCommand { get; }
    public RelayCommand ToggleCloseOnLaunchCommand { get; }

    // ------------------------------------------------------------ game detection

    private async Task DetectGameAsync(bool ignoreSaved)
    {
        State = AppState.Searching;
        var saved = ignoreSaved ? null : _config.GamePath;
        var found = await Task.Run(() =>
        {
            var g = GameLocator.TryValidate(saved);
            return g ?? GameLocator.AutoDetect();
        });
        await Task.Delay(350); // let the searching state register instead of flashing
        if (found == null)
        {
            Game = null;
            State = AppState.NeedsGame;
            return;
        }
        UseGame(found);
    }

    private void UseGame(GameInstall g)
    {
        Game = g;
        _config.GamePath = g.Folder;
        SaveConfig();
        Raise(nameof(CanLaunchViaSteam));
        var foreign = LoaderInstaller.ForeignLoader(g);
        Banner = foreign == null ? null :
            $"{char.ToUpper(foreign[0])}{foreign[1..]} is set up in this game. When you press Play, Cleanstrike takes over and backs up the old setup. Removing Cleanstrike puts it back.";
        LoadProfiles();
        LoadLibrary();
        State = AppState.Ready;
        _pollTimer.Start();
        Poll();
        CommandManagerRefresh();
    }

    private void LocateGame()
    {
        var dlg = new OpenFolderDialog
        {
            Title = "Select your Road to Vostok folder (the one with the game's .exe)",
            InitialDirectory = Game?.Folder ?? GameLocator.SteamRoot() ?? "",
        };
        if (dlg.ShowDialog(Application.Current.MainWindow) != true) return;
        var g = GameLocator.TryValidate(dlg.FolderName);
        if (g == null)
        {
            Dialog.Show(Application.Current.MainWindow, "That's not the game folder",
                "Cleanstrike couldn't find Road to Vostok in that folder. Pick the folder that contains the game's .exe and .pck files.\n\nIn Steam: right-click Road to Vostok > Manage > Browse local files.", "OK");
            return;
        }
        UseGame(g);
        Toast("Found Road to Vostok " + g.GameVersion, "success");
    }

    // ------------------------------------------------------------ library & profiles

    private void LoadProfiles()
    {
        _switchingProfile = true;
        Profiles.Clear();
        foreach (var p in Store.ProfileNames()) Profiles.Add(p);
        var want = Profiles.Contains(_config.ActiveProfile) ? _config.ActiveProfile : Profiles[0];
        _activeProfile = "";
        ActiveProfile = want;
        _switchingProfile = false;
    }

    private void LoadLibrary(string? selectId = null)
    {
        if (Game == null) return;
        selectId ??= Selected?.Mod.Id;
        var mods = ModLibrary.Scan(Game);
        _profile = Store.LoadProfile(ActiveProfile);
        // Mods that appear in the folder are on in the profile you're using.
        if (Store.Reconcile(_profile, mods, enableNew: true)) Store.SaveProfile(_profile);

        Mods.Clear();
        var report = Launcher.ReadReport(Game);
        foreach (var entry in _profile.Mods)
        {
            var mod = mods.FirstOrDefault(m => string.Equals(m.Id, entry.Id, StringComparison.OrdinalIgnoreCase));
            if (mod == null) continue;
            var vm = new ModItemViewModel(mod, Game, entry.Enabled, OnModToggled);
            vm.ApplyReport(report?.Mods.FirstOrDefault(r => r.Id == mod.Id));
            Mods.Add(vm);
        }
        Selected = Mods.FirstOrDefault(m => m.Mod.Id == selectId) ?? Mods.FirstOrDefault();
        Raise(nameof(HasMods));
        Raise(nameof(Summary));
        Raise(nameof(LoaderStatus));
    }

    private void OnModToggled()
    {
        SaveProfile();
        Raise(nameof(Summary));
    }

    private void SaveProfile()
    {
        _profile.Name = ActiveProfile;
        _profile.Mods = Mods.Select(m => new ProfileEntry { Id = m.Mod.Id, File = m.Mod.FileName, Enabled = m.IsEnabled }).ToList();
        Store.SaveProfile(_profile);
    }

    public void Move(ModItemViewModel item, int newIndex)
    {
        int old = Mods.IndexOf(item);
        newIndex = Math.Clamp(newIndex, 0, Mods.Count - 1);
        if (old < 0 || old == newIndex) return;
        Mods.Move(old, newIndex);
        SaveProfile();
    }

    public void InstallFiles(IEnumerable<string> paths)
    {
        if (Game == null) return;
        var installed = ModLibrary.Scan(Game);
        var done = new List<ModLibrary.InstallResult>();
        var errors = new List<string>();
        foreach (var path in paths)
        {
            try
            {
                var r = ModLibrary.Install(Game, path, installed);
                installed.RemoveAll(m => m.Id == r.Mod.Id);
                installed.Add(r.Mod);
                done.Add(r);
            }
            catch (UserFacingException e) { errors.Add(e.Message); }
            catch (UnauthorizedAccessException) { errors.Add(AccessMessage()); }
            catch (Exception e)
            {
                Log.Write("Install failed: " + e);
                errors.Add($"Couldn't install \"{Path.GetFileName(path)}\": {e.Message}");
            }
        }
        if (done.Count > 0)
        {
            // New mods are switched on in the current profile and off in the others.
            foreach (var name in Profiles.Where(p => p != ActiveProfile))
            {
                var p = Store.LoadProfile(name);
                if (Store.Reconcile(p, installed, enableNew: false)) Store.SaveProfile(p);
            }
            var current = Store.LoadProfile(ActiveProfile);
            Store.Reconcile(current, installed, enableNew: false);
            foreach (var r in done)
            {
                var e = current.Mods.First(x => x.Id == r.Mod.Id);
                if (r.Replaced == null) e.Enabled = true;
            }
            Store.SaveProfile(current);
            LoadLibrary(done[^1].Mod.Id);

            var first = done[0];
            string msg = done.Count > 1 ? $"Installed {done.Count} mods"
                : first.Replaced != null && first.Replaced.Version != first.Mod.Version && first.Replaced.Version.Length > 0
                    ? $"Updated {first.Mod.Name} {first.Replaced.Version} → {first.Mod.Version}"
                    : first.Replaced != null ? $"Reinstalled {first.Mod.Name}" : $"Installed {first.Mod.Name}";
            if (done.Any(d => d.Repaired)) msg += " (fixed its packaging)";
            Toast(msg, "success");
        }
        if (errors.Count > 0)
            Dialog.Show(Application.Current.MainWindow, errors.Count == 1 ? "Couldn't install that mod" : "Some mods couldn't be installed",
                string.Join("\n\n", errors), "OK");
    }

    private void AddModsFromDialog()
    {
        var dlg = new OpenFileDialog
        {
            Title = "Add mods",
            Filter = "Road to Vostok mods (*.csmod;*.vmz;*.zip;*.pck)|*.csmod;*.vmz;*.zip;*.pck|All files|*.*",
            Multiselect = true,
        };
        if (dlg.ShowDialog(Application.Current.MainWindow) == true) InstallFiles(dlg.FileNames);
    }

    private void RemoveMod(ModItemViewModel? m)
    {
        if (m == null || Game == null) return;
        var r = Dialog.Show(Application.Current.MainWindow, $"Remove {m.Name}?",
            "This deletes the mod and its settings from your game folder. Saves made with it stay untouched.", "Remove", "Cancel", danger: true);
        if (!r.Ok) return;
        try
        {
            ModLibrary.Remove(Game, m.Mod);
            LoadLibrary();
            Toast($"Removed {m.Name}", "info");
        }
        catch (UnauthorizedAccessException) { Dialog.Show(Application.Current.MainWindow, "Couldn't remove the mod", AccessMessage(), "OK"); }
        catch (IOException e) { Dialog.Show(Application.Current.MainWindow, "Couldn't remove the mod", e.Message + "\n\nIf the game is running, close it first.", "OK"); }
    }

    private void NewProfile()
    {
        var r = Dialog.Show(Application.Current.MainWindow, "New profile",
            "Profiles remember which mods are on and their order. The new profile starts as a copy of this one.", "Create", "Cancel", input: "");
        var name = r.Text?.Trim();
        if (!r.Ok || string.IsNullOrEmpty(name)) return;
        if (Profiles.Contains(name, StringComparer.OrdinalIgnoreCase)) { Toast("A profile with that name already exists", "error"); return; }
        SaveProfile();
        Store.SaveProfile(new Profile { Name = name, Mods = _profile.Mods.Select(e => new ProfileEntry { Id = e.Id, File = e.File, Enabled = e.Enabled }).ToList() });
        _config.ActiveProfile = name;
        LoadProfiles();
        LoadLibrary();
        Toast($"Switched to {name}", "success");
    }

    private void RenameProfile()
    {
        var old = ActiveProfile;
        var r = Dialog.Show(Application.Current.MainWindow, "Rename profile", "", "Rename", "Cancel", input: old);
        var name = r.Text?.Trim();
        if (!r.Ok || string.IsNullOrEmpty(name) || name == old) return;
        if (Profiles.Contains(name, StringComparer.OrdinalIgnoreCase) && !name.Equals(old, StringComparison.OrdinalIgnoreCase)) { Toast("A profile with that name already exists", "error"); return; }
        SaveProfile();
        var p = Store.LoadProfile(old);
        Store.DeleteProfile(old);
        p.Name = name;
        Store.SaveProfile(p);
        _config.ActiveProfile = name;
        LoadProfiles();
    }

    private void DeleteProfile()
    {
        if (Profiles.Count <= 1) return;
        var name = ActiveProfile;
        var r = Dialog.Show(Application.Current.MainWindow, $"Delete \"{name}\"?", "Your mods stay installed; only this profile's on/off choices and order are removed.", "Delete", "Cancel", danger: true);
        if (!r.Ok) return;
        Store.DeleteProfile(name);
        _config.ActiveProfile = Profiles.First(p => p != name);
        LoadProfiles();
        LoadLibrary();
    }

    // ------------------------------------------------------------ launching

    private void Play(bool vanilla)
    {
        if (Game == null) return;
        if (Launcher.IsRunning(Game)) { Toast("Road to Vostok is already running", "info"); return; }
        try
        {
            SaveProfile();
            var order = Mods.Select(m => (m.Mod, m.IsEnabled)).ToList();
            var steam = _config.LaunchViaSteam && Game.IsSteam;
            _awaitingReportSince = Launcher.Launch(Game, order, vanilla, steam);
            Raise(nameof(LoaderStatus));
            Toast(vanilla ? "Starting Road to Vostok without mods…" : "Starting Road to Vostok…", "info");
            if (_config.CloseOnLaunch) Application.Current.Shutdown();
        }
        catch (UnauthorizedAccessException)
        {
            Dialog.Show(Application.Current.MainWindow, "Cleanstrike can't write to the game folder", AccessMessage(), "OK");
        }
        catch (Exception e)
        {
            Log.Write("Launch failed: " + e);
            Dialog.Show(Application.Current.MainWindow, "The game didn't start", e.Message, "OK");
        }
    }

    private void Poll()
    {
        if (Game == null) return;
        IsRunning = Launcher.IsRunning(Game);
        if (_awaitingReportSince is { } since)
        {
            var report = Launcher.ReadReport(Game, since.AddSeconds(-2));
            if (report != null)
            {
                _awaitingReportSince = null;
                foreach (var m in Mods) m.ApplyReport(report.Mods.FirstOrDefault(r => r.Id == m.Mod.Id));
                AnnounceReport(report);
            }
            else if (DateTime.Now - since > TimeSpan.FromMinutes(3)) _awaitingReportSince = null;
        }
    }

    private void AnnounceReport(LaunchReport r)
    {
        if (r.SafeMode && r.SafeModeReason == "crash_guard")
        {
            Dialog.Show(Application.Current.MainWindow, "Started without mods",
                "The game crashed while starting twice in a row, so Cleanstrike started it without mods this time to keep you playing.\n\nTry switching off the mod you added most recently, then press Play again.", "OK");
            return;
        }
        if (r.SafeMode) return;
        var loaded = r.Mods.Count(m => m.Status == "loaded");
        var problems = r.Mods.Where(m => m.Status is "failed" or "incompatible" or "missing").ToList();
        if (problems.Count > 0)
            Toast(problems.Count == 1 ? $"{problems[0].Name} didn't load. Select it to see why" : $"{problems.Count} mods didn't load. Select them to see why", "error");
        else if (loaded > 0)
            Toast(loaded == 1 ? "Mod loaded in game" : $"All {loaded} mods loaded in game", "success");
    }

    private void UninstallFromGame()
    {
        if (Game == null) return;
        var r = Dialog.Show(Application.Current.MainWindow, "Remove Cleanstrike from the game?",
            "The game goes back to how it was before Cleanstrike (any previous override.cfg is restored). Your installed mods stay in the Cleanstrike folder for next time.", "Remove", "Cancel", danger: true);
        if (!r.Ok) return;
        try
        {
            LoaderInstaller.Uninstall(Game);
            Raise(nameof(LoaderStatus));
            Banner = LoaderInstaller.ForeignLoader(Game) is { } f ? $"{f} is back in charge of this game." : null;
            Toast("Cleanstrike removed from the game", "info");
        }
        catch (UnauthorizedAccessException) { Dialog.Show(Application.Current.MainWindow, "Couldn't remove Cleanstrike", AccessMessage(), "OK"); }
    }

    // ------------------------------------------------------------ helpers

    public void Toast(string text, string kind)
    {
        ToastText = text;
        ToastKind = kind;
        ToastVisible = true;
        _toastTimer.Stop();
        _toastTimer.Start();
    }

    private static void OpenFolder(string? path)
    {
        if (path == null) return;
        Directory.CreateDirectory(path);
        Process.Start(new ProcessStartInfo("explorer.exe", $"\"{path}\"") { UseShellExecute = true });
    }

    private void OpenLog()
    {
        if (Game == null) return;
        var path = File.Exists(Game.GameLogPath) ? Game.GameLogPath : Log.LogPath;
        if (!File.Exists(path)) { Toast("No log yet. Play once first", "info"); return; }
        Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
    }

    private void SaveConfig()
    {
        try { Store.SaveConfig(_config); } catch (Exception e) { Log.Write("Config save failed: " + e.Message); }
    }

    private static string AccessMessage() =>
        "Windows blocked Cleanstrike from changing files in the game folder. Close the game if it's running, or right-click Cleanstrike and choose \"Run as administrator\".";

    private static void CommandManagerRefresh() => System.Windows.Input.CommandManager.InvalidateRequerySuggested();
}
