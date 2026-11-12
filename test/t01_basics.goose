// Objects, properties, methods, values, strings, enums and misuse.
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
    check(!qt::is_initialized(), "not initialized yet");
    check(qt::init(qt::APP_WIDGETS, "t01\0-platform\0offscreen"), "init");
    check(qt::is_initialized(), "initialized");
    qt::set_error_policy(qt::ERRORS_RETURN);
    check(qt::version() == "1.5.0", "qtc version");
    check(qt::qt_version().len >= 5, "qt version");

    // objects and properties
    let win = qt::QWidget();
    check(qt::alive(win), "window alive");
    check(qt::class_name(win) == "QWidget", "class name");
    win.setWindowTitle("Hello");
    check(win.windowTitle() == "Hello", "windowTitle round trip");
    check(qt::set(win, "minimumWidth", 120), "set property");
    check(qt::get_int(win, "minimumWidth") == 120, "get property");
    // typed getters picked by type argument
    check(win.prop<i64>("minimumWidth") == 120, "prop<i64>");
    check(win.prop<u8[]>("windowTitle") == "Hello", "prop<u8[]>");
    check(win.prop<bool>("enabled"), "prop<bool>");
    check(win.prop<f64>("windowOpacity") == 1.0, "prop<f64>");
    let geo = win.prop<qt::Val>("geometry");
    check(geo.h != 0, "prop<Val>");
    qt::free(geo);
    check(qt::call(win, "width") && qt::ret<i64>() == win.width(), "ret<i64>");
    check(qt::call(win, "windowTitle") && qt::ret<u8[]>() == "Hello", "ret<u8[]>");
    check(!qt::set(win, "noSuchProperty", 1), "unknown property refused");
    check(qt::last_error() == qt::ERR_NOT_FOUND, "unknown property error");

    let label = qt::QLabel("first", win);
    check(label.text() == "first", "constructor argument");
    label.setText("Goose \xf0\x9f\xa6\xa2 \xe4\xbd\xa0\xe5\xa5\xbd");
    check(label.text() == "Goose \xf0\x9f\xa6\xa2 \xe4\xbd\xa0\xe5\xa5\xbd", "utf-8 round trip");
    label.setText("");
    check(label.text().len == 0, "empty string");
    var long: u8[>..] = [];
    for i in 100000 { long.push('x'); }
    label.setText(long);
    check(label.text().len == 100000, "long string");
    label.setAlignment(qt::Qt.AlignRight | qt::Qt.AlignVCenter);
    check(label.alignment() == qt::Qt.AlignRight | qt::Qt.AlignVCenter, "flags");
    label.setAlignment(1073741824);
    check(qt::last_error() == qt::ERR_OUT_OF_RANGE, "invalid flags refused");
    check(label.parentWidget().h == win.h, "parent is the same handle");
    check(qt::inherits(label, "QFrame"), "inherits");

    // overloads resolved by type: QSpinBox::setValue(int), QDoubleSpinBox::setValue(double)
    let spin = qt::QSpinBox(win);
    spin.setMaximum(500);
    spin.setValue(42);
    check(spin.value() == 42.0, "int setValue");
    let dspin = qt::QDoubleSpinBox(win);
    dspin.setValue(2.5);
    check(dspin.value() == 2.5, "double setValue");
    spin.setValue(10000000000);
    check(qt::last_error() == qt::ERR_OUT_OF_RANGE, "integer range checked");

    let combo = qt::QComboBox(win);
    combo.addItem("one");
    let data = qt::val(42);
    combo.addItem("two", data);
    check(combo.count() == 2, "addItem overloads");
    let back = combo.itemData(1);
    check(back.to_int() == 42, "itemData value");
    back.free();
    data.free();
    check(combo.itemText(0) == "one", "itemText");

    // statics and values
    qt::QCoreApplication_setApplicationName("goose-tests");
    check(qt::QCoreApplication_applicationName() == "goose-tests", "static call");
    let red = qt::QColor(255, 0, 0, 255);
    check(red.name() == "#ff0000", "QColor value");
    red.setGreen(128);
    check(red.green() == 128, "value method");
    let copy = qt::clone(red);
    check(qt::equal(red, copy), "value copy equal");
    let s = qt::val("123");
    check(s.toInt() == 123, "QString method on a string value");
    let hex = qt::val("ff");
    check(hex.toInt(16) == 255, "out-parameter skipped, base passed");
    check(qt::out_count() == 1 && qt::out_bool(0), "bool *ok reported true");
    let bad = qt::val("zz");
    check(bad.toInt(16) == 0 && !qt::out_bool(0), "bool *ok reported false");
    red.getRgb();
    check(qt::out_count() == 4 && qt::out_int(0) == 255 && qt::out_int(1) == 128 && qt::out_int(2) == 0 && qt::out_int(3) == 255,
          "four int* out-parameters");
    check(bad.toInt(1) == 0 && qt::last_error() == qt::ERR_OUT_OF_RANGE, "invalid base refused");
    let big = qt::val("x");
    big.fill("y", 1000000000000);
    check(qt::last_error() == qt::ERR_LIMIT, "huge allocation refused");
    let list = qt::new_list();
    qt::list_append(list, red);
    qt::list_append(list, label);
    check(qt::list_len(list) == 2, "list");
    let first = qt::list_get(list, 1);
    check(first.to_obj().h == label.h, "object in a list");
    let j = qt::from_json("{\"a\": [1, 2, 3], \"b\": \"x\"}");
    check(qt::map_len(j) == 2, "json map");
    check(qt::json(j) == "{\"a\":[1,2,3],\"b\":\"x\"}", "json round trip");
    for v in [red, copy, s, hex, bad, big, list, first, j] { v.free(); }
    check(qt::live_values() == 0, "all values freed");

    // misuse is an error, never a crash
    qt::destroy(win);
    check(!qt::alive(win), "destroyed handle is stale at once");
    win.setWindowTitle("gone");
    check(qt::last_error() == qt::ERR_STALE_HANDLE, "stale receiver");
    qt::process_events();
    check(!qt::alive(label), "children go with the parent");
    check(label.text().len == 0, "stale call returns a default");
    check(qt::last_error() == qt::ERR_STALE_HANDLE, "stale child");
    qt::NONE.show();
    check(qt::last_error() == qt::ERR_NULL_HANDLE, "null receiver");
    let bogus = qt::Obj { h: 9223372036854775807 };
    bogus.show();
    check(qt::last_error() == qt::ERR_BAD_HANDLE, "garbage handle");
    check(!red.alive(), "freed value is stale");
    check(red.name().len == 0, "stale value call");
    check(!qt::free(red), "double free refused");
    let b2 = qt::QPushButton("x");
    qt::arg("a"); qt::arg("b"); qt::arg("c");
    check(!qt::call(b2, "setText"), "too many arguments");
    check(qt::last_error() == qt::ERR_BAD_ARGS, "bad args");
    check(!qt::call(b2, "noSuchMethod"), "unknown method");
    check(qt::last_error() == qt::ERR_NOT_FOUND, "not found");
    qt::destroy(b2);

    let e, ok = qt::enum_value("Qt::AlignHCenter");
    check(ok && e == 4, "enum lookup");
    check(qt::QImage.Format_ARGB32 == 5, "class enum");
    check(qt::class_count() > 400, "classes bound");
    check(qt::shutdown(), "shutdown");
    print("t01_basics: ", checks - failures, " passed, ", failures, " failed");
    if failures > 0 { exit(1); }
}
