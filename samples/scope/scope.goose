// scope: a four-channel oscilloscope. Four worker threads generate signals at about 51,000
// samples a second each and stream them to the GUI thread through qt::post (eight 16-bit
// samples in one event); a QWidget subclassed in Goose paints the last 1,024 samples of each
// channel, as fast as frames come. Native builds only (the JIT runs no threads):
//
//   goose build scope.goose -o scope && ./scope       a window; close it to quit
//   ./scope --selftest                                3 seconds offscreen, then frame and sample rates
import os;
import math;
import qt from "../..";

let CHANNELS = 4;
let SHOWN = 1024;               // samples shown per channel
let RATE = 51200.0;             // samples a second per channel
let BLOCK = 512;                // samples a worker makes at a time
let PAUSE_MS = 10;              // between the times a worker catches up with the clock
let W = 800.0;
let H = 480.0;
let COLORS: u32[] = [0xff40e0a0, 0xffffc040, 0xff60a0ff, 0xffff6080];
let NAMES: const u8[:][] = ["sine + noise", "square", "chirp", "sawtooth"];

let T_SAMPLES: u64 = 100;       // + channel: a post with eight samples
let T_PAINT: u64 = 1;
let T_FRAME: u64 = 2;

// 16 bits a sample, four to an i64
fn pack(xs: const f64[:], at: i64) -> i64 {
    var v: u64 = 0;
    for k in 4 {
        let q = ((xs[at + k] * 32000.0) as! i64) & 0xffff;
        v = v | ((q as u64) << ((16 * k) as u64));
    }
    return v as i64;
}

fn unpack(v: i64, k: i64) -> f64 {
    var q = (((v as u64) >> ((16 * k) as u64)) & 0xffff) as i64;
    if q >= 32768 { q -= 65536; }
    return q / 32000.0;
}

// t in seconds; the 1,024 samples shown span 20 ms, so the frequencies suit that window
fn wave(channel: i64, t: f64, noise: f64) -> f64 {
    if channel == 0 { return 0.7 * sin(TAU * 150.0 * t) + 0.15 * noise; }
    if channel == 1 { return if sin(TAU * 100.0 * t) >= 0.0 { 0.6 } else { -0.6 }; }
    if channel == 2 { return 0.8 * sin(TAU * (225.0 * t - 111.4 * sin(TAU * 0.25 * t))); }   // 50 to 400 Hz and back, every 4 s
    let x = t * 120.0;
    return 1.6 * (x - floor(x)) - 0.8;
}

// a worker: makes its channel's signal until the stop token is canceled
thread_fn generate(channel: i64, stop: u64) {
    let token = qt::Future { id: stop };
    var n: i64 = 0;
    var seed: u64 = 12345 + channel as u64;
    var samples: f64[>..] = [];
    let start = clock_ns();
    while !qt::canceled(token) {
        // as many blocks as the clock says are due, as a sampling device would deliver them: a
        // sleep can last well over PAUSE_MS (macOS on a busy machine), which must not slow the
        // signal down. At most 20 blocks at once; the rest come at the next wake.
        let due = ((clock_ns() - start) / 1e9 * RATE) as! i64;
        var made = 0;
        while n + BLOCK <= due && made < 20 {
            samples.clear();
            for i in BLOCK {
                seed = seed * 6364136223846793005 + 1442695040888963407;
                let noise = ((seed >> 33) as i64 % 2000) / 1000.0 - 1.0;
                samples.push(wave(channel, (n + i) / RATE, noise));
            }
            var at = 0;
            while at < BLOCK {
                qt::post(T_SAMPLES + channel as u64, pack(samples, at), pack(samples, at + 4));
                at += 8;
            }
            n += BLOCK;
            made++;
        }
        sleep_ms(PAUSE_MS);
    }
}

// the GUI thread's copy: the last SHOWN samples of each channel, as rings
var rings: f64[>..] = [];
var heads: i64[] = [0, 0, 0, 0];
var received: i64[] = [0, 0, 0, 0];
var frames = 0;
var points_drawn = 0;
var xy: f64[>..] = [];

fn take(channel: i64, a: i64, b: i64) {
    for k in 8 {
        let s = if k < 4 { unpack(a, k) } else { unpack(b, k - 4) };
        rings[channel * SHOWN + heads[channel]] = s;
        heads[channel] = (heads[channel] + 1) % SHOWN;
    }
    received[channel] += 8;
}

