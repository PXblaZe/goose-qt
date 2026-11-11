# Graphics

goose-qt binds Qt's RHI, the layer Qt Quick itself renders through: one API over Vulkan,
Metal, Direct3D 11 and 12, and OpenGL (ES), plus a Null backend that checks everything and
draws nothing. Shaders are written once, as Vulkan-style GLSL, and compiled at run time for
whichever backend is in use. The [rhi example](../examples/rhi.goose) draws a spinning
triangle in a window; the [mandelbrot sample](../samples/mandelbrot/mandelbrot.goose) runs a
compute shader and reads the results back.

Every RHI handle (the RHI itself, buffers, textures, pipelines, shaders, readbacks) is a
`qt::Gpu`. `qt::ok(g)` says whether one was made.

## Choosing a backend

```goose
qt::init(qt::APP_GUI);
qt::set_error_policy(qt::ERRORS_RETURN);      // a backend this machine lacks is not an error here
var r = qt::Gpu { h: 0 };
for b in [qt::RHI_VULKAN, qt::RHI_METAL, qt::RHI_D3D11, qt::RHI_OPENGL, qt::RHI_NULL] {
    if !qt::ok(r) { r = qt::rhi_create(b); }
}
qt::set_error_policy(qt::ERRORS_LOG);
print(qt::info(r));                            // JSON: backend, driver, limits, features
if qt::supports(r, qt::FEATURE_COMPUTE) { ... }
```

`qt::rhi_create(backend, qt::RHI_DEBUG)` turns on the backend's validation (the Vulkan
validation layers, when installed). The offscreen platform offers no GPU context; with no
display, run under `xvfb-run` for Vulkan or OpenGL, or use `RHI_NULL`.

## Drawing a frame

```goose
// where to draw: a texture you read back, or a window's swapchain
let tex = qt::texture(r, qt::RGBA8, 256, 256, qt::RENDER_TARGET | qt::READABLE);
let rt = qt::render_target(tex, false);              // false: no depth buffer

// what to draw
let vb = qt::buffer(r, qt::IMMUTABLE, qt::VERTEX_BUFFER, 3 * 20);
qt::upload_f32(vb, 0, [0.0, 0.8, 1.0, 0.2, 0.2,  -0.7, -0.6, 0.2, 1.0, 0.2,  0.7, -0.6, 0.2, 0.4, 1.0]);
let ub = qt::buffer(r, qt::DYNAMIC, qt::UNIFORM_BUFFER, 32);
let srb = qt::bindings(r);
qt::bind_uniform(srb, 0, qt::VERTEX, ub, 0, 32);
qt::create(srb);

let p = qt::pipeline(r);
qt::shaders(p, qt::shader_bake(qt::VERTEX, VS), qt::shader_bake(qt::FRAGMENT, FS));
qt::vertex_binding(p, 20, false);                    // 20 bytes a vertex
qt::vertex_attribute(p, 0, 0, qt::FLOAT2, 0);        // binding 0, location 0: position
qt::vertex_attribute(p, 0, 1, qt::FLOAT3, 8);        // location 1: colour
qt::create(p, srb, rt);

qt::begin_frame(r);
qt::upload_f32(ub, 0, [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0]);
qt::begin_pass(r, rt, 0xff181820);                   // clear colour
qt::set_pipeline(r, p);
qt::set_bindings(r, srb);
qt::set_vertex_buffer(r, 0, vb, 0);
qt::draw(r, 3);
qt::end_pass(r);
let rb = qt::read_texture(tex);
qt::end_frame(r);
let image = qt::image(rb);                           // a QImage value
```

For a window, make a `QWindow`, `qt::swapchain(r, window, flags)` (`qt::SC_DEPTH`,
`SC_READABLE`, `SC_NO_VSYNC`), and `qt::begin_frame(r, swapchain)` each frame:
`qt::RHI_SKIPPED` means the window cannot show a frame now (hidden, minimized), so skip it.
Inside a widget UI, override a `QRhiWidget`'s `initialize` and `render` and get its RHI and
target with `qt::rhi_widget(w)` and `qt::rhi_widget_target(w)`.

