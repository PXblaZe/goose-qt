// The comparison benchmark, in Goose through goose-qt. Same operations and counts as every other
// implementation (see ../README.md). Runs under the JIT and as a native build.
//   bench            the operations, one "RESULT <name> <value> <unit>" line each
//   bench --startup  start Qt, show a label, paint it once, exit (the runner times it)
import os;
import qt from "../../..";

let N = 200000;
let N_SIGNAL = 100000;
let N_OBJECTS = 50000;
let ROWS = 1000000;
let LINES = 100000;
let BUTTONS = 2000;
let T_ROWS: u64 = 1;
let T_COLS: u64 = 2;
let T_DATA: u64 = 3;

fn result(name: const u8[:], v: f64, unit: const u8[:]) { print("RESULT ", name, " ", v, " ", unit); }
fn ns_per(t0: i64, n: i64) -> f64 { return (clock_ns() - t0) / (n + 0.0); }
fn ms_since(t0: i64) -> f64 { return (clock_ns() - t0) / 1e6; }

export "goose_qt_override" fn on_override(obj: u64, tag: u64, nargs: i64, depth: i64) -> i32 {
    if tag == T_ROWS || tag == T_COLS {
        let rows = if tag == T_ROWS { ROWS } else { 1 };
        qt::ov_ret(if qt::ov_arg_index(0).valid { 0 } else { rows });
        return qt::OV_DONE;
    }
    if tag == T_DATA {
        if qt::ov_arg_int(1) != 0 { return qt::OV_BASE; }   // not Qt::DisplayRole
        qt::ov_ret(str("item ", qt::ov_arg_index(0).row));
        return qt::OV_DONE;
    }
    return qt::OV_BASE;
}

fn main() {
    var startup = false;
    for a in args() { if a == "--startup" { startup = true; } }
    if !qt::init(qt::APP_WIDGETS, "bench") { exit(1); }
    if startup {
        let hello = qt::QLabel("hello");
        hello.show();
        let pm = hello.grab();
        pm.free();
        qt::shutdown();
        return;
    }
    let label = qt::QLabel();
    let slider = qt::QSlider();
    slider.setMaximum(1 << 30);
    let button = qt::QPushButton("b");
    var sum = 0;
    var total = 0;

    for i in N / 10 { label.setText("hello"); }
    var t = clock_ns();
    for i in N { label.setText("hello"); }
    result("set_text", ns_per(t, N), "ns");

    t = clock_ns();
    for i in N { total += label.text().len; }
    result("get_text", ns_per(t, N), "ns");

    t = clock_ns();
    for i in N { slider.setValue(i); }
    result("set_value", ns_per(t, N), "ns");

    t = clock_ns();
    for i in N { sum += slider.value_int(); }
    result("get_value", ns_per(t, N), "ns");

    t = clock_ns();
    for i in N { qt::set(label, "text", "hello"); }
    result("set_property", ns_per(t, N), "ns");

    qt::connect(button, "clicked", 1);
    var ev = default<qt::Event>();
    var clicks = 0;
    t = clock_ns();
    for i in N_SIGNAL {
        button.click();
        while qt::poll(ev) { clicks++; }
    }
    result("signal", ns_per(t, N_SIGNAL), "ns");

    t = clock_ns();
    for i in N {
        let c = qt::QColor(255, 0, 0);
        sum += c.red();
        c.free();
    }
    result("value_type", ns_per(t, N), "ns");

    t = clock_ns();
    for i in N_OBJECTS { qt::destroy(qt::QObject()); }
    qt::process_events();   // qt::destroy deletes in the event loop: count that too
    result("object_churn", ns_per(t, N_OBJECTS), "ns");

    qt::use_overrides();
    let model = qt::new_overridable("QAbstractTableModel");
    qt::override(model, "rowCount", T_ROWS);
    qt::override(model, "columnCount", T_COLS);
    qt::override(model, "data", T_DATA);
    let proxy = qt::QSortFilterProxyModel();
    proxy.setSourceModel(model);
    t = clock_ns();
    proxy.setFilterFixedString("4242");
    let matches = proxy.rowCount();
    result("model_filter", ms_since(t), "ms");
    result("model_matches", matches + 0.0, "rows");

    let img = qt::QImage(1024, 1024, qt::QImage.Format_ARGB32);
    img.fill(0xffffffff);
    t = clock_ns();
    qt::draw_begin(img);
    qt::draw_pen(0xff000000, 1.0);
    for i in LINES {
        let x = (i * 7) % 1000;
        let y = (i * 13) % 1000;
        qt::draw_line(x + 0.0, y + 0.0, x + 8.0, y + 5.0);
    }
    qt::draw_end();
    result("paint_lines", ms_since(t), "ms");
    img.free();

    t = clock_ns();
    let win = qt::QWidget();
    let grid = qt::QGridLayout(win);
    for i in BUTTONS { grid.addWidget(qt::QPushButton(str("b ", i)), i / 40, i % 40); }
    win.show();
    let pm = win.grab();
    pm.free();
    qt::destroy(win);
    qt::process_events();
    result("widgets", ms_since(t), "ms");

    qt::shutdown();
    if clicks != N_SIGNAL || total == 0 || sum == 0 { exit(1); }
}
