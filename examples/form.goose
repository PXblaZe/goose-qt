// form: a small form with a list of entries, built from Qt widgets.
//
//   goose form.goose                     fill it in and press Submit; close the window to quit
//   goose form.goose -- --selftest       fills it in and submits it itself, then checks the list
//
// Shows constructors with arguments, enum values (qt::Qt.AlignRight), several
// signals in one loop, and coalescing: a burst of textEdited signals arrives
// as one event whose count says how many there were.
import os;
import qt from "..";

let T_SUBMIT: u64 = 1;
let T_EDITED: u64 = 2;
let T_SELFTEST_DONE: u64 = 3;

fn main() {
    let argv = args();
    let selftest = argv.len > 1 && argv[1] == "--selftest";
    if !qt::init() {
        print("qt::init: ", qt::last_error_message());
        exit(1);
    }

    let window = qt::QWidget();
    window.setWindowTitle("Sign-up");
    let form = qt::QFormLayout(window);
    let name = qt::QLineEdit();
    name.setPlaceholderText("your name");
    let age = qt::QSpinBox();
    age.setRange(0, 130);
    age.setValue(30);
    let country = qt::QComboBox();
    for c in ["India", "Netherlands", "Brazil", "Japan"] { country.addItem(c); }
    let subscribe = qt::QCheckBox("Subscribe to the newsletter");
    let submit = qt::QPushButton("Submit");
    let entries = qt::QListWidget();
    form.addRow("Name", name);
    form.addRow("Age", age);
    form.addRow("Country", country);
    form.addRow(subscribe);
    form.addRow(submit);
    form.addRow("Entries", entries);
    form.setLabelAlignment(qt::Qt.AlignRight | qt::Qt.AlignVCenter);

    qt::connect(submit, "clicked", T_SUBMIT);
    qt::connect(name, "textEdited", T_EDITED, qt::CONN_COALESCE);
    window.show();

    if selftest {
        for key in ["A", "d", "a"] { name.insert(key); }   // insert() counts as editing
        age.setValue(36);
        country.setCurrentIndex(1);
        subscribe.setChecked(true);
        submit.click();
        qt::post(T_SELFTEST_DONE, 0, 0);
    }

    var edit_events = 0;
    var keystrokes = 0;
    var ev = default<qt::Event>();
    while qt::wait(-1) == qt::WAIT_EVENTS {
        while qt::poll(ev) {
            if ev.tag == T_SUBMIT {
                var who = name.text();
                if who.len == 0 { who = str("(no name)"); }
                var line = str(who, ", ", age.value_int(), ", ", country.currentText());
                if subscribe.isChecked() { line.append(", subscribed"); }
                entries.addItem(line);
                name.clear();
            } else if ev.tag == T_EDITED {
                edit_events++;
                keystrokes += ev.count;
                print("name edited (", ev.count, " keystrokes)");
            } else if ev.tag == T_SELFTEST_DONE {
                qt::quit();
            }
        }
    }

    var ok = true;
    if selftest {
        // list items are not QObjects, so read the entry through the list's model
        let n = entries.count();
        let model = entries.model_obj();
        let index = model.index(0, 0);    // a QModelIndex value
        let data = model.data(index);     // role defaults to DisplayRole
        let first = data.to_str();
        data.free();
        index.free();
        ok = n == 1 && first == "Ada, 36, Netherlands, subscribed" && edit_events == 1 && keystrokes == 3;
        print("form: ", n, " entries, first \"", first, "\", ", edit_events, " edit event for ", keystrokes, " keystrokes: ",
              if ok { "ok" } else { "FAIL" });
    }
    qt::shutdown();
    if !ok { exit(1); }
}
