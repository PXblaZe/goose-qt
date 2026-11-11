// mandelbrot: the same fractal computed twice, by four Goose worker threads on the CPU and by a
// compute shader on the GPU through Qt's RHI (Vulkan, or OpenGL 4.3, whichever this machine
// has), then shown side by side and compared pixel by pixel. Native builds only (the JIT runs
// no threads):
//
//   goose build mandelbrot.goose -o mandelbrot && ./mandelbrot     a window with both images
//   ./mandelbrot --selftest       offscreen: timings, and how far the two images agree
//   ./mandelbrot --save           also writes cpu.png and gpu.png
//
// The workers hand their bands back through futures (qt::add_bytes); the images reach Qt as
// PPM bytes built in Goose (QImage::loadFromData).
import os;
import qt from "../..";

let W = 1024;
let H = 768;
let MAX_ITER = 255;
let CX = -0.6;
let CY = 0.0;
let SPAN = 3.2;            // the width of the view in the complex plane
let WORKERS = 4;

// --- the CPU: a band of rows per worker

fn iterations(px: i64, py: i64) -> i64 {
    let x0 = CX + (px / (W - 1.0) - 0.5) * SPAN;
    let y0 = CY + (py / (H - 1.0) - 0.5) * SPAN * H / W;
    var x = 0.0;
    var y = 0.0;
    var i = 0;
    while i < MAX_ITER && x * x + y * y <= 4.0 {
        let t = x * x - y * y + x0;
        y = 2.0 * x * y + y0;
        x = t;
        i++;
    }
    return i;
}

thread_fn band(id: u64, row0: i64, rows: i64) {
    let f = qt::Future { id: id };
    var out: u8[>..] = [];
    for r in rows {
        for px in W { out.push(iterations(px, row0 + r) as u8); }
    }
    qt::add_bytes(f, out);
    qt::finish(f);
}

fn cpu_render(out: u8[>..]&) -> bool {
    var futures: qt::Future[>..] = [];
    var threads: i64[>..] = [];
    let rows = H / WORKERS;
    for k in WORKERS {
        let f = qt::promise();
        futures.push(f);
        threads.push(thread_spawn(band, f.id, k * rows, rows));
    }
    var ok = true;
    for k in WORKERS {
        if qt::wait(futures[k], 60000) != qt::WAIT_FINISHED { ok = false; }
        let part = qt::result_str(futures[k], 0);   // the band's bytes
        for b in part { out.push(b); }
        qt::release(futures[k]);
    }
    for t in threads { thread_wait(t); }
    return ok && out.len == W * H;
}

// --- the GPU: one invocation per pixel, in single precision

fn shader() -> u8[>..] {
    return str("""
        #version 440
        layout(local_size_x = 16, local_size_y = 16) in;
        layout(std430, binding = 0) writeonly buffer Out { uint it[]; };
        void main() {
            uint px = gl_GlobalInvocationID.x;
            uint py = gl_GlobalInvocationID.y;
        """,
        "    if (px >= ", W, "u || py >= ", H, "u) return;\n",
        "    float x0 = ", CX, " + (float(px) / ", W - 1, ".0 - 0.5) * ", SPAN, ";\n",
        "    float y0 = ", CY, " + (float(py) / ", H - 1, ".0 - 0.5) * ", SPAN * H / W, ";\n",
        """
            float x = 0.0, y = 0.0;
            uint i = 0u;
        """,
        "    while (i < ", MAX_ITER, "u && x * x + y * y <= 4.0) {\n",
        """
                float t = x * x - y * y + x0;
                y = 2.0 * x * y + y0;
                x = t;
                i++;
            }
        """,
        "    it[py * ", W, "u + px] = i;\n}\n");
}

struct GpuRun { ok: bool, backend: i64, bake_ms: f64, run_ms: f64 }

fn backend_name(b: i64) -> const u8[:] {
    if b == qt::RHI_VULKAN { return "Vulkan"; }
    if b == qt::RHI_OPENGL { return "OpenGL"; }
    return "no backend with compute";
}

fn gpu_render(out: u8[>..]&) -> GpuRun {
    var run = GpuRun { ok: false, backend: -1, bake_ms: 0.0, run_ms: 0.0 };
    qt::set_error_policy(qt::ERRORS_RETURN);   // a backend this machine lacks is not an error here
    var r = qt::rhi_create(qt::RHI_VULKAN);
    run.backend = qt::RHI_VULKAN;
    if !qt::ok(r) || !qt::supports(r, qt::FEATURE_COMPUTE) {
        if qt::ok(r) { qt::destroy(r); }
        r = qt::rhi_create(qt::RHI_OPENGL);
        run.backend = qt::RHI_OPENGL;
    }
    if !qt::ok(r) || !qt::supports(r, qt::FEATURE_COMPUTE) || !qt::supports(r, qt::FEATURE_READ_BACK_BUFFERS) {
        if qt::ok(r) { qt::destroy(r); }
        qt::set_error_policy(qt::ERRORS_LOG);
        run.backend = -1;
        return run;
    }
    var t = clock_ns();
    let cs = qt::shader_bake(qt::COMPUTE, shader());
    run.bake_ms = (clock_ns() - t) / 1e6;
    if !qt::ok(cs) { print("mandelbrot: the shader: ", qt::last_error_message()); return run; }
    t = clock_ns();
    let sb = qt::buffer(r, qt::STATIC, qt::STORAGE_BUFFER, W * H * 4);
    let srb = qt::bindings(r);
    qt::bind_storage(srb, 0, qt::COMPUTE, sb, qt::STORE);
    qt::create(srb);
    let cp = qt::compute_pipeline(r, cs, srb);
    var rb = qt::Gpu { h: 0 };
    if qt::ok(cp) && qt::begin_frame(r) == qt::OK {
        qt::begin_compute(r);
        qt::set_pipeline(r, cp);
        qt::set_bindings(r, srb);
        qt::dispatch(r, W / 16, H / 16, 1);
        qt::end_pass(r);
        rb = qt::read_buffer(sb, 0, W * H * 4);
        qt::end_frame(r);
        qt::finish(r);
    }
    let words = qt::bytes(rb);
    run.run_ms = (clock_ns() - t) / 1e6;
    if words.len == W * H * 4 {
        for i in W * H { out.push(words[4 * i]); }   // the low byte: iterations never pass 255
        run.ok = true;
    }
    qt::destroy(cs);
    qt::destroy(r);   // the buffer, bindings and pipeline go with it
    qt::set_error_policy(qt::ERRORS_LOG);
    return run;
}

