using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;
using Cleanstrike.ViewModels;

namespace Cleanstrike.Views;

public sealed class InverseVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) => value is true ? Visibility.Collapsed : Visibility.Visible;
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}

public sealed class StatusBrushConverter : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) => value switch
    {
        ModStatusKind.Loaded => Application.Current.FindResource("Success"),
        ModStatusKind.Problem => Application.Current.FindResource("Danger"),
        _ => Application.Current.FindResource("Faint"),
    };
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}

public sealed class StatusIconConverter : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) => value switch
    {
        ModStatusKind.Loaded => "",   // check
        ModStatusKind.Problem => "",  // warning
        _ => "",
    };
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}

public sealed class ToastBrushConverter : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) => value switch
    {
        "success" => Application.Current.FindResource("Success"),
        "error" => Application.Current.FindResource("Danger"),
        _ => Application.Current.FindResource("Accent"),
    };
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => throw new NotSupportedException();
}
