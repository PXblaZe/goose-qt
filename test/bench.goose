// What a call costs from Goose: generated wrappers, the property system,
// strings both ways, values, signals round trip. Prints a Markdown table.
//   goose bench.goose            (JIT)
//   goose build bench.goose -o bench && ./bench
import qt from "..";
import os;

fn report(what: const u8[:], n: i64, t0: i64) {
    let ns = (clock_ns() - t0) / n;
    print("| ", what, " | ", ns, " |");
}

fn main() {
    qt::init(qt::APP_WIDGETS, "bench\0-platform\0offscreen");
    qt::set_error_policy(qt::ERRORS_RETURN);
    qt::set_quit_on_last_window_closed(false);
    let n = 200000;
    let label = qt::QLabel();
    let slider = qt::QSlider();
    slider.setMaximum(1 << 30);
    let button = qt::QPushButton("b");
    var ev = default<qt::Event>();
    print("goose-qt on qtc ", qt::version(), ", Qt ", qt::qt_version(), ": nanoseconds per operation\n");
    print("| operation | ns |");
    print("|---|---|");

    var t = clock_ns();
    for i in n { label.setText("hello"); }
    report("label.setText(\"hello\") (generated wrapper)", n, t);

    t = clock_ns();
    for i in n { qt::set(label, "text", "hello"); }
    report("qt::set(label, \"text\", ...) (property)", n, t);

    t = clock_ns();
    for i in n { slider.setValue(i & 65535); }
    report("slider.setValue(i)", n, t);

    var sum = 0;
    t = clock_ns();
    for i in n { sum += slider.value_int(); }
    report("slider.value_int()", n, t);

    t = clock_ns();
    var total = 0;
    for i in n { total += label.text().len; }
    report("label.text() (a string back)", n, t);

    t = clock_ns();
    for i in n {
        let v = qt::val(i);
        v.free();
    }
    report("qt::val(i) + free", n, t);

    let color = qt::QColor(10, 20, 30, 255);
    t = clock_ns();
    for i in n { sum += color.red(); }
    report("color.red() (a method on a value)", n, t);

    qt::connect(button, "clicked", 1);
    t = clock_ns();
    for i in n / 4 {
        button.click();
        qt::poll(ev);
    }
    report("button.click() + qt::poll (signal round trip)", n / 4, t);

    t = clock_ns();
    for i in n {
        qt::post(2, i, 0);
        qt::poll(ev);
    }
    report("qt::post + qt::poll", n, t);

    t = clock_ns();
    for i in n { qt::alive(label); }
    report("qt::alive(handle)", n, t);

    t = clock_ns();
    let stale = qt::Obj { h: 21474836481 };
    for i in n { stale.show(); }
    report("call on a stale handle (rejected)", n, t);

    color.free();
    if sum == -1 || total == -1 { print(""); }
    qt::shutdown();
}
