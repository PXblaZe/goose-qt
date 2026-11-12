// The misuse probes, one per run: misuse CASE (see run.py for the list)
import os;
import qt from "../../..";

fn report() {
    if qt::last_error() != 0 { print("error: ", qt::last_error_message()); } else { print("no error reported"); }
}

// a widget changed from another thread: the handle crosses as a number
thread_fn writer(label: u64) {
    let l = qt::Obj { h: label };
    for i in 1000 { l.setText("x"); if qt::last_error() != 0 { break; } }
    report();
}

fn main() {
    var c = str("");
    for a in args() { c = str(a); }
    qt::set_error_policy(qt::ERRORS_RETURN);
    if c == "before_app" { let l = qt::QLabel("x"); l.show(); report(); return; }
    qt::init(qt::APP_WIDGETS, "misuse");
    qt::set_error_policy(qt::ERRORS_RETURN);
    if c == "deleted" { let w = qt::QWidget(); let l = qt::QLabel("x", w); qt::destroy(w); qt::process_events(); l.setText("y"); }
    if c == "deleted_self" { let l = qt::QLabel("x"); qt::destroy(l); l.setText("y"); }
    if c == "double_delete" { let l = qt::QLabel("x"); qt::destroy(l); qt::destroy(l); }
    if c == "stale_index" {
        let m = qt::QStandardItemModel(2, 1);
        let i = m.index(1, 0);
        m.clear();
        if !m.setData(i, qt::val("b")) && qt::last_error() == 0 { print("refused: the index is no longer valid, setData returned false"); qt::shutdown(); return; }
    }
    if c == "held_deleted" {
        let t = qt::QTableWidget(2, 2);
        let b = qt::QPushButton("x");
        t.setCellWidget(0, 0, b);
        t.show();
        qt::process_events();
        qt::destroy(b);
        let e = qt::last_error();
        t.resize(400, 300);
        qt::process_events();
        if e == 0 && qt::last_error() == 0 { print("handled: the table let go of the button first (no error, no crash)"); qt::shutdown(); return; }
    }
    if c == "null" { let cb = qt::QComboBox(); cb.lineEdit().setText("x"); }
    if c == "range" { let s = qt::QSpinBox(); s.setValue(10000000000); }
    if c == "wrong_thread" {
        let l = qt::QLabel("x");
        l.show();
        let t = thread_spawn(writer, l.h);
        thread_wait(t);
        qt::shutdown();
        return;
    }
    if c == "qtbug" { let cb = qt::QComboBox(); cb.addItem("a"); cb.setView(cb.view()); cb.showPopup(); qt::process_events(); }
    report();
    qt::shutdown();
}