| Area | Calls |
|---|---|
| resources | `buffer(r, IMMUTABLE/STATIC/DYNAMIC, VERTEX/INDEX/UNIFORM/STORAGE_BUFFER, size)`, `texture(r, format, w, h, RENDER_TARGET/READABLE/STORAGE_IMAGE)`, `sampler(r, linear, repeat)`, `render_target`, `swapchain` |
| uploads | `upload(buf, offset, bytes)`, `upload_f32`, `upload_u16`, `upload_u32`, `upload_image(tex, img)`, `upload_pixels` |
| bindings | `bindings(r)`, `bind_uniform`, `bind_texture`, `bind_storage`, `bind_image`, `create(srb)` |
| pipelines | `pipeline`, `shaders`, `vertex_binding`, `vertex_attribute`, `options(p, topology, cull, blend, depth_test, depth_write)`, `create(p, srb, target)`, `compute_pipeline(r, shader, srb)` |
| frames | `begin_frame`, `begin_pass`, `begin_compute`, `set_pipeline`, `set_bindings`, `set_viewport`, `set_vertex_buffer`, `set_index_buffer`, `draw`, `draw_indexed`, `dispatch`, `end_pass`, `end_frame`, `finish` |
| readback | `read_texture`, `read_buffer`, `read_swapchain`, then `ready(rb)`, `bytes(rb)`, `image(rb)` |
| shaders | `shader_bake(stage, glsl)`, `shader_save(s)` / `shader_load(qsb)` to cache baked shaders, `shader_reflect(s)` (JSON) |

## Compute

```goose
let cs = qt::shader_bake(qt::COMPUTE, """
    #version 440
    layout(local_size_x = 64) in;
    layout(std430, binding = 0) writeonly buffer Out { uint v[]; };
    void main() { v[gl_GlobalInvocationID.x] = gl_GlobalInvocationID.x * 2u; }
    """);
let sb = qt::buffer(r, qt::STATIC, qt::STORAGE_BUFFER, 1024 * 4);
let srb = qt::bindings(r);
qt::bind_storage(srb, 0, qt::COMPUTE, sb, qt::STORE);
qt::create(srb);
let cp = qt::compute_pipeline(r, cs, srb);
qt::begin_frame(r);
qt::begin_compute(r);
qt::set_pipeline(r, cp);
qt::set_bindings(r, srb);
qt::dispatch(r, 1024 / 64, 1, 1);
qt::end_pass(r);
let rb = qt::read_buffer(sb, 0, 1024 * 4);
qt::end_frame(r);
qt::finish(r);
let words = qt::bytes(rb);                 // 4,096 bytes, little-endian uints
```

The binding's access (`qt::LOAD`, `STORE`, `LOAD_STORE`) must match how the shader uses the
buffer: a buffer bound `STORE` must be declared `writeonly` (or the shader must not read it),
or the pipeline is refused.

## What is checked

Qt's RHI checks little in release builds, and nothing about memory. qtc checks every command
before Qt sees it:

- pipelines against their shaders' reflection data: vertex attributes, the interface between
  stages, and bindings (type, stage and access);
- every draw against the buffers' sizes, so no vertex or index is fetched past the end, and
  indexed draws against the largest index the GPU will see;
- frames and passes in order, dispatch sizes against the device's limits;
- lifetimes: resources keep what they use alive, destroying the RHI destroys everything made
  with it in order, and a resource destroyed mid-frame goes once the frame is submitted.

What a shader computes is not checked: a shader that indexes a storage buffer out of bounds
is undefined behaviour on the GPU, as in C++. See [qtc's limits](../../qtc/docs/LIMITS.md#graphics).

## Interop

For code that talks to the graphics API directly: `qt::native(r)` gives the native handles
(Vulkan instance, device, queue …), `qt::native_object(res)` a resource's native object,
`qt::begin_external(r)` / `end_external` bracket native commands inside a frame,
`qt::gl_proc_address(name)` resolves OpenGL functions, and `qt::vk_create`,
`vk_proc_address`, `vk_surface` set up Vulkan for code that does its own rendering. What that
code does is outside qtc's checks.

Qt Quick's choice of graphics API is set with `qt::quick_set_graphics_api(qt::GAPI_VULKAN)`
before its first window, and read with `qt::quick_graphics_api(window)`.
