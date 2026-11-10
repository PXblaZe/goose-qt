// hello: a window with a label and a button that counts its clicks.
//
//   goose hello.goose                    opens the window; close it to quit
//   goose hello.goose -- --selftest      clicks the button three times itself and checks the label
//   goose build hello.goose -o hello     a native program with the same options
//
// Objects are qt::Obj handles and every Qt method is a function, so UFCS reads
// like C++: label.setText("hi"). Signals arrive as events from qt::wait and
// qt::poll at the top of the loop, never in the middle of a Qt call.
import os;
import qt from "..";

let T_CLICKED: u64 = 1;
let T_SELFTEST_DONE: u64 = 2;

fn main() {
    let argv = args();
    let selftest = argv.len > 1 && argv[1] == "--selftest";
    if !qt::init() {
        print("qt::init: ", qt::last_error_message());
        exit(1);
    }

    let window = qt::QWidget();
    window.setWindowTitle("Hello from Goose");
    let layout = qt::QVBoxLayout(window);
    let label = qt::QLabel("Not clicked yet");
    let button = qt::QPushButton("Click me");
    layout.addWidget(label);     // the layout gives both a parent: the window
    layout.addWidget(button);
    window.resize(320, 120);
    qt::connect(button, "clicked", T_CLICKED);
    window.show();

    if selftest {
        for _ in 3 { button.click(); }
        qt::post(T_SELFTEST_DONE, 0, 0);   // arrives after the three clicks
    }

    var clicks = 0;
    var ev = default<qt::Event>();
    while qt::wait(-1) == qt::WAIT_EVENTS {   // WAIT_QUIT once the window closes
        while qt::poll(ev) {
            if ev.tag == T_CLICKED {
                clicks++;
                if clicks == 1 {
                    label.setText("Clicked 1 time");
                } else {
                    label.setText(str("Clicked ", clicks, " times"));
                }
            } else if ev.tag == T_SELFTEST_DONE {
                qt::quit();
            }
        }
    }

    var ok = true;
    if selftest {
        let text = label.text();
        ok = text == "Clicked 3 times";
        if ok { print("hello: label says \"", text, "\": ok"); } else { print("hello: label says \"", text, "\": FAIL"); }
    }
    qt::shutdown();   // destroys the window, and with it everything inside
    if !ok { exit(1); }
}