// --- iterations to an image

fn color(i: u8) -> u32 {
    if i as i64 >= MAX_ITER { return 0x000000; }
    let t = i / (MAX_ITER + 0.0);
    let r = (9.0 * (1.0 - t) * t * t * t * 255.0) as! i64;
    let g = (15.0 * (1.0 - t) * (1.0 - t) * t * t * 255.0) as! i64;
    let b = (8.5 * (1.0 - t) * (1.0 - t) * (1.0 - t) * t * 255.0) as! i64;
    return ((r << 16) | (g << 8) | b) as u32;
}

fn to_image(its: const u8[:]) -> qt::Val {
    var ppm = str("P6\n", W, " ", H, "\n255\n");
    for i in its {
        let c = color(i);
        ppm.push((c >> 16) as u8);
        ppm.push((c >> 8) as u8);
        ppm.push(c as u8);
    }
    let img = qt::QImage();
    img.loadFromData(ppm, "PPM");
    return img;
}

fn shown(img: qt::Val, title: const u8[:]) -> qt::Obj {
    let label = qt::QLabel();
    let pm = qt::QPixmap_fromImage(img);
    label.setPixmap(pm);
    label.setToolTip(title);
    pm.free();
    return label;
}

// one decimal place: lavapipe runs the shader on the CPU and manages well under 1 Mpixel/s
fn one_dec(v: f64) -> u8[>..] {
    let t = (v * 10.0 + 0.5) as! i64;
    return str(t / 10, ".", t % 10);
}

fn main() {
    var selftest = false;
    var save = false;
    for a in args() {
        if a == "--selftest" { selftest = true; }
        if a == "--save" { save = true; }
    }
    // the self-test runs offscreen when there is no display, where no GPU context can be made
    var display = str("");
    let has_display = env("DISPLAY", display) || env("WAYLAND_DISPLAY", display);
    let started = if selftest && !has_display { qt::init(qt::APP_WIDGETS, "mandelbrot\0-platform\0offscreen") } else { qt::init() };
    if !started { print("mandelbrot: ", qt::last_error_message()); exit(1); }

    var cpu: u8[>..] = [];
    var t = clock_ns();
    let cpu_ok = cpu_render(cpu);
    let cpu_ms = (clock_ns() - t) / 1e6;

    var gpu: u8[>..] = [];
    let g = gpu_render(gpu);

    // how far they agree: single against double precision differs along the edge of the set
    var same = 0;
    var close = 0;
    if g.ok {
        for i in W * H {
            let d = cpu[i] as i64 - gpu[i];
            if d == 0 { same++; }
            if d >= -3 && d <= 3 { close++; }
        }
    }

    let cpu_img = to_image(cpu);
    var gpu_img = qt::QImage();
    if g.ok { gpu_img.free(); gpu_img = to_image(gpu); }
    if save {
        cpu_img.save("cpu.png");
        if g.ok { gpu_img.save("gpu.png"); }
    }

    let mpix = W * H / 1e6;
    print("mandelbrot: ", W, " x ", H, ", up to ", MAX_ITER, " iterations a pixel");
    print("  CPU, ", WORKERS, " Goose threads   ", cpu_ms as i64, " ms (", one_dec(mpix / cpu_ms * 1000.0), " Mpixel/s)");
    if g.ok {
        print("  GPU, ", backend_name(g.backend), " compute  ", g.run_ms as i64, " ms (", one_dec(mpix / g.run_ms * 1000.0),
              " Mpixel/s, with set-up and read-back; the shader baked in ", g.bake_ms as i64, " ms)");
        print("  agreement: ", same * 100 / (W * H), "% of pixels equal, ", close * 100 / (W * H), "% within 3 iterations");
    } else {
        print("  GPU: ", backend_name(g.backend), " here");
    }

    var ok = cpu_ok && cpu[(H / 2) * W + W / 2 - 100] as i64 == MAX_ITER && cpu[0] < 5;
    if g.ok { ok = ok && close * 100 >= 97 * W * H; }

    if !selftest {
        let window = qt::QWidget();
        window.setWindowTitle(str("Mandelbrot: CPU ", cpu_ms as i64, " ms | GPU (", backend_name(g.backend), ") ", g.run_ms as i64, " ms"));
        let row = qt::QHBoxLayout(window);
        row.addWidget(shown(cpu_img, "CPU"));
        if g.ok { row.addWidget(shown(gpu_img, "GPU")); }
        window.show();
        while qt::wait(-1) == qt::WAIT_EVENTS { var ev = default<qt::Event>(); while qt::poll(ev) {} }
    } else {
        print("mandelbrot: ", if ok { "ok" } else { "FAIL" });
    }
    cpu_img.free();
    gpu_img.free();
    qt::shutdown();
    if !ok { exit(1); }
}
