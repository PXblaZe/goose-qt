// chaos: stability under abuse. A seeded random driver creates and destroys widgets, nests and
// reparents them, calls their methods with hostile arguments (extreme integers, NaN, huge and
// empty strings, objects already destroyed, forged handles), reads and writes properties that
// exist and some that do not, frees values twice, connects signals and floods the event queue.
// Every misuse comes back as an error code; the program counts them and checks at the end that
// nothing leaked: every object and value it made is gone.
//
//   goose chaos.goose                         100,000 operations, seed 1
//   goose chaos.goose -- --ops 2000000 --seed 7
//   goose chaos.goose -- --selftest           20,000 operations, then the checks
import os;
import qt from "../..";

let CLASSES: const u8[:][] = ["QWidget", "QLabel", "QPushButton", "QLineEdit", "QSlider", "QSpinBox",
    "QComboBox", "QListWidget", "QTextEdit", "QProgressBar", "QCheckBox", "QGroupBox", "QTabWidget",
    "QScrollArea", "QSplitter", "QTableWidget", "QTreeWidget", "QMainWindow", "QFrame", "QDial",
    "QPlainTextEdit", "QToolButton", "QStackedWidget", "QCalendarWidget", "QLCDNumber"];

// methods that many widget classes have, so that the calls reach real code more often than not
let METHODS: const u8[:][] = ["setText", "setValue", "setMaximum", "setMinimum", "resize", "move", "show",
    "hide", "setEnabled", "setWindowTitle", "addItem", "setCurrentIndex", "setRowCount", "setColumnCount",
    "setParent", "setFocus", "raise", "lower", "adjustSize", "update", "setStyleSheet", "setToolTip",
    "setMinimumSize", "setFixedWidth", "clear", "insertItem", "removeItem", "setRange", "setOrientation",
    "addTab", "setWidget", "setCurrentWidget", "addWidget", "setPlainText", "setHtml", "scroll",
    "setGeometry", "setVisible", "setMaximumHeight", "setPlaceholderText", "setChecked", "setReadOnly",
    "setDisabled", "repaint", "close", "setCentralWidget", "setDigitCount", "display", "setNotchesVisible",
    "noSuchMethod", "deleteLater"];

let PROPERTIES: const u8[:][] = ["text", "value", "maximum", "minimum", "windowTitle", "enabled", "visible",
    "geometry", "toolTip", "styleSheet", "objectName", "currentIndex", "checked", "readOnly", "plainText",
    "minimumWidth", "maximumHeight", "windowOpacity", "orientation", "noSuchProperty", "size", "pos"];

let VALUES: const u8[:][] = ["QColor", "QFont", "QRect", "QPoint", "QSize", "QDate", "QDateTime", "QUrl",
    "QImage", "QPixmap", "QIcon", "QKeySequence", "QPen", "QBrush", "QPolygon", "QRegion", "QTransform"];

let VALUE_METHODS: const u8[:][] = ["isValid", "isNull", "width", "height", "name", "toString", "setWidth",
    "setRed", "translate", "scaled", "fill", "addDays", "setX", "boundingRect", "inverted", "rotate",
    "toImage", "lighter", "united", "noSuchMethod"];

let STRINGS: const u8[:][] = ["", "x", "Hello, chaos", "%s%n%x%p", "\x00\x01\xff", "<b>bold</b>", "a/../b/",
    "qtc \xf0\x9f\x98\x80 emoji", "\xc3\x28 invalid UTF-8", "QWidget { color: red }"];

let INTS: i64[] = [0, 1, -1, 2, 7, 100, 4096, 65535, -65536, 2147483647, -2147483648, 9223372036854775807,
                   -9223372036854775807];

var r = rng { s: 1 };
var objects: qt::Obj[>..] = [];   // made by this program, alive or not
var values: qt::Val[>..] = [];    // live values
var freed: qt::Val[>..] = [];     // values freed already
var connections: u64[>..] = [];
var counts: i64[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];   // OK, then -1 .. -19, other
var ops = 0;

fn pick(n: i64) -> i64 { return rand_int(r, n); }
fn chance(percent: i64) -> bool { return pick(100) < percent; }

fn tally() {
    let e = qt::last_error();
    if e == qt::OK { counts[0]++; } else if e < 0 && e >= -19 { counts[0 - e]++; } else { counts[20]++; }
    qt::clear_error();
}

fn some_object() -> qt::Obj {
    if objects.len == 0 || chance(3) {
        // a forged handle, or none at all
        if chance(50) { return qt::NONE; }
        return qt::Obj { h: rand_u64(r) };
    }
    return objects[pick(objects.len)];
}

fn some_string() -> u8[>..] {
    if chance(2) {
        var big: u8[>..] = [];
        for i in 100000 { big.push(65 + (i % 26) as u8); }
        return big;
    }
    return str(STRINGS[pick(STRINGS.len)]);
}

fn some_int() -> i64 {
    if chance(50) { return INTS[pick(INTS.len)]; }
    return pick(1000) - 100;
}

fn push_args(n: i64) {
    for _ in n {
        let k = pick(8);
        if k == 0 { qt::arg(some_string()); }
        else if k == 1 { qt::arg(some_object()); }
        else if k == 2 { qt::arg(if chance(50) { 0.0 / 0.0 } else { rand_flt(r) * 1e6 - 5e5 }); }
        else if k == 3 { qt::arg(chance(50)); }
        else if k == 4 && values.len > 0 { qt::arg(values[pick(values.len)]); }
        else if k == 5 { qt::arg_null(); }
        else { qt::arg(some_int()); }
    }
}

