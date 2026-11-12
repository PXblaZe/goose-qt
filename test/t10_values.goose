// Small value types as structs (values.goose, qtc_inline.h): no handle, the same checks.
import qt from "..";

var failures = 0;
var checks = 0;
fn check(ok: bool, what: const u8[:]) {
    checks++;
    if !ok {
        failures++;
        print("FAIL ", what, "  [", qt::last_error_message(), "]");
    }
}

fn main() {
    qt::set_error_policy(qt::ERRORS_RETURN);
    // usable before qt::init: they touch no application state
    let early = qt::point(3, -4);
    check(early.manhattanLength() == 7, "before init");
    check(qt::init(qt::APP_WIDGETS, "t10\0-platform\0offscreen"), "init");
    qt::set_error_policy(qt::ERRORS_RETURN);

    // geometry
    var r = qt::rect(1, 2, 3, 4);
    check(r.x1 == 1 && r.y2 == 5, "fields: Qt keeps the far corner");
    check(r.right() == 3 && r.width() == 3 && r.height() == 4, "getters");
    r.moveTo(10, 20);
    check(r.x() == 10 && r.y() == 20 && r.width() == 3, "moveTo changes it in place");
    let t = r.translated(1, 1);
    check(t.x() == 11 && r.x() == 10, "translated makes a copy");
    check(r.intersects(t), "intersects");
    check(r.contains(qt::point(11, 21)), "contains a point");
    let rf = qt::rectf(r);
    check(rf.width() == 3.0, "RectF from Rect");
    let c0 = r.center();
    check(c0.x() == 11 && c0.y() == 21, "center is a Point");
    let s = qt::size(640, 480);
    check(s.width() == 640 && !s.isEmpty(), "size");
    let m = qt::margins(1, 2, 3, 4);
    check(m.left() == 1 && m.bottom() == 4, "margins");
    let ln = qt::linef(0.0, 0.0, 3.0, 4.0);
    check(ln.length() == 5.0, "LineF length");

    // colors
    var c = qt::color(255, 10, 20);
    check(c.red() == 255 && c.green() == 10 && c.blue() == 20, "rgb");
    c.setRed(7);
    check(c.red() == 7, "setRed in place");
    let h = qt::color_fromHsv(120, 255, 255);
    check(h.hue() == 120 && h.green() == 255, "fromHsv");
    check(h.toRgb().green() == 255, "toRgb");

    // checks
    let bad = qt::rect(10000000000, 0, 1, 1);
    check(qt::last_error() == qt::ERR_OUT_OF_RANGE && bad.x1 == 0, "int out of range");
    var junk = c;
    junk.spec = 99;
    check(junk.red() == 0 && qt::last_error() == qt::ERR_INVALID_ARG, "a color qtc did not make");
    check(c.red() == 7 && qt::last_error() == 0, "a good one after it");

    // objects take them
    let w = qt::QWidget();
    w.setGeometry(qt::rect(5, 6, 70, 80));
    let g = qt::to_rect(w.geometry());
    check(g.x() == 5 && g.width() == 70, "setGeometry(Rect), geometry back as a Rect");
    w.move(qt::point(9, 8));
    check(w.x() == 9 && w.y() == 8, "move(Point)");
    w.setGeometry(junk_rect());
    check(qt::last_error() == 0, "a rect from a helper");
    qt::arg(qt::rect(1, 1, 50, 50));
    check(qt::call(w, "setGeometry"), "as a qt::call argument");
    check(qt::call(w, "pos") && qt::ret_point().x() == 1, "ret_point");
    let v = c.to_val();
    check(v.red() == 7, "to_val: the Val form works too");
    check(qt::to_color(v).red() == 7, "and back");
    qt::free(v);
    qt::destroy(w);
    check(qt::shutdown(), "shutdown");
    print("t10_values: ", checks - failures, " passed, ", failures, " failed");
    if failures > 0 { exit(1); }
}

fn junk_rect() -> qt::Rect { return qt::rect(0, 0, 10, 10); }
