using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using Cleanstrike.Services;
using Cleanstrike.ViewModels;

namespace Cleanstrike.Views;

public partial class MainWindow : Window
{
    private Point _dragStart;
    private ModItemViewModel? _dragItem;

    public MainWindow()
    {
        InitializeComponent();
        StateChanged += (_, _) => OnStateChanged();
        DragEnter += OnFileDragEnter;
        DragLeave += (_, _) => DropOverlay.Visibility = Visibility.Collapsed;
        DragOver += OnFileDragOver;
        Drop += OnFileDrop;
        Vm.PropertyChanged += OnVmChanged;
    }

    private MainViewModel Vm => (MainViewModel)DataContext;

    // ------------------------------------------------------------ chrome

    private void OnMinimize(object s, RoutedEventArgs e) => WindowState = WindowState.Minimized;
    private void OnMaximize(object s, RoutedEventArgs e) => WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;
    private void OnClose(object s, RoutedEventArgs e) => Close();

    private void OnStateChanged()
    {
        // A maximized chromeless window overhangs the screen by the resize border.
        Frame.Margin = WindowState == WindowState.Maximized ? new Thickness(7) : new Thickness(0);
        Frame.BorderThickness = WindowState == WindowState.Maximized ? new Thickness(0) : new Thickness(1);
        MaxGlyph.Text = WindowState == WindowState.Maximized ? "" : "";
    }

    private void OnGameChip(object sender, RoutedEventArgs e) => OpenMenu((Button)sender);
    private void OnProfileMenu(object sender, RoutedEventArgs e) => OpenMenu((Button)sender);

    private static void OpenMenu(Button b)
    {
        if (b.ContextMenu == null) return;
        b.ContextMenu.PlacementTarget = b;
        b.ContextMenu.DataContext = b.DataContext;
        b.ContextMenu.IsOpen = true;
    }

    // ------------------------------------------------------------ toast

    private void OnVmChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName != nameof(MainViewModel.ToastVisible)) return;
        var show = Vm.ToastVisible;
        var ease = new CubicEase { EasingMode = EasingMode.EaseOut };
        var d = TimeSpan.FromMilliseconds(show ? 200 : 260);
        Toast.BeginAnimation(OpacityProperty, new DoubleAnimation(show ? 1 : 0, d) { EasingFunction = ease });
        ToastShift.BeginAnimation(TranslateTransform.YProperty, new DoubleAnimation(show ? 0 : 8, d) { EasingFunction = ease });
    }

    // ------------------------------------------------------------ install by drag & drop

    private static string[]? DroppedFiles(DragEventArgs e) =>
        e.Data.GetDataPresent(DataFormats.FileDrop) ? e.Data.GetData(DataFormats.FileDrop) as string[] : null;

    private void OnFileDragEnter(object sender, DragEventArgs e)
    {
        if (DroppedFiles(e) != null && Vm.IsReady) DropOverlay.Visibility = Visibility.Visible;
    }

    private void OnFileDragOver(object sender, DragEventArgs e)
    {
        if (DroppedFiles(e) != null)
        {
            e.Effects = Vm.IsReady ? DragDropEffects.Copy : DragDropEffects.None;
            e.Handled = true;
        }
    }

    private void OnFileDrop(object sender, DragEventArgs e)
    {
        DropOverlay.Visibility = Visibility.Collapsed;
        var files = DroppedFiles(e);
        if (files == null || !Vm.IsReady) return;
        e.Handled = true;
        Activate();
        Vm.InstallFiles(files);
    }

    // ------------------------------------------------------------ reorder by drag

    private void OnListMouseDown(object sender, MouseButtonEventArgs e)
    {
        _dragItem = null;
        if (e.OriginalSource is FrameworkElement { Tag: "grip" } grip && grip.DataContext is ModItemViewModel m)
        {
            _dragItem = m;
            _dragStart = e.GetPosition(ModList);
        }
    }

    private void OnListMouseMove(object sender, MouseEventArgs e)
    {
        if (_dragItem == null || e.LeftButton != MouseButtonState.Pressed) return;
        var p = e.GetPosition(ModList);
        if (Math.Abs(p.Y - _dragStart.Y) < SystemParameters.MinimumVerticalDragDistance) return;
        var item = _dragItem;
        _dragItem = null;
        DragDrop.DoDragDrop(ModList, new DataObject(typeof(ModItemViewModel), item), DragDropEffects.Move);
    }

    private void OnListDragOver(object sender, DragEventArgs e)
    {
        if (!e.Data.GetDataPresent(typeof(ModItemViewModel))) return;
        e.Effects = DragDropEffects.Move;
        e.Handled = true;
        if (e.Data.GetData(typeof(ModItemViewModel)) is not ModItemViewModel dragged) return;
        // Live reorder while hovering, so the list shows where the mod will land.
        var target = ItemUnder(e.GetPosition(ModList));
        if (target != null && target != dragged) Vm.Move(dragged, Vm.Mods.IndexOf(target));
    }

    private void OnListDrop(object sender, DragEventArgs e)
    {
        if (e.Data.GetData(typeof(ModItemViewModel)) is ModItemViewModel dragged)
        {
            Vm.Selected = dragged;
            e.Handled = true;
        }
    }

    private ModItemViewModel? ItemUnder(Point p)
    {
        var hit = ModList.InputHitTest(p) as DependencyObject;
        while (hit != null && hit is not ListBoxItem) hit = VisualTreeHelper.GetParent(hit);
        return (hit as ListBoxItem)?.DataContext as ModItemViewModel;
    }

    private void OnListKeyDown(object sender, KeyEventArgs e)
    {
        if (Vm.Selected == null) return;
        if (Keyboard.Modifiers == ModifierKeys.Alt && e.SystemKey is Key.Up or Key.Down)
        {
            var i = Vm.Mods.IndexOf(Vm.Selected) + (e.SystemKey == Key.Up ? -1 : 1);
            Vm.Move(Vm.Selected, i);
            e.Handled = true;
        }
        else if (e.Key == Key.Space)
        {
            Vm.Selected.IsEnabled = !Vm.Selected.IsEnabled;
            e.Handled = true;
        }
        else if (e.Key == Key.Delete)
        {
            Vm.RemoveModCommand.Execute(Vm.Selected);
            e.Handled = true;
        }
    }

    protected override void OnClosed(EventArgs e)
    {
        Log.Write("App closed");
        base.OnClosed(e);
    }
}