fn create() {
    let o = qt::new_object(CLASSES[pick(CLASSES.len)]);
    tally();
    if !qt::alive(o) { return; }
    objects.push(o);
    if objects.len > 1 && chance(60) {
        // nest it in another one: trees get deep and wide, and go when their root goes
        qt::arg(objects[pick(objects.len)]);
        qt::call(o, "setParent(QWidget*)");
        tally();
    }
}

fn destroy_one() {
    if objects.len == 0 { return; }
    qt::destroy(objects[pick(objects.len)]);   // its children go with it; destroying twice is refused
    tally();
}

fn call_method() {
    let o = some_object();
    push_args(pick(4));
    qt::call(o, METHODS[pick(METHODS.len)]);
    tally();
}

fn touch_property() {
    let o = some_object();
    let name = PROPERTIES[pick(PROPERTIES.len)];
    let k = pick(4);
    if k == 0 { qt::set(o, name, some_string()); }
    else if k == 1 { qt::set(o, name, some_int()); }
    else if k == 2 { let s = qt::get_str(o, name); if s.len < 0 { print(""); } }
    else { let v = qt::get_val(o, name); tally(); if qt::alive(v) { qt::free(v); } }
    tally();
}

fn value_op() {
    let k = pick(6);
    if k <= 1 {
        push_args(pick(3));
        let v = qt::new_value(VALUES[pick(VALUES.len)]);
        tally();
        if qt::alive(v) { values.push(v); }
    } else if k == 2 && values.len > 0 {
        push_args(pick(3));
        qt::call(values[pick(values.len)], VALUE_METHODS[pick(VALUE_METHODS.len)]);
        tally();
        if qt::ret_kind() == qt::T_VALUE { let rv = qt::ret_val(); if qt::alive(rv) { qt::free(rv); } }
    } else if k == 3 && values.len > 0 {
        let i = pick(values.len);
        qt::free(values[i]);
        tally();
        freed.push(values[i]);
        values[i] = values[values.len - 1];
        values.pop();
    } else if k == 4 && freed.len > 0 {
        qt::free(freed[pick(freed.len)]);   // a double free: refused
        tally();
    } else {
        let v = qt::from_json(if chance(50) { "{\"a\": [1, 2.5, \"x\", null, {\"b\": true}]}" } else { "{not json" });
        tally();
        if qt::alive(v) { values.push(v); }
    }
}

fn signal_op() {
    if chance(70) {
        let c = qt::connect(some_object(), if chance(50) { "destroyed" } else { "objectNameChanged" }, 7,
                            if chance(50) { qt::CONN_COALESCE } else { 0 });
        tally();
        if c != 0 { connections.push(c); }
    } else if connections.len > 0 {
        let i = pick(connections.len);
        qt::disconnect(connections[i]);   // a second disconnect of the same one is refused
        tally();
    }
}

fn drain() {
    qt::process_events();
    var ev = default<qt::Event>();
    while qt::poll(ev) {}
}

fn main() {
    var selftest = false;
    var total = -1;
    var seed = 1;
    var prev = str("");
    for a in args() {
        if a == "--selftest" { selftest = true; }
        if prev == "--ops" { let n, ok = parse_int(a); if ok { total = n; } }
        if prev == "--seed" { let n, ok = parse_int(a); if ok { seed = n; } }
        prev = str(a);
    }
    if total < 0 { total = if selftest { 20000 } else { 100000 }; }
    r.s = seed as u64;
    if !qt::init(qt::APP_WIDGETS, "chaos\0-platform\0offscreen") {
        print("qt::init: ", qt::last_error_message());
        exit(1);
    }
    qt::set_error_policy(qt::ERRORS_RETURN);   // misuse is the point: count it, do not log it
    qt::set_quit_on_last_window_closed(false);
    qt::set_queue_limit(10000);
    let objects0 = qt::live_objects();
    let values0 = qt::live_values();

    let t0 = clock_ns();
    while ops < total {
        let k = pick(100);
        if k < 22 { create(); }
        else if k < 32 { destroy_one(); }
        else if k < 62 { call_method(); }
        else if k < 77 { touch_property(); }
        else if k < 90 { value_op(); }
        else if k < 96 { signal_op(); }
        else if k < 98 { for i in 2000 { qt::post(9, i, 0); } tally(); }   // a flood past the queue limit
        else { drain(); }
        ops++;
        if objects.len > 400 {
            // keep the working set bounded: destroy the oldest half
            let half = objects.len / 2;
            for i in half { qt::destroy(objects[i]); qt::clear_error(); }
            for i in objects.len - half { objects[i] = objects[i + half]; }
            for _ in half { objects.pop(); }
        }
    }
    let seconds = (clock_ns() - t0) as f64 / 1e9;
    drain();

    // everything this program made goes: objects (children with their parents), values
    for o in objects { qt::destroy(o); }
    for v in values { qt::free(v); }
    for c in connections { qt::disconnect(c); }
    qt::clear_error();
    drain();
    let leaked_objects = qt::live_objects() - objects0;
    let leaked_values = qt::live_values() - values0;

    print("chaos: ", ops, " operations in ", seconds, " s (", (ops / seconds) as i64, " per second), seed ", seed);
    print("  calls by result:");
    print("  succeeded            ", counts[0]);
    for e in 19 {
        let n = counts[e + 1];
        if n > 0 {
            var name = qt::status_name(0 - (e + 1));
            while name.len < 21 { name.push(' '); }
            print("  ", name, n);
        }
    }
    if counts[20] > 0 { print("  other                ", counts[20]); }
    print("  events dropped past the queue limit: ", qt::dropped_events());
    print("  left over: ", leaked_objects, " objects, ", leaked_values, " values");
    let ok = leaked_objects == 0 && leaked_values == 0 && counts[0] > 0 && counts[4] > 0;
    print("chaos: ", if ok { "ok" } else { "FAIL" });
    qt::shutdown();
    if !ok { exit(1); }
}
