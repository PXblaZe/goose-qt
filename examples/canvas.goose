// canvas: custom drawing, on screen and into an image.
//
//   goose canvas.goose                   click in the window to drop dots; close it to quit
//   goose canvas.goose -- --selftest     draws without a user, saves canvas.png and checks pixels
//
// A QtcCanvas is a widget that repaints from the last recording made with
// qt::draw_begin(canvas) ... qt::draw_end(): no paint callback runs inside Qt.
// qt::watch delivers its mouse presses as events. The same drawing calls paint
// straight into a QImage value.
import os;
import qt from "..";

let T_PRESS: u64 = 1;
let T_SELFTEST_DONE: u64 = 2;

var dots: f64[>..] = [];   // x0, y0, x1, y1, ...

fn scene() {   // the drawing calls, whatever the target
    qt::draw_clear(0xff1e2430);
    qt::draw_antialias(true);
    qt::draw_linear_gradient(0.0, 0.0, 400.0, 0.0, 0xff2a3a5c, 0xff5c2a4a);
    qt::draw_no_pen();
    qt::draw_rect(0.0, 0.0, 400.0, 40.0);
    qt::draw_pen(0xffffffff, 1.0);
    qt::draw_font("Sans", 12.0);
    qt::draw_text_in(0.0, 0.0, 400.0, 40.0, qt::Qt.AlignCenter, "click to drop dots");
    qt::draw_no_pen();
    qt::draw_brush(0xffffcc33);
    var i = 0;
    while i + 1 < dots.len {
        qt::draw_ellipse(dots[i] - 8.0, dots[i + 1] - 8.0, 16.0, 16.0);
        i += 2;
    }
}

fn redraw(canvas: qt::Obj) {
    if qt::draw_begin(canvas) {
        scene();
        qt::draw_end();   // the canvas repaints from this recording from now on
    }
}

fn add_dot(canvas: qt::Obj, x: f64, y: f64) {
    if dots.len < 512 {
        dots.push(x);
        dots.push(y);
    }
    redraw(canvas);
}

// the colour name ("#rrggbb") of one pixel of an image value
fn pixel(img: qt::Val, x: i64, y: i64) -> u8[>..] {
    let c = img.pixelColor(x, y);
    let n = c.name();
    c.free();
    return n;
}

fn main() {
    let argv = args();
    let selftest = argv.len > 1 && argv[1] == "--selftest";
    if !qt::init() {
        print("qt::init: ", qt::last_error_message());
        exit(1);
    }

    let canvas = qt::new_object("QtcCanvas");
    canvas.setWindowTitle("Canvas");
    canvas.resize(400, 300);
    qt::watch(canvas, qt::bit(qt::EV_MOUSE_PRESS), T_PRESS);
    redraw(canvas);
    canvas.show();

    if selftest {
        add_dot(canvas, 100.0, 150.0);   // what three clicks would do
        add_dot(canvas, 200.0, 200.0);
        add_dot(canvas, 300.0, 100.0);
        qt::post(T_SELFTEST_DONE, 0, 0);
    }

    var ev = default<qt::Event>();
    while qt::wait(-1) == qt::WAIT_EVENTS {
        while qt::poll(ev) {
            if ev.tag == T_PRESS {
                add_dot(canvas, ev.d0, ev.d1);   // d0, d1: the position in the widget
            } else if ev.tag == T_SELFTEST_DONE {
                qt::quit();
            }
        }
    }

    var ok = true;
    if selftest {
        // the same scene into an image, saved as a PNG
        let img = qt::QImage(400, 300, qt::QImage.Format_ARGB32);
        qt::draw_begin(img);
        scene();
        qt::draw_end();
        let saved = img.save("canvas.png");
        let dot = pixel(img, 200, 200);
        let back = pixel(img, 20, 280);
        // and what the window shows: grab it
        let pm = canvas.grab();
        let grabbed = pm.toImage();
        let shot = pixel(grabbed, 300, 100);
        ok = saved && dot == "#ffcc33" && back == "#1e2430" && shot == "#ffcc33";
        print("canvas: saved ", saved, ", dot ", dot, ", background ", back, ", window ", shot, ": ",
              if ok { "ok" } else { "FAIL" });
        grabbed.free();
        pm.free();
        img.free();
    }
    qt::shutdown();
    if !ok { exit(1); }
}
