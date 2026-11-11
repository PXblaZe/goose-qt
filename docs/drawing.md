# Drawing

goose-qt draws with `QPainter` through a recording API: `qt::draw_begin(target)`, a series of
`qt::draw_*` calls, then `qt::draw_end()`. There are three kinds of target:

| Target | What happens |
|---|---|
| a `QtcCanvas` widget | the recording replaces what the canvas paints; it repaints from it whenever Qt asks, with no Goose code running |
| a `QImage` or `QPixmap` value | the commands paint into it at `draw_end()` |
| the widget whose `paintEvent` you override | the commands paint the widget, inside Qt's paint call |

Colours are `0xAARRGGBB` (`0xffff0000` is opaque red); coordinates are `f64` in the target's
pixels.

## A canvas

```goose
let canvas = qt::new_object("QtcCanvas");
canvas.resize(400, 300);
canvas.show();
if qt::draw_begin(canvas) {
    qt::draw_clear(0xff1e2430);
    qt::draw_antialias(true);
    qt::draw_pen(0xffffffff, 2.0);
    qt::draw_line(0.0, 0.0, 400.0, 300.0);
    qt::draw_no_pen();
    qt::draw_brush(0xffffcc33);
    qt::draw_ellipse(180.0, 130.0, 40.0, 40.0);
    qt::draw_font("Sans", 14.0);
    qt::draw_pen(0xffffffff, 1.0);
    qt::draw_text_in(0.0, 0.0, 400.0, 40.0, qt::Qt.AlignCenter, "hello");
    qt::draw_end();
}
```

To animate, record again: each `draw_begin(canvas) … draw_end()` replaces the previous
picture. Watch the canvas for mouse events to make it interactive
([Events](events.md#input-events-from-any-widget)); the
[canvas example](../examples/canvas.goose) drops a dot where you click.

## Into an image

```goose
let img = qt::QImage(256, 256, qt::QImage.Format_ARGB32);
if qt::draw_begin(img) {
    qt::draw_clear(0xff000000);
    qt::draw_pen(0xff40e0a0, 3.0);
    qt::draw_rounded_rect(20.0, 20.0, 216.0, 216.0, 16.0, 16.0);
    qt::draw_end();
}
img.save("out.png");
img.free();
```

## Inside paintEvent

When a widget subclassed in Goose overrides `paintEvent`, the override draws on the widget
itself; this is what the [scope sample](../samples/scope/scope.goose) does at 94 frames a
second:

```goose
export "goose_qt_override" fn on_override(obj: u64, tag: u64, nargs: i64, depth: i64) -> i32 {
    if tag == T_PAINT {
        qt::draw_begin(qt::Obj { h: obj });
        qt::draw_clear(0xff10141c);
        qt::draw_pen(0xff40e0a0, 1.5);
        qt::draw_polyline(points);         // x0, y0, x1, y1, ... as one f64 array
        qt::draw_end();
        return qt::OV_DONE;
    }
    return qt::OV_BASE;
}
```

Methods that receive a `QPainter *` (`QGraphicsItem::paint`, `QStyledItemDelegate::paint`,
`QGraphicsView::drawBackground`) draw with that painter instead:
`qt::draw_begin_painter(0)` (the argument's index), then the same calls and `draw_end()`.
See [Subclassing](subclassing.md).

## The calls

| Group | Calls |
|---|---|
| state | `draw_clear(argb)`, `draw_antialias(on)`, `draw_opacity(o)`, `draw_save()`, `draw_restore()` |
| pen and brush | `draw_pen(argb, width)`, `draw_pen(argb, width, style, cap, join)`, `draw_no_pen()`, `draw_brush(argb)`, `draw_brush(argb, style)`, `draw_no_brush()`, `draw_linear_gradient(x1, y1, x2, y2, argb1, argb2)` |
| transform and clip | `draw_translate(dx, dy)`, `draw_rotate(degrees)`, `draw_scale(sx, sy)`, `draw_clip_rect(x, y, w, h)` |
| shapes | `draw_point`, `draw_line`, `draw_rect`, `draw_rounded_rect`, `draw_ellipse`, `draw_arc`, `draw_pie` (angles in degrees), `draw_polyline(xy)`, `draw_polygon(xy)` |
| paths | `draw_path_move`, `draw_path_line`, `draw_path_quad`, `draw_path_cubic`, `draw_path_close`, then `draw_path_end()` draws it with the current pen and brush |
| text | `draw_font(family, points)`, `draw_font(family, points, weight, italic)`, `draw_text(x, y, text)` (baseline at y), `draw_text_in(x, y, w, h, flags, text)` |
| images | `draw_image(image, x, y, w, h)` |
| counting | `draw_count()`: commands in the current recording |

Pen styles, caps and joins are Qt's numbers (`qt::Qt.DashLine`, `qt::Qt.RoundCap`,
`qt::Qt.RoundJoin`); text flags are alignment flags (`qt::Qt.AlignCenter`) and
`qt::Qt.TextWordWrap`.

A recording is checked as it is made: coordinates must be finite and within ±10⁹, pen widths
and font sizes sane, and paths small enough to flatten; anything else is refused with
`qt::ERR_OUT_OF_RANGE`, so a bug in the drawing code cannot take Qt's rasterizer down.
For GPU rendering, see [Graphics](graphics.md).
