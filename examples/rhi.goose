// rhi: a spinning triangle in a window, drawn with Qt's RHI (Vulkan, OpenGL, Direct3D or Metal,
// whichever this machine has; the Null backend otherwise).
//
//   goose rhi.goose                   draws until the window is closed
//   goose rhi.goose -- --selftest     draws a few frames offscreen, reads one back, checks it
//
// Shaders are Vulkan-style GLSL in raw strings, compiled at run time for the backend in use.
import os;
import math;
import qt from "..";

let VS = """
    #version 440
    layout(location = 0) in vec2 pos;
    layout(location = 1) in vec3 color;
    layout(location = 0) out vec3 v_color;
    layout(std140, binding = 0) uniform buf { vec4 rot; vec4 flip; };
    void main() {
        v_color = color;
        vec2 p = vec2(rot.x * pos.x - rot.y * pos.y, rot.y * pos.x + rot.x * pos.y);
        gl_Position = vec4(p.x, p.y * flip.x, 0.0, 1.0);
    }
    """;
let FS = """
    #version 440
    layout(location = 0) in vec3 v_color;
    layout(location = 0) out vec4 frag;
    void main() {
        frag = vec4(v_color, 1.0);
    }
    """;
let CLEAR: u32 = 0xff181820;

fn main() {
    let argv = args();
    let selftest = argv.len > 1 && argv[1] == "--selftest";
    if !qt::init(qt::APP_GUI) { exit(1); }

    // the first backend this machine has (the failures on the way are expected: quiet them)
    qt::set_error_policy(qt::ERRORS_RETURN);
    var r = qt::Gpu { h: 0 };
    var backend = 0;
    for b in [qt::RHI_VULKAN, qt::RHI_METAL, qt::RHI_D3D11, qt::RHI_OPENGL, qt::RHI_NULL] {
        if !qt::ok(r) { r = qt::rhi_create(b); backend = b; }
    }
    qt::set_error_policy(qt::ERRORS_LOG);
    if !qt::ok(r) { exit(1); }
    print("rhi: ", qt::info(r));
    // Vulkan's clip space has y pointing down
    var flip = 1.0;
    if backend == qt::RHI_VULKAN { flip = -1.0; }

    var window = qt::NONE;
    var target = qt::Gpu { h: 0 };
    var tex = qt::Gpu { h: 0 };
    if selftest {
        tex = qt::texture(r, qt::RGBA8, 128, 128, qt::RENDER_TARGET | qt::READABLE);
        target = qt::render_target(tex, false);
    } else {
        window = qt::new_object("QWindow");
        qt::set(window, "title", "goose-qt RHI");
        window.resize(480, 480);
        target = qt::swapchain(r, window, 0);
        if !qt::ok(target) { exit(1); }
        window.show();
    }
    let vb = qt::buffer(r, qt::IMMUTABLE, qt::VERTEX_BUFFER, 3 * 20);
    qt::upload_f32(vb, 0, [0.0, 0.8, 1.0, 0.2, 0.2,  -0.7, -0.6, 0.2, 1.0, 0.2,  0.7, -0.6, 0.2, 0.4, 1.0]);
    let ub = qt::buffer(r, qt::DYNAMIC, qt::UNIFORM_BUFFER, 32);
    let srb = qt::bindings(r);
    qt::bind_uniform(srb, 0, qt::VERTEX, ub, 0, 32);
    qt::create(srb);
    let p = qt::pipeline(r);
    qt::shaders(p, qt::shader_bake(qt::VERTEX, VS), qt::shader_bake(qt::FRAGMENT, FS));
    qt::vertex_binding(p, 20, false);
    qt::vertex_attribute(p, 0, 0, qt::FLOAT2, 0);
    qt::vertex_attribute(p, 0, 1, qt::FLOAT3, 8);
    if !qt::create(p, srb, target) { exit(1); }

    var frames = 0;
    var ok = true;
    var rb = qt::Gpu { h: 0 };
    loop {
        if !selftest {
            if qt::wait(16) == qt::WAIT_QUIT { break; }
            var ev = default<qt::Event>();
            while qt::poll(ev) {}
        }
        var angle = 0.0;
        if !selftest { angle = frames as f64 * 0.02; }
        var st = 0;
        if selftest { st = qt::begin_frame(r); } else { st = qt::begin_frame(r, target); }
        if st == qt::RHI_SKIPPED { continue; }   // the window is hidden or minimized
        if st != qt::OK { ok = false; break; }
        qt::upload_f32(ub, 0, [cos(angle), sin(angle), 0.0, 0.0, flip, 0.0, 0.0, 0.0]);
        qt::begin_pass(r, target, CLEAR);
        qt::set_pipeline(r, p);
        qt::set_bindings(r, srb);
        qt::set_vertex_buffer(r, 0, vb, 0);
        qt::draw(r, 3);
        qt::end_pass(r);
        if selftest && frames == 2 { rb = qt::read_texture(tex); }
        if !qt::end_frame(r) { ok = false; break; }
        frames++;
        if selftest && frames == 3 { break; }
    }
    if selftest {
        // the triangle's middle is drawn (on a backend that draws), a corner is the clear color
        let img = qt::image(rb);
        ok = ok && img.h != 0;
        if img.h != 0 && backend != qt::RHI_NULL {
            ok = ok && img.pixel(64, 64) != CLEAR as i64 && img.pixel(2, 2) == CLEAR as i64;
        }
        print("rhi: ", frames, " frames, ", if ok { "ok" } else { "FAILED" });
    }
    qt::shutdown();   // everything made with the RHI goes with it
    if !ok { exit(1); }
}
