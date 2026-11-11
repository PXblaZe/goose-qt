// Three misuses, one per run: misuse deleted|range|qtbug
import os;
import qt from "../../..";
fn main() {
    var c = str("");
    for a in args() { c = str(a); }
    qt::init(qt::APP_WIDGETS, "misuse");
    qt::set_error_policy(qt::ERRORS_RETURN);
    if c == "deleted" { let w = qt::QWidget(); let l = qt::QLabel("x", w); qt::destroy(w); qt::process_events(); l.setText("y"); }
    if c == "range" { let s = qt::QSpinBox(); s.setValue(10000000000); }
    if c == "qtbug" { let cb = qt::QComboBox(); cb.addItem("a"); cb.setView(cb.view()); cb.showPopup(); qt::process_events(); }
    if qt::last_error() != 0 { print("error: ", qt::last_error_message()); } else { print("no error reported"); }
    qt::shutdown();
}
