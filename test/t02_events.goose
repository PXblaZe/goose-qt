// Signals, watched events, timers, posts, the queue and quitting.
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

// Takes everything queued (after letting Qt deliver what is pending) into evs.
fn drain(evs: qt::Event[>..]&) {
    evs.clear();
    qt::wait(0);
    var ev = default<qt::Event>();
    while qt::poll(ev) { evs.push(ev); }
}

fn count_tag(evs: const qt::Event[:], tag: u64) -> i64 {
    var n = 0;
    for e in evs { if e.tag == tag { n++; } }
    return n;
}

fn main() {
    check(qt::init(qt::APP_WIDGETS, "t02\0-platform\0offscreen"), "init");
    qt::set_error_policy(qt::ERRORS_RETURN);
    qt::set_quit_on_last_window_closed(false);
    var evs: qt::Event[>..] = [];

    // ------------------------------------------------ signals with arguments
    let win = qt::QWidget();
    win.resize(300, 200);
    let btn = qt::QPushButton("press", win);
    btn.setGeometry(10, 10, 100, 30);
    let c1 = qt::connect(btn, "clicked", 1);
    check(c1 != 0, "connect clicked");
    check(qt::test_show(win), "show");
    check(qt::test_click(btn), "simulated click");
    drain(evs);
    check(count_tag(evs, 1) == 1, "one clicked event");
    if evs.len > 0 {
        let e = evs[0];
        check(e.kind == qt::EV_SIGNAL && e.source == btn.h && e.id == c1, "event fields");
        check(e.argc == 1 && qt::arg_kind(e, 0) == qt::T_BOOL && !qt::arg_bool(e, 0), "clicked(bool) argument");
        check(qt::signal(e) == "clicked(bool)", "signal signature");
        check(qt::sender(e).h == btn.h, "sender");
    }

    let slider = qt::QSlider(win);
    slider.setRange(0, 1000);
    qt::connect(slider, "valueChanged", 2);
    slider.setValue(42);
    drain(evs);
    check(evs.len == 1 && evs[0].i0 == 42 && qt::arg_int(evs[0], 0) == 42, "valueChanged(int) argument");

    let edit = qt::QLineEdit(win);
    qt::connect(edit, "textChanged", 3);
    edit.setText("h\xc3\xa9llo");
    drain(evs);
    check(evs.len == 1 && qt::arg_str(evs[0], 0) == "h\xc3\xa9llo" && qt::text(evs[0]) == "h\xc3\xa9llo", "string argument");

    // ------------------------------------------------ connection flags
    let spin = qt::QSpinBox(win);
    spin.setRange(0, 10000);
    qt::connect(spin, "valueChanged(int)", 4, qt::CONN_COALESCE);
    for i in 100 { spin.setValue(i + 1); }
    drain(evs);
    check(evs.len == 1 && evs[0].count == 100 && evs[0].i0 == 100, "coalesced into one event with the last value");

    let once = qt::QPushButton("once", win);
    let c5 = qt::connect(once, "clicked", 5, qt::CONN_ONCE);
    once.click();
    once.click();
    drain(evs);
    check(count_tag(evs, 5) == 1, "ONCE delivers one event");
    check(!qt::disconnect(c5), "a ONCE connection is gone after it fired");

    let noargs = qt::QPushButton("noargs", win);
    qt::connect(noargs, "clicked", 6, qt::CONN_NO_ARGS);
    noargs.click();
    drain(evs);
    check(evs.len == 1 && evs[0].argc == 0, "NO_ARGS");

    check(qt::disconnect(c1), "disconnect");
    btn.click();
    drain(evs);
    check(count_tag(evs, 1) == 0, "no events after disconnect");
    check(!qt::disconnect(c1), "double disconnect refused");
    check(qt::connect(btn, "noSuchSignal", 7) == 0 && qt::last_error() == qt::ERR_NOT_FOUND, "unknown signal");

    // a direct Qt connection
    let bar = qt::QProgressBar(win);
    bar.setRange(0, 1000);
    check(qt::connect_to(slider, "valueChanged(int)", bar, "setValue(int)") != 0, "connect_to");
    slider.setValue(77);
    check(bar.value() == 77, "connect_to delivers synchronously");
    drain(evs);

    // ------------------------------------------------ watched events
    let canvas = qt::QWidget(win);
    canvas.setGeometry(120, 10, 150, 150);
    let w1 = qt::watch(canvas, qt::bit(qt::EV_MOUSE_PRESS) | qt::bit(qt::EV_MOUSE_RELEASE), 10);
    check(w1 != 0, "watch");
    check(qt::test_click(canvas, 30, 40), "click on watched widget");
    drain(evs);
    check(evs.len == 2 && evs[0].kind == qt::EV_MOUSE_PRESS && evs[1].kind == qt::EV_MOUSE_RELEASE, "press and release");
    if evs.len == 2 { check(evs[0].d0 == 30.0 && evs[0].d1 == 40.0 && evs[0].i0 == 1, "position and button"); }
    check(qt::unwatch(w1), "unwatch");

    // consuming: the button never sees the press, so it never emits clicked
    let guarded = qt::QPushButton("guarded", win);
    guarded.setGeometry(10, 50, 100, 30);
    qt::connect(guarded, "clicked", 11);
    let mouse = qt::bit(qt::EV_MOUSE_PRESS) | qt::bit(qt::EV_MOUSE_RELEASE);
    let w2 = qt::watch(guarded, mouse, mouse, 12);
    qt::test_click(guarded);
    drain(evs);
    check(count_tag(evs, 12) == 2 && count_tag(evs, 11) == 0, "consumed mouse events");
    qt::unwatch(w2);
    qt::test_click(guarded);
    drain(evs);
    check(count_tag(evs, 11) == 1, "clicked again once unwatched");

    let keys = qt::watch(edit, qt::bit(qt::EV_KEY_PRESS), 13);
    edit.setFocus();
    qt::test_type(edit, "ab");
    drain(evs);
    check(count_tag(evs, 13) == 2, "key presses");
    var typed: u8[>..] = [];
    for e in evs { if e.tag == 13 { typed.append(qt::text(e)); } }
    check(typed == "ab", "key text");
    qt::unwatch(keys);

    let doomed = qt::QLabel("doomed", win);
    qt::watch(doomed, qt::bit(qt::EV_DESTROYED), 14);
    qt::destroy(doomed);
    drain(evs);
    check(count_tag(evs, 14) == 1, "destroyed event");

    // an event whose source dies before it is polled
    let brief = qt::QPushButton("brief", win);
    qt::connect(brief, "clicked", 15);
    brief.click();
    qt::destroy(brief);
    drain(evs);
    check(evs.len >= 1 && evs[0].tag == 15 && qt::stale_source(evs[0]), "stale source flagged");

    // ------------------------------------------------ timers
    let t1 = qt::single_shot(10, 20);
    var got_timer = false;
    for i in 100 {
        if qt::wait(50) == qt::WAIT_EVENTS {
            var ev = default<qt::Event>();
            while qt::poll(ev) { if ev.tag == 20 && ev.kind == qt::EV_TIMER { got_timer = true; } }
        }
        if got_timer { break; }
    }
    check(got_timer, "single-shot timer");
    let t2 = qt::timer(5, 21);
    qt::test_wait(60);
    drain(evs);
    check(evs.len == 1 && evs[0].tag == 21 && evs[0].i0 >= 2, "periodic timeouts coalesced");
    qt::destroy(t2);
    qt::test_wait(30);
    drain(evs);
    check(count_tag(evs, 21) == 0, "destroyed timer stops");
    qt::destroy(t1);

    // ------------------------------------------------ posts, the queue and waiting
    check(qt::post(30, 7, -8), "post");
    drain(evs);
    check(evs.len == 1 && evs[0].kind == qt::EV_POST && evs[0].i0 == 7 && evs[0].i1 == -8 && evs[0].source == 0, "post payload");
    check(qt::wait(20) == qt::WAIT_TIMEOUT, "timeout with nothing queued");

    qt::set_queue_limit(10);
    for i in 25 { qt::post(31, i, 0); }
    check(qt::pending() == 10 && qt::dropped_events() == 15, "queue limit drops and counts");
    drain(evs);
    qt::set_queue_limit(0);

    // ------------------------------------------------ quitting
    qt::quit(3);
    check(qt::wait(1000) == qt::WAIT_QUIT && qt::quit_requested() && qt::exit_code() == 3, "quit");
    qt::cancel_quit();
    check(!qt::quit_requested(), "cancel quit");
    qt::set_quit_on_last_window_closed(true);
    let top = qt::QWidget();
    qt::test_show(top);
    win.close();
    top.close();
    var closed = false;
    for i in 20 {
        let w = qt::wait(100);
        var ev = default<qt::Event>();
        while qt::poll(ev) { if ev.kind == qt::EV_LAST_WINDOW_CLOSED { closed = true; } }
        if w == qt::WAIT_QUIT { break; }
    }
    check(closed && qt::quit_requested(), "last window closed quits");

    check(qt::shutdown(), "shutdown");
    print("t02_events: ", checks - failures, " passed, ", failures, " failed");
    if failures > 0 { exit(1); }
}
