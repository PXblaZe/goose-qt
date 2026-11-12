// Direct signals: CONN_DIRECT runs goose_qt_signal inside the emission.
import qt from "..";

var failures = 0;
var passed = 0;
fn check(ok: bool, what: const u8[:]) {
    if ok { passed++; } else { failures++; print("FAIL ", what); }
}

let CLICKED = 1;
let VALUE = 2;
let SELF_DESTROY = 3;
var clicks = 0;
var values = 0;
var last_value = 0;
var wait_refused = false;
var slider = qt::NONE;

export "goose_qt_signal" fn on_signal(tag: u64, source: u64, seq: u64) {
    if tag == CLICKED {
        clicks++;
        wait_refused = qt::wait(0) < 0;
        slider.setValue(42);                      // emits valueChanged: a nested direct call
    } else if tag == VALUE {
        values++;
        last_value = qt::arg_int(qt::direct_event(), 0);
    } else if tag == SELF_DESTROY {
        qt::destroy(qt::Obj { h: source });       // deleted once Qt's call returns
    }
}

fn main() {
    check(qt::init(qt::APP_WIDGETS, "t11\0-platform\0offscreen"), "init");
    qt::set_error_policy(qt::ERRORS_RETURN);
    check(qt::use_direct_signals(), "use_direct_signals");
    let w = qt::QWidget();
    let b = qt::QPushButton("go", w);
    slider = qt::QSlider(w);
    check(qt::connect(b, "clicked", CLICKED, qt::CONN_DIRECT) != 0, "connect clicked");
    check(qt::connect(slider, "valueChanged", VALUE, qt::CONN_DIRECT) != 0, "connect valueChanged");
    b.click();
    check(clicks == 1, "the handler ran inside click()");
    check(values == 1 && last_value == 42, "nested direct call with its argument");
    check(wait_refused, "the event loop is refused inside the handler");
    var ev = default<qt::Event>();
    var queued = 0;
    qt::process_events();
    while qt::poll(ev) { if ev.tag == CLICKED || ev.tag == VALUE { queued++; } }
    check(queued == 0, "nothing was queued");
    var i = 0;
    while i < 100 {
        let x = qt::QPushButton("x", w);
        qt::connect(x, "clicked", SELF_DESTROY, qt::CONN_DIRECT);
        x.click();
        qt::process_events();
        if qt::alive(x) { failures++; }
        i++;
    }
    check(true, "100 senders destroyed by their own handler");
    qt::destroy(w);
    qt::shutdown();
    print("t11_direct: ", passed, " passed, ", failures, " failed");
    if failures > 0 { exit(1); }
}
