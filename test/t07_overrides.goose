// Subclassing Qt classes from Goose (overridable objects) and runtime-defined classes.
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

let T_ROWS: u64 = 1;
let T_DATA: u64 = 2;
let T_PAINT: u64 = 3;
let T_DOUBLE: u64 = 4;
let T_VALIDATE: u64 = 5;
let T_KEY: u64 = 6;

var g_rows = 3;
var g_calls: i64[] = [0, 0, 0, 0, 0, 0, 0, 0];
var g_last_key = 0;

export "goose_qt_override" fn on_override(obj: u64, tag: u64, nargs: i64, depth: i64) -> i32 {
    if tag < 8 { g_calls[tag]++; }
    if tag == T_ROWS {
        qt::ov_ret(g_rows);
        return qt::OV_DONE;
    }
    if tag == T_DATA {
        let ix = qt::ov_arg_index(0);
        if !ix.valid || qt::ov_arg_int(1) != 0 { return qt::OV_BASE; }   // DisplayRole only
        qt::ov_ret(str("row ", ix.row));
        return qt::OV_DONE;
    }
    if tag == T_PAINT {
        // paintEvent(QPaintEvent *): draw on the widget, half red, half blue
        qt::draw_begin(qt::Obj { h: obj });
        qt::draw_clear(0xFFFF0000);
        qt::draw_brush(0xFF0000FF, 1);
        qt::draw_no_pen();
        qt::draw_rect(20.0, 0.0, 20.0, 20.0);
        qt::draw_end();
        return qt::OV_DONE;
    }
    if tag == T_DOUBLE {
        // a runtime class's invokable: twice(int) -> int
        qt::ov_ret(qt::ov_arg_int(0) * 2);
        return qt::OV_DONE;
    }
    if tag == T_VALIDATE {
        // QValidator::validate(QString &input, int &pos): digits only, at most 4
        let s = qt::ov_arg_str(0);
        var digits = true;
        for c in s { if c < 48 || c > 57 { digits = false; } }
        qt::ov_ret(if digits && s.len <= 4 { 2 } else { 0 });   // Acceptable : Invalid
        return qt::OV_DONE;
    }
    if tag == T_KEY {
        var ev = default<qt::Event>();
        if qt::ov_arg_event(0, ev) { g_last_key = ev.i0; }
        return qt::OV_BASE;   // the line edit still gets the key
    }
    return qt::OV_BASE;
}

fn main() {
    check(qt::init(), "init");
    qt::set_error_policy(qt::ERRORS_RETURN);
    check(qt::use_overrides(), "the exported handler is found");
    check(qt::overridable_classes().len > 100, "overridable classes are listed");
    check(qt::overridable_methods("QAbstractListModel").len > 0, "and their methods");

    // a list model in Goose
    let model = qt::new_overridable("QAbstractListModel");
    check(qt::is_overridable(model), "made overridable");
    check(qt::override(model, "rowCount", T_ROWS), "rowCount overridden");
    check(qt::override(model, "data", T_DATA), "data overridden");
    check(!qt::override(model, "noSuchMethod", 9), "unknown methods are refused");
    let view = qt::QListView();
    view.setModel(model);
    qt::call(view, "model");
    check(qt::ret_obj().h == model.h, "the view uses the model");
    qt::call(model, "rowCount");
    check(qt::ret_int() == 3, "rowCount comes from Goose");
    check(g_calls[T_ROWS] > 0, "the handler ran");
    qt::arg(2); qt::arg(0);
    check(qt::call(model, "index"), "index()");
    let ix = qt::ret_val();
    qt::arg(ix);
    check(qt::call(model, "data"), "data()");
    check(qt::ret_str() == "row 2", "data comes from Goose");
    qt::free(ix);
    // rows added: the model says so
    g_rows = 5;
    qt::call(model, "rowCount");
    check(qt::ret_int() == 5, "the count follows the program");

    // a widget painted in Goose
    let w = qt::new_overridable("QWidget");
    check(qt::override(w, "paintEvent", T_PAINT), "paintEvent overridden");
    w.resize(40, 20);
    qt::call(w, "grab");
    let pm = qt::ret_val();
    let img = pm.toImage();
    check(img.pixel(5, 10) == 0xFFFF0000, "painted red on the left");
    check(img.pixel(30, 10) == 0xFF0000FF, "and blue on the right");
    check(g_calls[T_PAINT] > 0, "paintEvent ran in Goose");
    qt::free(img);
    qt::free(pm);

    // a validator, and an event override that lets the class run too
    let v = qt::new_overridable("QValidator");
    check(qt::override(v, "validate", T_VALIDATE), "validate overridden");
    let edit = qt::QLineEdit();
    edit.setValidator(v);
    qt::test_show(edit);
    qt::test_type(edit, "12a345");
    check(edit.text() == "1234", "the Goose validator kept digits only, four at most");
    let kw = qt::new_overridable("QWidget");
    check(qt::override(kw, "keyPressEvent", T_KEY), "keyPressEvent overridden");
    qt::test_show(kw);
    qt::test_key(kw, 0x41);
    check(g_last_key == 0x41, "the key event reached Goose");

    // a runtime class: a property with a notify signal and an invokable
    check(qt::class_begin("Counter", "QObject"), "class_begin");
    check(qt::class_property("count", "int", qt::PROP_WRITE | qt::PROP_NOTIFY), "a property");
    check(qt::class_invokable("twice(int)", "int", T_DOUBLE), "an invokable");
    check(qt::class_signal("ping(QString)"), "a signal");
    check(qt::class_end(), "class_end");
    check(qt::class_exists_runtime("Counter"), "the class exists");
    let c = qt::class_new("Counter");
    check(qt::alive(c), "an object of it");
    let conn = qt::connect(c, "countChanged", 50);
    check(conn != 0, "its notify signal connects");
    check(qt::set(c, "count", 7), "the property is written");
    check(qt::get_int(c, "count") == 7, "and read back");
    qt::arg(21);
    check(qt::call(c, "twice"), "the invokable is called");
    check(qt::ret_int() == 42, "and runs in Goose");
    check(qt::connect(c, "ping", 51) != 0, "ping connects");
    qt::arg("hello");
    check(qt::emit(c, "ping"), "a signal is emitted");
    var changed = 0;
    var pinged = false;
    qt::process_events();
    var ev = default<qt::Event>();
    while qt::poll(ev) {
        if ev.tag == 50 { changed++; }
        if ev.tag == 51 && qt::text(ev) == "hello" { pinged = true; }
    }
    check(changed == 1, "one countChanged");
    check(pinged, "ping arrived with its argument");
    check(!qt::class_begin("Counter", "QObject") || !qt::class_end(), "a class name is taken once");
    qt::class_cancel();

    qt::destroy(c);
    qt::destroy(edit);
    qt::destroy(kw);
    qt::destroy(v);
    qt::destroy(w);
    qt::destroy(view);
    qt::destroy(model);
    check(qt::shutdown(), "shutdown");
    print("t07_overrides: ", checks - failures, " passed, ", failures, " failed");
    if failures > 0 { exit(1); }
}
