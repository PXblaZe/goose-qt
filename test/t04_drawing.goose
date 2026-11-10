// Drawing on images and on a QtcCanvas widget, checked pixel by pixel.
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

fn pixel(img: qt::Val, x: i64, y: i64) -> u8[>..] {
    let c = img.pixelColor(x, y);
    let n = c.name();
    c.free();
    return n;
}

fn main() {
    check(qt::init(qt::APP_WIDGETS, "t04\0-platform\0offscreen"), "init");
    qt::set_error_policy(qt::ERRORS_RETURN);
    qt::set_quit_on_last_window_closed(false);

    // ------------------------------------------------ an image
    let img = qt::QImage(64, 32, qt::QImage.Format_ARGB32);
    check(img.width_int() == 64 && img.height_int() == 32, "image size");
    check(qt::draw_begin(img), "begin on an image");
    check(!qt::draw_begin(img) && qt::last_error() == qt::ERR_STATE, "nested begin refused");
    qt::draw_clear(0xff0000ff);
    qt::draw_no_pen();
    qt::draw_brush(0xffff0000);
    qt::draw_rect(0.0, 0.0, 32.0, 32.0);
    qt::draw_save();
    qt::draw_translate(40.0, 0.0);
    qt::draw_brush(0xff00ff00);
    qt::draw_rect(0.0, 0.0, 8.0, 8.0);
    qt::draw_restore();
    qt::draw_polygon([40.0, 20.0, 60.0, 20.0, 50.0, 30.0]);
    qt::draw_pen(0xffffffff, 1.0);
    qt::draw_line(0.0, 31.0, 63.0, 31.0);
    check(qt::draw_count() >= 6, "commands counted");
    check(qt::draw_end(), "end");
    check(pixel(img, 5, 5) == "#ff0000", "red square");
    check(pixel(img, 62, 2) == "#0000ff", "blue background");
    check(pixel(img, 43, 3) == "#00ff00", "translated green square");
    check(pixel(img, 44, 12) == "#0000ff", "restore undid the translation");
    check(pixel(img, 50, 25) == "#ff0000", "polygon filled with the red brush");
    check(pixel(img, 10, 31) == "#ffffff", "white line");

    // ------------------------------------------------ bad input is an error, never a crash
    qt::draw_begin(img);
    qt::draw_line(0.0 / 0.0, 0.0, 1.0, 1.0);
    check(qt::last_error() == qt::ERR_OUT_OF_RANGE, "NaN coordinate refused");
    qt::draw_rect(1e300, 0.0, 1.0, 1.0);
    check(qt::last_error() == qt::ERR_OUT_OF_RANGE, "huge coordinate refused");
    qt::draw_pen(0xff000000, -1.0, 1, 0, 0);
    check(qt::last_error() == qt::ERR_OUT_OF_RANGE, "negative pen width refused");
    qt::draw_pen(0xff000000, 1.0, 99, 0, 0);
    check(qt::last_error() == qt::ERR_OUT_OF_RANGE, "unknown pen style refused");
    qt::draw_polygon([1.0, 2.0, 3.0]);
    check(qt::last_error() == qt::ERR_INVALID_ARG, "odd coordinate count refused");
    qt::draw_restore();
    check(qt::last_error() == qt::ERR_STATE, "restore without save refused");
    qt::draw_path_end();
    check(qt::last_error() == qt::ERR_STATE, "path end without a path refused");
    qt::draw_path_move(2.0, 2.0);
    qt::draw_path_quad(10.0, 0.0, 20.0, 10.0);
    qt::draw_path_cubic(25.0, 15.0, 30.0, 5.0, 35.0, 10.0);
    qt::draw_path_close();
    qt::draw_path_end();
    check(qt::last_error() == qt::OK || qt::draw_count() > 0, "a path");
    qt::draw_save();
    check(qt::draw_end(), "end closes an unmatched save");
    check(!qt::draw_end() && qt::last_error() == qt::ERR_STATE, "end without begin refused");
    qt::draw_line(0.0, 0.0, 1.0, 1.0);
    check(qt::last_error() == qt::ERR_STATE, "drawing outside begin/end refused");

    // ------------------------------------------------ text, gradients, transforms, images
    let big = qt::QImage(200, 100, qt::QImage.Format_ARGB32);
    qt::draw_begin(big);
    qt::draw_clear(0xffffffff);
    qt::draw_linear_gradient(0.0, 0.0, 200.0, 0.0, 0xff000000, 0xffffffff);
    qt::draw_no_pen();
    qt::draw_rect(0.0, 50.0, 200.0, 50.0);
    qt::draw_pen(0xff000000, 1.0);
    qt::draw_font("Sans", 14.0);
    qt::draw_text(5.0, 30.0, "goose-qt \xf0\x9f\xa6\xa2");
    qt::draw_text_in(0.0, 0.0, 200.0, 50.0, qt::Qt.AlignCenter, "centred");
    qt::draw_save();
    qt::draw_translate(150.0, 25.0);
    qt::draw_rotate(45.0);
    qt::draw_scale(2.0, 2.0);
    qt::draw_rect(-5.0, -5.0, 10.0, 10.0);
    qt::draw_restore();
    qt::draw_image(img, 0.0, 0.0, 32.0, 16.0);
    qt::draw_opacity(0.5);
    qt::draw_ellipse(100.0, 0.0, 20.0, 20.0);
    qt::draw_arc(120.0, 0.0, 20.0, 20.0, 0.0, 180.0);
    qt::draw_pie(140.0, 0.0, 20.0, 20.0, 0.0, 90.0);
    qt::draw_rounded_rect(160.0, 0.0, 30.0, 20.0, 4.0, 4.0);
    qt::draw_polyline([0.0, 99.0, 50.0, 60.0, 100.0, 99.0]);
    qt::draw_point(199.0, 0.0);
    check(qt::draw_end(), "rich drawing");
    let left = img.pixelColor(2, 75);
    let right = big.pixelColor(197, 75);
    check(right.red() > 200, "gradient light on the right");
    left.free();
    right.free();
    let dark = big.pixelColor(2, 75);
    check(dark.red() < 40, "gradient dark on the left");
    dark.free();
    check(pixel(big, 5, 5) == "#ff0000", "image drawn into the image");

    // ------------------------------------------------ a canvas widget repaints from its recording
    let win = qt::QWidget();
    win.resize(160, 120);
    let canvas = qt::new_object("QtcCanvas");
    canvas.setParent(win);
    canvas.resize(160, 120);
    check(!qt::draw_begin(win) && qt::last_error() == qt::ERR_WRONG_TYPE, "a plain widget is not a canvas");
    check(qt::draw_begin(canvas), "begin on a canvas");
    qt::draw_clear(0xff102030);
    qt::draw_brush(0xffffcc00);
    for k in 1000 { qt::draw_ellipse(k % 150, k % 110, 5.0, 5.0); }
    qt::draw_end();
    let recorded = qt::get_int(canvas, "commandCount");
    check(recorded == 1001 || recorded == 1002, str("1001 commands recorded (", recorded, ")"));
    check(qt::test_show(win), "show");
    qt::test_wait(20);
    check(qt::get_int(canvas, "paintCount") >= 1, "painted");
    let shot = canvas.grab();
    check(shot.width_int() == 160, "grab the canvas");
    let shot_img = shot.toImage();
    check(pixel(shot_img, 159, 119) == "#102030", "canvas background in the grab");
    check(qt::test_grab(win, "t04_canvas.png"), "screenshot");
    // a recording that is replaced: the old commands go
    qt::draw_begin(canvas);
    qt::draw_clear(0xff000000);
    qt::draw_end();
    check(qt::get_int(canvas, "commandCount") == 1, "re-recorded");
    // destroying the target mid-recording ends it
    check(qt::draw_begin(canvas), "begin again");
    qt::destroy(canvas);
    qt::process_events();
    qt::draw_line(0.0, 0.0, 1.0, 1.0);
    check(!qt::draw_end() && qt::last_error() == qt::ERR_STALE_HANDLE, "ending a recording whose target was destroyed");
    check(qt::draw_begin(img), "drawing works again afterwards");
    qt::draw_end();

    for v in [img, big, shot, shot_img] { v.free(); }
    check(qt::live_values() == 0, "values freed");
    check(qt::shutdown(), "shutdown");
    print("t04_drawing: ", checks - failures, " passed, ", failures, " failed");
    if failures > 0 { exit(1); }
}
