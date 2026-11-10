// A small widgets application driven by simulated input, item models and views,
// and the ownership rules (objects Qt points at, Qt's internal parts).
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

let T_SUBMIT: u64 = 1;
let T_NEW: u64 = 2;
let T_TAB: u64 = 3;
let T_NAME: u64 = 4;
let T_CANVAS: u64 = 5;
let T_ROW: u64 = 6;

fn main() {
    check(qt::init(qt::APP_WIDGETS, "t03\0-platform\0offscreen"), "init");
    qt::set_error_policy(qt::ERRORS_RETURN);
    qt::set_quit_on_last_window_closed(false);

    // ------------------------------------------------ the main window
    let win = qt::QMainWindow();
    win.setWindowTitle("goose-qt form");
    win.resize(560, 420);
    let file = win.menuBar().addMenu("&File");
    let act_new = file.addAction("&New");
    check(qt::alive(act_new), "menu action");
    let tools = win.addToolBar("main");
    tools.addAction(act_new);
    qt::connect(act_new, "triggered", T_NEW);
    let status = win.statusBar();

    let tabs = qt::QTabWidget();
    win.setCentralWidget(tabs);
    check(win.centralWidget().h == tabs.h, "central widget");
    let page = qt::QWidget();
    let form = qt::QFormLayout(page);
    let name = qt::QLineEdit();
    name.setPlaceholderText("your name");
    let age = qt::QSpinBox();
    age.setRange(0, 130);
    age.setValue(30);
    let country = qt::QComboBox();
    for c in ["India", "Netherlands", "Brazil"] { country.addItem(c); }
    let subscribe = qt::QCheckBox("Subscribe");
    let submit = qt::QPushButton("Submit");
    let entries = qt::QListWidget();
    form.addRow("Name", name);
    form.addRow("Age", age);
    form.addRow("Country", country);
    form.addRow(subscribe);
    form.addRow(submit);
    form.addRow("Entries", entries);
    check(form.rowCount() == 6, "form rows");
    tabs.addTab(page, "Form");
    let canvas = qt::new_object("QtcCanvas");
    tabs.addTab(canvas, "Canvas");
    check(tabs.count() == 2, "tabs");

    qt::connect(submit, "clicked", T_SUBMIT);
    qt::connect(tabs, "currentChanged", T_TAB);
    qt::connect(name, "textEdited", T_NAME, qt::CONN_COALESCE);
    qt::watch(canvas, qt::bit(qt::EV_MOUSE_PRESS), T_CANVAS);
    check(qt::test_show(win), "show");

    // ------------------------------------------------ the user fills in the form
    name.setFocus();
    check(qt::test_type(name, "Phoenix"), "type a name");
    for i in 3 { qt::test_key(age, 0x01000013); }   // Qt::Key_Up
    country.setCurrentIndex(1);
    check(qt::test_click(subscribe, 8, 8), "tick the box");
    check(qt::test_click(submit), "submit");
    act_new.trigger();
    tabs.setCurrentIndex(1);
    qt::test_wait(10);
    qt::test_click(canvas, 50, 60);
    qt::test_click(canvas, 120, 80);
    qt::post(99, 0, 0);

    var submits = 0;
    var news = 0;
    var tab_changes = 0;
    var edit_events = 0;
    var edit_count = 0;
    var clicks = 0;
    var line: u8[>..] = [];
    var dots: f64[>..] = [];
    var done = false;
    while !done {
        if qt::wait(2000) != qt::WAIT_EVENTS { break; }
        var ev = default<qt::Event>();
        while qt::poll(ev) {
            if ev.tag == T_SUBMIT {
                submits++;
                line.clear();
                line.append(name.text());
                line.append(str(", ", age.value_int(), ", ", country.currentText()));
                if subscribe.isChecked() { line.append(", subscribed"); }
                entries.addItem(line);
                status.showMessage("saved", 0);
            } else if ev.tag == T_NEW {
                news++;
                name.clear();
            } else if ev.tag == T_TAB {
                tab_changes++;
            } else if ev.tag == T_NAME {
                edit_events++;
                edit_count += ev.count;
            } else if ev.tag == T_CANVAS {
                clicks++;
                dots.push(ev.d0);
                dots.push(ev.d1);
                qt::draw_begin(canvas);
                qt::draw_clear(0xffffffff);
                qt::draw_antialias(true);
                qt::draw_brush(0xff2266cc);
                qt::draw_no_pen();
                var i = 0;
                while i + 1 < dots.len {
                    qt::draw_ellipse(dots[i] - 6.0, dots[i + 1] - 6.0, 12.0, 12.0);
                    i += 2;
                }
                qt::draw_end();
            } else if ev.tag == 99 {
                done = true;
            }
        }
    }
    check(submits == 1, "one submit");
    check(line == "Phoenix, 33, Netherlands, subscribed", "the entry");
    check(news == 1 && name.text().len == 0, "New clears the name");
    check(tab_changes == 1, "tab change");
    check(edit_events == 1 && edit_count == 7, "seven keystrokes coalesced");
    check(clicks == 2 && qt::get_int(canvas, "commandCount") == 6, "canvas clicks drawn");
    check(entries.count() == 1, "one list entry");
    check(status.currentMessage() == "saved", "status message");
    check(qt::test_grab(win, "t03_form.png"), "grab a screenshot");

    // ------------------------------------------------ item models and views
    let model = qt::QStandardItemModel(3, 2);
    check(model.rowCount() == 3 && model.columnCount() == 2, "model size");
    let idx = model.index(1, 1);
    check(model.setData(idx, qt::val("cell")), "setData");
    check(model.data(idx).to_str() == "cell", "data");
    let view = qt::QTableView();
    view.setModel(model);
    view.resize(300, 200);
    qt::test_show(view);
    view.selectRow(2);
    let sel = view.selectionModel();
    check(sel.selectedRows().list_len() == 1, "row selected");
    qt::connect(model, "rowsInserted", T_ROW);
    check(model.insertRows(3, 2), "insertRows");
    check(model.rowCount() == 5, "rows inserted");
    check(!model.removeRows(4, 10) && qt::last_error() == qt::ERR_OUT_OF_RANGE, "removing rows that do not exist is refused");
    let other = qt::QStandardItemModel(1, 1);
    let foreign = other.index(0, 0);
    check(!model.setData(foreign, qt::val("x")) && qt::last_error() == qt::ERR_BAD_ARGS, "an index of another model is refused");
    var ev = default<qt::Event>();
    qt::wait(0);
    var rows = 0;
    while qt::poll(ev) { if ev.tag == T_ROW { rows++; check(ev.i0 == 3 && ev.i1 == 4, "rowsInserted(first, last)"); } }
    check(rows == 1, "rowsInserted event");

    let proxy = qt::QSortFilterProxyModel();
    proxy.setSourceModel(model);
    check(proxy.rowCount() == 5, "proxy over the model");
    proxy.setSourceModel(proxy);
    check(qt::last_error() == qt::ERR_BAD_ARGS, "a proxy cannot be its own source");

    // ------------------------------------------------ objects Qt points at
    let box = qt::QMessageBox();
    let cb = qt::QCheckBox("Don't ask again");
    box.setCheckBox(cb);
    check(box.checkBox().h == cb.h, "check box set");
    check(qt::destroy(cb), "destroying the check box releases it first");
    check(box.checkBox().h == 0, "the message box let go of it");
    box.setInformativeText("still fine");
    check(box.informativeText() == "still fine", "message box usable after");
    let cb2 = qt::QCheckBox("again");
    box.setCheckBox(cb2);
    let box2 = qt::QMessageBox();
    box2.setCheckBox(cb2);
    check(qt::last_error() == qt::ERR_STATE, "a check box held by one message box cannot move to another");

    check(!qt::destroy(tabs.tabBar()) && qt::last_error() == qt::ERR_STATE, "a QTabWidget's tab bar cannot be destroyed");
    let scroll = qt::QScrollArea();
    let vp = scroll.viewport();
    check(qt::destroy(vp), "destroying a viewport replaces it");
    check(qt::alive(scroll.viewport()) && scroll.viewport().h != vp.h, "new viewport");
    let lay = qt::QVBoxLayout();
    let lbl = qt::QLabel("in a layout without a widget");
    lay.addWidget(lbl);
    lay.addWidget(lbl);
    check(qt::last_error() == qt::ERR_BAD_ARGS, "one widget twice in a parentless layout is refused");
    qt::destroy(lbl);
    qt::process_events();
    check(lay.count() == 0, "a destroyed widget leaves the parentless layout");
    let holder = qt::QWidget();
    holder.setLayout(lay);
    check(qt::test_show(holder), "the layout is usable afterwards");

    // reparenting cycles are refused, not hung
    let outer = qt::QWidget();
    let inner = qt::QWidget(outer);
    let ilay = qt::QVBoxLayout(inner);
    ilay.addWidget(outer);
    check(qt::last_error() == qt::ERR_BAD_ARGS, "a widget cannot be added inside itself");
    let mw2 = qt::QMainWindow();
    mw2.setCentralWidget(mw2);
    check(qt::last_error() == qt::ERR_BAD_ARGS, "a window cannot be its own central widget");

    check(qt::shutdown(), "shutdown");
    print("t03_widgets: ", checks - failures, " passed, ", failures, " failed");
    if failures > 0 { exit(1); }
}
