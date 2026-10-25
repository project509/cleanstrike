using System.Windows;
using System.Windows.Input;

namespace Cleanstrike.Views;

/// <summary>Themed replacement for MessageBox, with an optional text input.</summary>
public partial class Dialog : Window
{
    public readonly record struct Result(bool Ok, string? Text);

    private bool _ok;

    private Dialog() => InitializeComponent();

    public static Result Show(Window? owner, string title, string message, string primary,
        string? secondary = null, string? input = null, bool danger = false)
    {
        var d = new Dialog();
        if (owner is { IsLoaded: true }) d.Owner = owner;
        else d.WindowStartupLocation = WindowStartupLocation.CenterScreen;
        d.TitleText.Text = title;
        d.MessageText.Text = message;
        d.MessageText.Visibility = string.IsNullOrEmpty(message) ? Visibility.Collapsed : Visibility.Visible;
        d.PrimaryButton.Content = primary;
        if (danger) d.PrimaryButton.Style = (Style)d.FindResource("Btn.Danger");
        if (secondary == null)
        {
            d.SecondaryButton.Visibility = Visibility.Collapsed;
            d.PrimaryButton.IsCancel = true;
        }
        else d.SecondaryButton.Content = secondary;
        if (input != null)
        {
            d.Input.Text = input;
            d.Input.Visibility = Visibility.Visible;
            d.Loaded += (_, _) => { d.Input.Focus(); d.Input.SelectAll(); };
        }
        d.MouseLeftButtonDown += (_, e) => { if (e.ButtonState == MouseButtonState.Pressed) d.DragMove(); };
        d.ShowDialog();
        return new Result(d._ok, input != null ? d.Input.Text : null);
    }

    private void OnPrimary(object sender, RoutedEventArgs e)
    {
        _ok = true;
        Close();
    }

    private void OnSecondary(object sender, RoutedEventArgs e) => Close();
}
