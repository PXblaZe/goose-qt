// counter: a Qt window written in Goose, built as a shared library that a C or C++ program
// loads (goose build --shared). The host calls goose_init once, then these functions, all
// from that thread; host.c is such a program.
//
//   goose build --shared --header counter.h -o libcounter.so counter.goose
//   cc host.c -I. -L. -lcounter -Wl,-rpath,'$ORIGIN' -o host && ./host --selftest
import qt from "../..";

var window = qt::NONE;
var label = qt::NONE;
var button = qt::NONE;
var clicks = 0;
var text = str("");   // what counter_label hands out, kept until the next call

// Runs once, inside goose_init.
fn main() {
    if !qt::init(qt::APP_WIDGETS) { print("counter: Qt did not start"); }
}

// Makes the window; returns 1, or 0 when it could not.
export "counter_open" fn open(title: const u8[:]) -> i64 {
    window = qt::QWidget();
    window.setWindowTitle(title);
    let layout = qt::QVBoxLayout(window);
    label = qt::QLabel("no clicks yet", window);
    button = qt::QPushButton("Click me", window);
    layout.addWidget(label);
    layout.addWidget(button);
    if qt::connect(button, "clicked", 1) == 0 { return 0; }
    window.show();
    return 1;
}

// Handles what happened in the window for up to ms milliseconds; returns 0 once it was closed.
export "counter_run" fn run(ms: i64) -> i64 {
    if qt::wait(ms) == qt::WAIT_QUIT || !qt::alive(window) || !window.isVisible() { return 0; }
    var ev = default<qt::Event>();
    while qt::poll(ev) {
        if ev.kind == qt::EV_SIGNAL && ev.tag == 1 {
            clicks++;
            if clicks == 1 { label.setText("1 click"); } else { label.setText(str(clicks, " clicks")); }
        }
    }
    return 1;
}

// Clicks the button as a user would (for tests and demos).
export "counter_click" fn click() { qt::call(button, "click"); }

export "counter_clicks" fn count() -> i64 { return clicks; }

// The label's text, for the host to show: it stays valid until the next call of this.
export "counter_label" fn label_text() -> const u8[:] {
    text = label.prop<u8[]>("text");
    return text;
}

export "counter_close" fn close() { qt::shutdown(); }