fn paint_scope(widget: u64) {
    qt::draw_begin(qt::Obj { h: widget });
    qt::draw_clear(0xff10141c);
    qt::draw_antialias(true);
    qt::draw_pen(0xff2a3242, 1.0);
    for i in 11 { let x = i * W / 10.0; qt::draw_line(x, 0.0, x, H); }
    for i in 9 { let y = i * H / 8.0; qt::draw_line(0.0, y, W, y); }
    let lane = H / CHANNELS;
    for c in CHANNELS {
        xy.clear();
        let mid = lane * c + lane / 2.0;
        for i in SHOWN {
            let s = rings[c * SHOWN + (heads[c] + i) % SHOWN];
            xy.push(i * W / (SHOWN - 1));
            xy.push(mid - s * lane * 0.45);
        }
        qt::draw_pen(COLORS[c], 1.5);
        qt::draw_polyline(xy);
        qt::draw_text(8.0, lane * c + 16.0, NAMES[c]);
        points_drawn += SHOWN;
    }
    qt::draw_end();
    frames++;
}

export "goose_qt_override" fn on_override(obj: u64, tag: u64, nargs: i64, depth: i64) -> i32 {
    if tag == T_PAINT {
        paint_scope(obj);
        return qt::OV_DONE;
    }
    return qt::OV_BASE;
}

fn drain() {
    var ev = default<qt::Event>();
    while qt::poll(ev) {
        if ev.tag >= T_SAMPLES && ev.tag < T_SAMPLES + CHANNELS {
            take((ev.tag - T_SAMPLES) as i64, ev.i0, ev.i1);
        } else if ev.tag == T_FRAME {
            // painted on the next update
        }
    }
}

fn main() {
    var selftest = false;
    for a in args() { if a == "--selftest" { selftest = true; } }
    let started = if selftest { qt::init(qt::APP_WIDGETS, "scope\0-platform\0offscreen") } else { qt::init() };
    if !started || !qt::use_overrides() {
        print("scope: ", qt::last_error_message());
        exit(1);
    }
    qt::set_queue_limit(200000);
    for _ in CHANNELS * SHOWN { rings.push(0.0); }

    let scope = qt::new_overridable("QWidget");
    qt::override(scope, "paintEvent", T_PAINT);
    scope.setWindowTitle("Goose scope: 4 channels");
    scope.resize(W as! i64, H as! i64);
    scope.show();

    let stop = qt::promise();   // a cancel token the workers watch
    var workers: i64[>..] = [];
    for c in CHANNELS { workers.push(thread_spawn(generate, c, stop.id)); }

    let t0 = clock_ns();
    if selftest {
        while clock_ns() - t0 < 3000000000 {
            qt::process_events();
            drain();
            let pm = scope.grab();   // offscreen, a grab is what paints
            pm.free();
        }
    } else {
        let timer = qt::timer(16, T_FRAME);
        var ev = default<qt::Event>();
        while qt::wait(-1) == qt::WAIT_EVENTS {
            drain();
            scope.update();
            if frames % 60 == 0 {
                let secs = (clock_ns() - t0) / 1e9;
                scope.setWindowTitle(str("Goose scope: ", (frames / secs) as i64, " frames/s, ",
                                         ((received[0] + received[1] + received[2] + received[3]) / secs) as i64, " samples/s"));
            }
        }
        qt::destroy(timer);
    }
    let seconds = (clock_ns() - t0) / 1e9;

    qt::cancel(stop);
    for id in workers { thread_wait(id); }
    qt::release(stop);
    drain();

    let total = received[0] + received[1] + received[2] + received[3];
    print("scope: ", frames, " frames in ", seconds, " s: ", (frames / seconds) as i64, " frames/s, ",
          (points_drawn / seconds) as i64, " points drawn/s");
    print("  samples from 4 worker threads: ", total, " (", (total / seconds) as i64, "/s, ", (total / 8 / seconds) as i64,
          " events/s), dropped ", qt::dropped_events());
    var ok = true;
    if selftest {
        for c in CHANNELS { if received[c] < 50000 { ok = false; } }
        ok = ok && frames / seconds >= 20.0 && qt::dropped_events() == 0 && qt::live_futures() == 0;
        print("scope: ", if ok { "ok" } else { "FAIL" });
    }
    qt::shutdown();
    if !ok { exit(1); }
}
