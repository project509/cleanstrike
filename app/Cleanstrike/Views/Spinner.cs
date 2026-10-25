using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;

namespace Cleanstrike.Views;

/// <summary>A thin rotating arc, drawn in the accent colour.</summary>
public sealed class Spinner : FrameworkElement
{
    private readonly RotateTransform _rotate = new();

    public Spinner()
    {
        RenderTransform = _rotate;
        RenderTransformOrigin = new Point(0.5, 0.5);
        Loaded += (_, _) => _rotate.BeginAnimation(RotateTransform.AngleProperty,
            new DoubleAnimation(0, 360, TimeSpan.FromSeconds(0.9)) { RepeatBehavior = RepeatBehavior.Forever });
        Unloaded += (_, _) => _rotate.BeginAnimation(RotateTransform.AngleProperty, null);
    }

    protected override void OnRender(DrawingContext dc)
    {
        double r = Math.Min(ActualWidth, ActualHeight) / 2 - 2;
        var c = new Point(ActualWidth / 2, ActualHeight / 2);
        dc.DrawEllipse(null, new Pen(new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)), 2.5), c, r, r);
        var accent = (Brush)Application.Current.FindResource("Accent");
        var start = new Point(c.X, c.Y - r);
        var end = new Point(c.X + r * Math.Sin(Math.PI * 0.6), c.Y - r * Math.Cos(Math.PI * 0.6));
        var g = new StreamGeometry();
        using (var ctx = g.Open())
        {
            ctx.BeginFigure(start, false, false);
            ctx.ArcTo(end, new Size(r, r), 0, false, SweepDirection.Clockwise, true, false);
        }
        dc.DrawGeometry(null, new Pen(accent, 2.5) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round }, g);
    }
}
