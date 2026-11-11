// Graphics from Goose: Qt's RHI on the Null backend (and on OpenGL or Vulkan where the machine
// has them), with every command checked; Qt Quick's choice of API.
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

let VS = """
    #version 440
    layout(location = 0) in vec2 pos;
    layout(location = 1) in vec3 color;
    layout(location = 0) out vec3 v_color;
    layout(std140, binding = 0) uniform buf { vec4 tint; };
    void main() {
        v_color = color * tint.rgb;
        gl_Position = vec4(pos, 0.0, 1.0);
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
let CS = """
    #version 440
    layout(local_size_x = 16) in;
    layout(std430, binding = 0) buffer Data { uint vals[]; };
    void main() {
        uint i = gl_GlobalInvocationID.x;
        vals[i] = i + 100u;
    }
    """;

fn render(backend: i64, name: const u8[:]) {
    let r = qt::rhi_create(backend);
    if !qt::ok(r) {
        print("  ", name, ": not available here");
        return;
    }
    let real = backend != qt::RHI_NULL;
    let tex = qt::texture(r, qt::RGBA8, 32, 32, qt::RENDER_TARGET | qt::READABLE);
    let rt = qt::render_target(tex, false);
    let ub = qt::buffer(r, qt::DYNAMIC, qt::UNIFORM_BUFFER, 64);
    check(qt::upload_f32(ub, 0, [1.0, 1.0, 1.0, 1.0]), "uniforms uploaded");
    // the left half, green: x, y, r, g, b per vertex
    let vb = qt::buffer(r, qt::IMMUTABLE, qt::VERTEX_BUFFER, 6 * 20);
    check(qt::upload_f32(vb, 0, [-1.0, -1.0, 0.0, 1.0, 0.0,  0.0, -1.0, 0.0, 1.0, 0.0,  0.0, 1.0, 0.0, 1.0, 0.0,
                                 -1.0, -1.0, 0.0, 1.0, 0.0,  0.0, 1.0, 0.0, 1.0, 0.0,  -1.0, 1.0, 0.0, 1.0, 0.0]),
          "vertices uploaded");
    let srb = qt::bindings(r);
    check(qt::bind_uniform(srb, 0, qt::VERTEX, ub, 0, 16), "uniform bound");
    check(qt::create(srb), "bindings created");
    let vs = qt::shader_bake(qt::VERTEX, VS);
    let fs = qt::shader_bake(qt::FRAGMENT, FS);
    check(qt::ok(vs) && qt::ok(fs), "shaders compiled");
    let p = qt::pipeline(r);
    check(qt::shaders(p, vs, fs), "pipeline shaders");
    check(qt::vertex_binding(p, 20, false), "vertex binding");
    check(qt::vertex_attribute(p, 0, 0, qt::FLOAT2, 0), "position");
    check(!qt::create(p, srb, rt), "a shader input without an attribute is refused");
    check(qt::vertex_attribute(p, 0, 1, qt::FLOAT3, 8), "color");
    check(qt::create(p, srb, rt), "pipeline created");

    check(qt::begin_frame(r) == qt::OK, "frame");
    check(qt::begin_pass(r, rt, 0xFFFF0000), "pass");
    check(qt::set_pipeline(r, p), "pipeline set");
    check(qt::set_bindings(r, srb), "bindings set");
    check(qt::set_vertex_buffer(r, 0, vb, 0), "vertex buffer set");
    check(!qt::draw(r, 7), "seven vertices from a buffer of six are refused");
    check(qt::last_error() == qt::ERR_OUT_OF_RANGE, "out of range");
    check(qt::draw(r, 6), "drawn");
    check(qt::end_pass(r), "pass ended");
    let rb = qt::read_texture(tex);
    check(qt::end_frame(r), "frame ended");
    check(qt::ready(rb), "read back");
    let px = qt::bytes(rb);
    check(px.len == 32 * 32 * 4, "every pixel");
    if real && px.len == 32 * 32 * 4 {
        let left = (16 * 32 + 2) * 4;
        let right = (16 * 32 + 29) * 4;
        check(px[left] == 0 && px[left + 1] == 255 && px[left + 2] == 0, "green on the left");
        check(px[right] == 255 && px[right + 1] == 0 && px[right + 2] == 0, "red on the right");
    }

    // compute: a storage buffer written by a shader
    if qt::supports(r, qt::FEATURE_COMPUTE) && qt::supports(r, qt::FEATURE_READ_BACK_BUFFERS) {
        let cs = qt::shader_bake(qt::COMPUTE, CS);
        let sb = qt::buffer(r, qt::STATIC, qt::STORAGE_BUFFER, 16 * 4);
        let s2 = qt::bindings(r);
        check(qt::bind_storage(s2, 0, qt::COMPUTE, sb, qt::LOAD_STORE), "storage bound");
        check(qt::create(s2), "created");
        let cp = qt::compute_pipeline(r, cs, s2);
        check(qt::ok(cp), "compute pipeline");
        check(qt::begin_frame(r) == qt::OK, "compute frame");
        check(qt::begin_compute(r), "compute pass");
        check(qt::set_pipeline(r, cp), "set");
        check(qt::set_bindings(r, s2), "bound");
        check(qt::dispatch(r, 1, 1, 1), "dispatched");
        check(qt::end_pass(r), "ended");
        let rb2 = qt::read_buffer(sb, 0, 64);
        check(qt::end_frame(r), "frame ended");
        let b = qt::bytes(rb2);
        check(b.len == 64, "read back");
        if real && b.len == 64 { check(b[4 * 7] == 107, "the shader's values"); }
        qt::destroy(cs);   // shaders are not the RHI's
    }

    // destroying in the wrong order is refused; the RHI takes everything with it
    check(!qt::destroy(ub), "a buffer the bindings use stays");
    check(qt::destroy(r), "the RHI goes");
    check(!qt::destroy(tex), "and its texture with it");
    check(qt::last_error() == qt::ERR_STALE_HANDLE, "stale");
    qt::destroy(vs);
    qt::destroy(fs);
    print("  ", name, ": rendered");
}

fn main() {
    check(qt::init(), "init");
    qt::set_error_policy(qt::ERRORS_RETURN);
    let live0 = qt::rhi_live();
    render(qt::RHI_NULL, "Null");
    render(qt::RHI_OPENGL, "OpenGL");
    render(qt::RHI_VULKAN, "Vulkan");
    check(qt::rhi_live() == live0, "nothing left behind");
    check(!qt::ok(qt::rhi_create(99)), "unknown backends are refused");
    check(!qt::ok(qt::shader_bake(qt::VERTEX, "#version 440\nvoid main() { nonsense }\n")), "bad GLSL is refused");
    check(qt::last_error_message().len > 20, "with the compiler's message");
    check(qt::quick_set_graphics_api(qt::GAPI_SOFTWARE), "Qt Quick's API chosen");
    check(qt::quick_graphics_api() == qt::GAPI_SOFTWARE, "and reported");
    let n = qt::native(qt::rhi_create(qt::RHI_NULL));
    check(n.backend == qt::RHI_NULL, "native handles");
    check(qt::shutdown(), "shutdown with an RHI left alive");
    print("t09_graphics: ", checks - failures, " passed, ", failures, " failed");
    if failures > 0 { exit(1); }
}
