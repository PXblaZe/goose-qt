// goose-qt, the parts on top of Qt's classes: overridable objects (subclassing Qt classes),
// runtime-defined classes, futures and promises, worker objects, and graphics (Qt's RHI over
// Vulkan, OpenGL, Direct3D and Metal). Part of namespace qt; see qt.goose.
namespace qt;

import binary;

// ------------------------------------------------------------- C side

extern fn gq_override_handler() -> u64;
extern fn gq_has_override_handler() -> bool;

extern "qtc" {
    // overridable objects
    fn qtc_new_overridable(class_name: const u8[:]) -> u64;
    fn qtc_is_overridable(obj: u64) -> bool;
    fn qtc_overridable_classes() -> View;
    fn qtc_overridable_methods(class_name: const u8[:]) -> View;
    fn qtc_override(obj: u64, method: const u8[:], tag: u64) -> i32;
    fn qtc_set_override_handler(handler: u64, user: u64) -> i32;
    fn qtc_ov_arg_kind(index: i32) -> i32;
    fn qtc_ov_arg_type(index: i32) -> View;
    fn qtc_ov_arg_bool(index: i32) -> bool;
    fn qtc_ov_arg_int(index: i32) -> i64;
    fn qtc_ov_arg_double(index: i32) -> f64;
    fn qtc_ov_arg_str(index: i32) -> View;
    fn qtc_ov_arg_obj(index: i32) -> u64;
    fn qtc_ov_arg_val(index: i32) -> u64;
    fn qtc_ov_arg_event(index: i32, out: Event&) -> i32;
    fn qtc_ov_event_text(index: i32) -> View;
    fn qtc_ov_accept_event(index: i32, accepted: bool) -> i32;
    fn qtc_ov_arg_index(index: i32, row: i32&, column: i32&, id: u64&) -> bool;
    fn qtc_ov_set_arg_int(index: i32, v: i64) -> i32;
    fn qtc_ov_set_arg_str(index: i32, v: const u8[:]) -> i32;
    fn qtc_ov_buffer_write(index: i32, bytes: const u8[:]) -> i64;
    fn qtc_ov_buffer_read(index: i32) -> View;
    fn qtc_ov_ret_bool(v: bool) -> i32;
    fn qtc_ov_ret_int(v: i64) -> i32;
    fn qtc_ov_ret_uint(v: u64) -> i32;
    fn qtc_ov_ret_double(v: f64) -> i32;
    fn qtc_ov_ret_str(v: const u8[:]) -> i32;
    fn qtc_ov_ret_bytes(v: const u8[:]) -> i32;
    fn qtc_ov_ret_val(v: u64) -> i32;
    fn qtc_ov_ret_index(row: i32, column: i32, id: u64) -> i32;
    fn qtc_ov_call_base() -> i32;
    fn qtc_ov_depth() -> i32;
    fn qtc_draw_begin_painter(arg_index: i32) -> i32;
    // runtime classes
    fn qtc_class_begin(name: const u8[:], base: const u8[:]) -> i32;
    fn qtc_class_signal(signature: const u8[:]) -> i32;
    fn qtc_class_slot(signature: const u8[:], return_type: const u8[:], tag: u64) -> i32;
    fn qtc_class_invokable(signature: const u8[:], return_type: const u8[:], tag: u64) -> i32;
    fn qtc_class_property(name: const u8[:], type_name: const u8[:], flags: u32) -> i32;
    fn qtc_class_end() -> i32;
    fn qtc_class_cancel() -> i32;
    fn qtc_class_exists_runtime(class_name: const u8[:]) -> bool;
    fn qtc_class_new(class_name: const u8[:]) -> u64;
    fn qtc_emit(obj: u64, signal: const u8[:]) -> i32;
    // futures, promises, workers
    fn qtc_promise_new() -> u64;
    fn qtc_promise_progress_range(f: u64, min: i32, max: i32) -> i32;
    fn qtc_promise_progress(f: u64, value: i32, text: const u8[:]) -> i32;
    fn qtc_promise_add_bool(f: u64, v: bool) -> i32;
    fn qtc_promise_add_int(f: u64, v: i64) -> i32;
    fn qtc_promise_add_double(f: u64, v: f64) -> i32;
    fn qtc_promise_add_str(f: u64, v: const u8[:]) -> i32;
    fn qtc_promise_add_bytes(f: u64, v: const u8[:]) -> i32;
    fn qtc_promise_add_f64s(f: u64, v: const f64[:]) -> i32;
    fn qtc_promise_add_json(f: u64, json: const u8[:]) -> i32;
    fn qtc_promise_add_val(f: u64, v: u64) -> i32;
    fn qtc_promise_fail(f: u64, message: const u8[:]) -> i32;
    fn qtc_promise_finish(f: u64) -> i32;
    fn qtc_promise_canceled(f: u64) -> bool;
    fn qtc_promise_suspend_if_requested(f: u64) -> i32;
    fn qtc_future_state(f: u64) -> i32;
    fn qtc_future_result_count(f: u64) -> i64;
    fn qtc_future_progress(f: u64, value: i32&, min: i32&, max: i32&) -> i32;
    fn qtc_future_result(f: u64, index: i64) -> i32;
    fn qtc_future_error(f: u64) -> View;
    fn qtc_future_cancel(f: u64) -> i32;
    fn qtc_future_suspend(f: u64, suspend: bool) -> i32;
    fn qtc_future_wait(f: u64, timeout_ms: i64) -> i32;
    fn qtc_future_release(f: u64) -> i32;
    fn qtc_future_all(a: u64, b: u64) -> u64;
    fn qtc_future_any(a: u64, b: u64) -> u64;
    fn qtc_future_watch(f: u64, tag: u64) -> u64;
    fn qtc_future_unwatch(watch: u64) -> i32;
    fn qtc_live_futures() -> i64;
    fn qtc_move_to_thread(obj: u64, thread: u64) -> i32;
    fn qtc_invoke_queued(obj: u64, method: const u8[:]) -> i32;
    fn qtc_invoke_future(obj: u64, method: const u8[:]) -> u64;
    // graphics
    fn qtc_quick_set_graphics_api(api: i32) -> i32;
    fn qtc_quick_graphics_api(window: u64) -> i32;
    fn qtc_gl_proc_address(name: const u8[:]) -> u64;
    fn qtc_rhi_create(backend: i32, flags: u32) -> u64;
    fn qtc_rhi_destroy(h: u64) -> i32;
    fn qtc_rhi_info(rhi: u64) -> View;
    fn qtc_rhi_supports(rhi: u64, feature: i32) -> bool;
    fn qtc_rhi_live() -> i64;
    fn qtc_rhi_finish(rhi: u64) -> i32;
    fn qtc_rhi_shader_bake(stage: u32, glsl: const u8[:]) -> u64;
    fn qtc_rhi_shader_load(qsb: const u8[:]) -> u64;
    fn qtc_rhi_shader_save(shader: u64) -> View;
    fn qtc_rhi_shader_reflect(shader: u64) -> View;
    fn qtc_rhi_buffer(rhi: u64, type_: i32, usage: u32, size: i64) -> u64;
    fn qtc_rhi_texture(rhi: u64, format: i32, w: i32, h: i32, flags: u32) -> u64;
    fn qtc_rhi_sampler(rhi: u64, linear: bool, repeat: bool) -> u64;
    fn qtc_rhi_render_target(texture: u64, depth: bool) -> u64;
    fn qtc_rhi_swapchain(rhi: u64, window: u64, flags: u32) -> u64;
    fn qtc_rhi_bindings(rhi: u64) -> u64;
    fn qtc_rhi_bind_uniform(srb: u64, binding: i32, stages: u32, buffer: u64, offset: i64, size: i64) -> i32;
    fn qtc_rhi_bind_texture(srb: u64, binding: i32, stages: u32, texture: u64, sampler: u64) -> i32;
    fn qtc_rhi_bind_storage(srb: u64, binding: i32, stages: u32, buffer: u64, access: i32) -> i32;
    fn qtc_rhi_bind_image(srb: u64, binding: i32, stages: u32, texture: u64, access: i32) -> i32;
    fn qtc_rhi_bindings_create(srb: u64) -> i32;
    fn qtc_rhi_pipeline(rhi: u64) -> u64;
    fn qtc_rhi_pipeline_shaders(p: u64, vertex: u64, fragment: u64) -> i32;
    fn qtc_rhi_pipeline_vertex_binding(p: u64, stride: i32, per_instance: bool) -> i32;
    fn qtc_rhi_pipeline_vertex_attribute(p: u64, binding: i32, location: i32, format: i32, offset: i32) -> i32;
    fn qtc_rhi_pipeline_options(p: u64, topology: i32, cull: i32, blend: bool, depth_test: bool, depth_write: bool) -> i32;
    fn qtc_rhi_pipeline_create(p: u64, bindings: u64, target: u64) -> i32;
    fn qtc_rhi_compute_pipeline(rhi: u64, shader: u64, bindings: u64) -> u64;
    fn qtc_rhi_upload(buffer: u64, offset: i64, bytes: const u8[:]) -> i32;
    fn qtc_rhi_upload_image(texture: u64, image: u64) -> i32;
    fn qtc_rhi_upload_pixels(texture: u64, pixels: const u8[:]) -> i32;
    fn qtc_rhi_read_texture(texture: u64) -> u64;
    fn qtc_rhi_read_buffer(buffer: u64, offset: i64, size: i64) -> u64;
    fn qtc_rhi_read_swapchain(swapchain: u64) -> u64;
    fn qtc_rhi_readback_ready(rb: u64) -> bool;
    fn qtc_rhi_readback_bytes(rb: u64) -> View;
    fn qtc_rhi_readback_image(rb: u64) -> u64;
    fn qtc_rhi_begin_frame(rhi: u64, swapchain: u64) -> i32;
    fn qtc_rhi_end_frame(rhi: u64) -> i32;
    fn qtc_rhi_begin_pass(rhi: u64, target: u64, clear_argb: u32, depth: f64, flags: u32) -> i32;
    fn qtc_rhi_begin_compute(rhi: u64, flags: u32) -> i32;
    fn qtc_rhi_end_pass(rhi: u64) -> i32;
    fn qtc_rhi_set_pipeline(rhi: u64, pipeline: u64) -> i32;
    fn qtc_rhi_set_bindings(rhi: u64, bindings: u64) -> i32;
    fn qtc_rhi_set_viewport(rhi: u64, x: f64, y: f64, w: f64, h: f64) -> i32;
    fn qtc_rhi_set_vertex_buffer(rhi: u64, binding: i32, buffer: u64, offset: i64) -> i32;
    fn qtc_rhi_set_index_buffer(rhi: u64, buffer: u64, offset: i64, index32: bool) -> i32;
    fn qtc_rhi_draw(rhi: u64, vertices: i64, instances: i64, first_vertex: i64, first_instance: i64) -> i32;
    fn qtc_rhi_draw_indexed(rhi: u64, indices: i64, instances: i64, first_index: i64, vertex_offset: i64, first_instance: i64) -> i32;
    fn qtc_rhi_dispatch(rhi: u64, x: i32, y: i32, z: i32) -> i32;
    fn qtc_rhi_widget(widget: u64) -> u64;
    fn qtc_rhi_widget_target(widget: u64) -> u64;
    fn qtc_rhi_native(rhi: u64, out: NativeHandles&) -> i32;
    fn qtc_rhi_native_object(resource: u64, layout: i32&) -> u64;
    fn qtc_rhi_make_current(rhi: u64) -> i32;
    fn qtc_rhi_begin_external(rhi: u64, native_cb: u64&) -> i32;
    fn qtc_rhi_end_external(rhi: u64) -> i32;
    fn qtc_vk_create(extensions: const u8[:], layers: const u8[:]) -> u64;
    fn qtc_vk_instance(h: u64) -> u64;
    fn qtc_vk_proc_address(h: u64, name: const u8[:]) -> u64;
    fn qtc_vk_attach(h: u64, window: u64) -> i32;
    fn qtc_vk_surface(h: u64, window: u64) -> u64;
}

// --------------------------------------------- overridable objects
//
// Subclassing a Qt class: make an overridable object, name the virtual methods to override
// with a tag each, and export the handler Qt's calls come to:
//
//   export "goose_qt_override" fn on_override(obj: u64, tag: u64, nargs: i64, depth: i64) -> i32 {
//       if tag == ROWS { qt::ov_ret_int(5); return qt::OV_DONE; }
//       return qt::OV_BASE;      // the class's own implementation
//   }
//   fn main() {
//       qt::init();
//       qt::use_overrides();
//       let model = qt::new_overridable("QAbstractListModel");
//       qt::override(model, "rowCount", ROWS);
//
// The handler reads the call's arguments with ov_arg_* and sets its result with ov_ret_*. It
// runs on the GUI thread: methods Qt calls on other threads (QThread::run) run Qt's own
// implementation. It may call qt as usual, but not run the event loop or shut down.

let OV_DONE = 0;
let OV_BASE = 1;

// Points libqtc at the exported goose_qt_override. False when the program exports none.
fn use_overrides() -> bool {
    if !gq_has_override_handler() { return false; }
    return qtc_set_override_handler(gq_override_handler(), 0) == 0;
}
// An object of an overridable class (constructor arguments pushed with arg()).
fn new_overridable(class_name: const u8[:]) -> Obj { return Obj { h: qtc_new_overridable(class_name) }; }
fn is_overridable(o: Obj) -> bool { return qtc_is_overridable(o.h); }
fn overridable_classes() -> u8[>..] { return view(qtc_overridable_classes()); }   // one per line
fn overridable_methods(class_name: const u8[:]) -> u8[>..] { return view(qtc_overridable_methods(class_name)); }
// method: a name, or a signature for an overload; tag 0 stops overriding it.
fn override(o: Obj, method: const u8[:], tag: u64) -> bool { return qtc_override(o.h, method, tag) == 0; }

fn ov_arg_kind(i: i64) -> i64 { return qtc_ov_arg_kind(i as i32); }
fn ov_arg_type(i: i64) -> u8[>..] { return view(qtc_ov_arg_type(i as i32)); }
fn ov_arg_bool(i: i64) -> bool { return qtc_ov_arg_bool(i as i32); }
fn ov_arg_int(i: i64) -> i64 { return qtc_ov_arg_int(i as i32); }
fn ov_arg_f64(i: i64) -> f64 { return qtc_ov_arg_double(i as i32); }
fn ov_arg_str(i: i64) -> u8[>..] { return view(qtc_ov_arg_str(i as i32)); }
fn ov_arg_obj(i: i64) -> Obj { return Obj { h: qtc_ov_arg_obj(i as i32) }; }
fn ov_arg_val(i: i64) -> Val { return Val { h: qtc_ov_arg_val(i as i32) }; }   // free it
// An event argument (QMouseEvent *, ...) as poll() would deliver it.
fn ov_arg_event(i: i64, ev: Event&) -> bool { return qtc_ov_arg_event(i as i32, ev) == 0; }
fn ov_event_text(i: i64) -> u8[>..] { return view(qtc_ov_event_text(i as i32)); }
fn ov_accept_event(i: i64, accepted: bool) -> bool { return qtc_ov_accept_event(i as i32, accepted) == 0; }
struct ModelIndex { row: i64, column: i64, id: u64, valid: bool }
fn ov_arg_index(i: i64) -> ModelIndex {
    var row: i32 = -1;
    var column: i32 = -1;
    var id: u64 = 0;
    let ok = qtc_ov_arg_index(i as i32, row, column, id);
    return ModelIndex { row: row, column: column, id: id, valid: ok };
}
fn ov_set_arg_int(i: i64, v: i64) -> bool { return qtc_ov_set_arg_int(i as i32, v) == 0; }
fn ov_set_arg_str(i: i64, v: const u8[:]) -> bool { return qtc_ov_set_arg_str(i as i32, v) == 0; }
// QIODevice::readData / writeData: the buffer argument.
fn ov_buffer_write(i: i64, bytes: const u8[:]) -> i64 { return qtc_ov_buffer_write(i as i32, bytes); }
fn ov_buffer_read(i: i64) -> u8[>..] { return view(qtc_ov_buffer_read(i as i32)); }
fn ov_ret(v: bool) -> bool { return qtc_ov_ret_bool(v) == 0; }
fn ov_ret(v: i64) -> bool { return qtc_ov_ret_int(v) == 0; }
fn ov_ret(v: f64) -> bool { return qtc_ov_ret_double(v) == 0; }
fn ov_ret(v: const u8[:]) -> bool { return qtc_ov_ret_str(v) == 0; }
fn ov_ret(v: Val) -> bool { return qtc_ov_ret_val(v.h) == 0; }
fn ov_ret_uint(v: u64) -> bool { return qtc_ov_ret_uint(v) == 0; }
fn ov_ret_bytes(v: const u8[:]) -> bool { return qtc_ov_ret_bytes(v) == 0; }
fn ov_ret_index(row: i64, column: i64, id: u64) -> bool { return qtc_ov_ret_index(row as i32, column as i32, id) == 0; }
// Runs the class's own implementation now (its result becomes the call's, unless set after).
fn ov_call_base() -> bool { return qtc_ov_call_base() == 0; }
fn ov_depth() -> i64 { return qtc_ov_depth(); }
// Draws with the call's QPainter argument (paint(), drawBackground(), ...): draw_* until draw_end().
fn draw_begin_painter(arg_index: i64) -> bool { return qtc_draw_begin_painter(arg_index as i32) == 0; }

// ------------------------------------------------- runtime classes
//
// New QObject classes with signals, slots, invokables and properties, made while the program
// runs. Slots and invokables come to the override handler with their tag.

let PROP_READ = 0;
let PROP_WRITE = 1;
let PROP_NOTIFY = 2;
let PROP_CONSTANT = 4;

fn class_begin(name: const u8[:], base: const u8[:]) -> bool { return qtc_class_begin(name, base) == 0; }
fn class_signal(signature: const u8[:]) -> bool { return qtc_class_signal(signature) == 0; }
// return_type "": void.
fn class_slot(signature: const u8[:], return_type: const u8[:], tag: u64) -> bool { return qtc_class_slot(signature, return_type, tag) == 0; }
fn class_invokable(signature: const u8[:], return_type: const u8[:], tag: u64) -> bool {
    return qtc_class_invokable(signature, return_type, tag) == 0;
}
fn class_property(name: const u8[:], type_name: const u8[:], flags: i64) -> bool { return qtc_class_property(name, type_name, flags as u32) == 0; }
fn class_end() -> bool { return qtc_class_end() == 0; }
fn class_cancel() -> bool { return qtc_class_cancel() == 0; }
fn class_exists_runtime(name: const u8[:]) -> bool { return qtc_class_exists_runtime(name); }
fn class_new(name: const u8[:]) -> Obj { return Obj { h: qtc_class_new(name) }; }
// Emits a signal with the pushed arguments.
fn emit(o: Obj, signal: const u8[:]) -> bool { return qtc_emit(o.h, signal) == 0; }

// ------------------------------------------------ futures and promises
//
// A future holds the results of work done elsewhere. Goose workers (thread_fn) fill a promise
// with the promise_* functions, which any thread may call; the GUI thread waits for the future,
// watches it (EV_FUTURE_* events) or reads its results.

struct Future { id: u64 }

let FUT_STARTED = 1;
let FUT_RUNNING = 2;
let FUT_FINISHED = 4;
let FUT_CANCELED = 8;
let FUT_SUSPENDED = 16;
let FUT_FAILED = 32;
let EV_FUTURE_STARTED = 5;
let EV_FUTURE_PROGRESS = 6;
let EV_FUTURE_RESULTS = 7;
let EV_FUTURE_FINISHED = 8;
let EV_FUTURE_CANCELED = 9;
let EV_FUTURE_SUSPENDED = 10;
let EV_FUTURE_RESUMED = 11;
let WAIT_FINISHED = 1;

fn promise() -> Future { return Future { id: qtc_promise_new() }; }
fn progress_range(f: Future, min: i64, max: i64) -> bool { return qtc_promise_progress_range(f.id, min as i32, max as i32) == 0; }
fn progress(f: Future, value: i64) -> bool { return qtc_promise_progress(f.id, value as i32, "") == 0; }
fn progress(f: Future, value: i64, text: const u8[:]) -> bool { return qtc_promise_progress(f.id, value as i32, text) == 0; }
fn add(f: Future, v: bool) -> bool { return qtc_promise_add_bool(f.id, v) == 0; }
fn add(f: Future, v: i64) -> bool { return qtc_promise_add_int(f.id, v) == 0; }
fn add(f: Future, v: f64) -> bool { return qtc_promise_add_double(f.id, v) == 0; }
fn add(f: Future, v: const u8[:]) -> bool { return qtc_promise_add_str(f.id, v) == 0; }
fn add(f: Future, v: const f64[:]) -> bool { return qtc_promise_add_f64s(f.id, v) == 0; }
fn add(f: Future, v: Val) -> bool { return qtc_promise_add_val(f.id, v.h) == 0; }   // GUI thread
fn add_bytes(f: Future, v: const u8[:]) -> bool { return qtc_promise_add_bytes(f.id, v) == 0; }
fn add_json(f: Future, json: const u8[:]) -> bool { return qtc_promise_add_json(f.id, json) == 0; }
fn fail(f: Future, message: const u8[:]) -> bool { return qtc_promise_fail(f.id, message) == 0; }
fn finish(f: Future) -> bool { return qtc_promise_finish(f.id) == 0; }
// Whether the consumer canceled it: long work checks this and stops.
fn canceled(f: Future) -> bool { return qtc_promise_canceled(f.id); }
// Blocks while the consumer has it suspended (not on the GUI thread).
fn suspend_if_requested(f: Future) -> bool { return qtc_promise_suspend_if_requested(f.id) == 0; }

fn state(f: Future) -> i64 { return qtc_future_state(f.id); }
fn is_finished(f: Future) -> bool { let s = qtc_future_state(f.id); return s >= 0 && (s & FUT_FINISHED) != 0; }
fn is_failed(f: Future) -> bool { let s = qtc_future_state(f.id); return s >= 0 && (s & FUT_FAILED) != 0; }
fn result_count(f: Future) -> i64 { return qtc_future_result_count(f.id); }
struct Progress { value: i64, min: i64, max: i64 }
fn progress(f: Future) -> Progress {
    var v: i32 = 0;
    var lo: i32 = 0;
    var hi: i32 = 0;
    qtc_future_progress(f.id, v, lo, hi);
    return Progress { value: v, min: lo, max: hi };
}
// Result i into the return register: read it with ret_int(), ret_str(), ret_val(), ...
fn result(f: Future, i: i64) -> bool { return qtc_future_result(f.id, i) == 0; }
fn result_int(f: Future, i: i64) -> i64 { qtc_future_result(f.id, i); return qtc_ret_int(); }
fn result_f64(f: Future, i: i64) -> f64 { qtc_future_result(f.id, i); return qtc_ret_double(); }
fn result_str(f: Future, i: i64) -> u8[>..] { qtc_future_result(f.id, i); return view(qtc_ret_str()); }
fn result_val(f: Future, i: i64) -> Val { qtc_future_result(f.id, i); return Val { h: qtc_ret_val() }; }
fn error(f: Future) -> u8[>..] { return view(qtc_future_error(f.id)); }
fn cancel(f: Future) -> bool { return qtc_future_cancel(f.id) == 0; }
fn suspend(f: Future, on: bool) -> bool { return qtc_future_suspend(f.id, on) == 0; }
// WAIT_FINISHED, or WAIT_TIMEOUT; on the GUI thread the event loop runs meanwhile.
fn wait(f: Future, timeout_ms: i64) -> i64 { return qtc_future_wait(f.id, timeout_ms); }
fn release(f: Future) -> bool { return qtc_future_release(f.id) == 0; }
fn all(a: Future, b: Future) -> Future { return Future { id: qtc_future_all(a.id, b.id) }; }
fn any(a: Future, b: Future) -> Future { return Future { id: qtc_future_any(a.id, b.id) }; }
// Progress as EV_FUTURE_* events with this tag until it finishes.
fn watch(f: Future, tag: u64) -> u64 { return qtc_future_watch(f.id, tag); }
fn unwatch_future(w: u64) -> bool { return qtc_future_unwatch(w) == 0; }
fn live_futures() -> i64 { return qtc_live_futures(); }

// Worker objects: an object moved to a QThread's event loop, called there.
fn move_to_thread(o: Obj, thread: Obj) -> bool { return qtc_move_to_thread(o.h, thread.h) == 0; }
fn invoke_queued(o: Obj, method: const u8[:]) -> bool { return qtc_invoke_queued(o.h, method) == 0; }
// The call's result as the future's one result.
fn invoke_future(o: Obj, method: const u8[:]) -> Future { return Future { id: qtc_invoke_future(o.h, method) }; }

// ----------------------------------------------------------- graphics
//
// Qt's RHI: one API over Vulkan, OpenGL, Direct3D 11/12 and Metal (qtc.h has the details).
// Every handle (the RHI, its resources, shaders, readbacks) is a qt::Gpu.

struct Gpu { h: u64 }
// Matches qtc_rhi_native_handles.
struct NativeHandles { backend: i32, reserved: i32, instance: u64, physical_device: u64, device: u64, queue: u64,
                       queue_family: u32, queue_index: u32 }

let GAPI_UNKNOWN = 0;
let GAPI_SOFTWARE = 1;
let GAPI_OPENGL = 2;
let GAPI_VULKAN = 3;
let GAPI_D3D11 = 4;
let GAPI_D3D12 = 5;
let GAPI_METAL = 6;
let GAPI_NULL = 7;
let RHI_NULL = 0;
let RHI_OPENGL = 1;
let RHI_VULKAN = 2;
let RHI_D3D11 = 3;
let RHI_D3D12 = 4;
let RHI_METAL = 5;
let RHI_DEBUG = 1;
let FEATURE_COMPUTE = 1;
let FEATURE_INSTANCING = 2;
let FEATURE_INDEX32 = 3;
let FEATURE_BASE_VERTEX = 4;
let FEATURE_BASE_INSTANCE = 5;
let FEATURE_INT_ATTRIBUTES = 6;
let FEATURE_READ_BACK_BUFFERS = 7;
let VERTEX = 1;
let FRAGMENT = 2;
let COMPUTE = 4;
let IMMUTABLE = 0;
let STATIC = 1;
let DYNAMIC = 2;
let VERTEX_BUFFER = 1;
let INDEX_BUFFER = 2;
let UNIFORM_BUFFER = 4;
let STORAGE_BUFFER = 8;
let RGBA8 = 1;
let BGRA8 = 2;
let R8 = 3;
let RGBA16F = 4;
let RGBA32F = 5;
let R32F = 6;
let RENDER_TARGET = 1;
let READABLE = 2;
let STORAGE_IMAGE = 4;
let SC_DEPTH = 1;
let SC_READABLE = 2;
let SC_NO_VSYNC = 4;
let LOAD = 1;
let STORE = 2;
let LOAD_STORE = 3;
let FLOAT = 1;
let FLOAT2 = 2;
let FLOAT3 = 3;
let FLOAT4 = 4;
let UNORM_BYTE4 = 5;
let INT = 6;
let UINT = 7;
let TRIANGLES = 0;
let TRIANGLE_STRIP = 1;
let LINES = 2;
let LINE_STRIP = 3;
let POINTS = 4;
let CULL_NONE = 0;
let CULL_FRONT = 1;
let CULL_BACK = 2;
let RHI_SKIPPED = 1;
let PASS_EXTERNAL = 1;

fn quick_set_graphics_api(api: i64) -> bool { return qtc_quick_set_graphics_api(api as i32) == 0; }
fn quick_graphics_api() -> i64 { return qtc_quick_graphics_api(0); }
fn quick_graphics_api(window: Obj) -> i64 { return qtc_quick_graphics_api(window.h); }
// An OpenGL function of the current context, to hand to C code that calls it.
fn gl_proc_address(name: const u8[:]) -> u64 { return qtc_gl_proc_address(name); }

fn rhi_create(backend: i64) -> Gpu { return Gpu { h: qtc_rhi_create(backend as i32, 0) }; }
fn rhi_create(backend: i64, flags: i64) -> Gpu { return Gpu { h: qtc_rhi_create(backend as i32, flags as u32) }; }
fn ok(g: Gpu) -> bool { return g.h != 0; }
fn destroy(g: Gpu) -> bool { return qtc_rhi_destroy(g.h) == 0; }
fn info(r: Gpu) -> u8[>..] { return view(qtc_rhi_info(r.h)); }   // JSON
fn supports(r: Gpu, feature: i64) -> bool { return qtc_rhi_supports(r.h, feature as i32); }
fn rhi_live() -> i64 { return qtc_rhi_live(); }
fn finish(r: Gpu) -> bool { return qtc_rhi_finish(r.h) == 0; }

// Vulkan-style GLSL (#version 440, layout(binding = n), layout(location = n)) for every backend.
fn shader_bake(stage: i64, glsl: const u8[:]) -> Gpu { return Gpu { h: qtc_rhi_shader_bake(stage as u32, glsl) }; }
fn shader_load(qsb: const u8[:]) -> Gpu { return Gpu { h: qtc_rhi_shader_load(qsb) }; }
fn shader_save(s: Gpu) -> u8[>..] { return view(qtc_rhi_shader_save(s.h)); }
fn shader_reflect(s: Gpu) -> u8[>..] { return view(qtc_rhi_shader_reflect(s.h)); }

fn buffer(r: Gpu, type_: i64, usage: i64, size: i64) -> Gpu { return Gpu { h: qtc_rhi_buffer(r.h, type_ as i32, usage as u32, size) }; }
fn texture(r: Gpu, format: i64, w: i64, h: i64, flags: i64) -> Gpu {
    return Gpu { h: qtc_rhi_texture(r.h, format as i32, w as i32, h as i32, flags as u32) };
}
fn sampler(r: Gpu, linear: bool, repeat: bool) -> Gpu { return Gpu { h: qtc_rhi_sampler(r.h, linear, repeat) }; }
fn render_target(texture: Gpu, depth: bool) -> Gpu { return Gpu { h: qtc_rhi_render_target(texture.h, depth) }; }
fn swapchain(r: Gpu, window: Obj, flags: i64) -> Gpu { return Gpu { h: qtc_rhi_swapchain(r.h, window.h, flags as u32) }; }

fn bindings(r: Gpu) -> Gpu { return Gpu { h: qtc_rhi_bindings(r.h) }; }
// size 0: to the end of the buffer.
fn bind_uniform(srb: Gpu, binding: i64, stages: i64, buf: Gpu, offset: i64, size: i64) -> bool {
    return qtc_rhi_bind_uniform(srb.h, binding as i32, stages as u32, buf.h, offset, size) == 0;
}
fn bind_texture(srb: Gpu, binding: i64, stages: i64, tex: Gpu, smp: Gpu) -> bool {
    return qtc_rhi_bind_texture(srb.h, binding as i32, stages as u32, tex.h, smp.h) == 0;
}
fn bind_storage(srb: Gpu, binding: i64, stages: i64, buf: Gpu, access: i64) -> bool {
    return qtc_rhi_bind_storage(srb.h, binding as i32, stages as u32, buf.h, access as i32) == 0;
}
fn bind_image(srb: Gpu, binding: i64, stages: i64, tex: Gpu, access: i64) -> bool {
    return qtc_rhi_bind_image(srb.h, binding as i32, stages as u32, tex.h, access as i32) == 0;
}
fn create(srb: Gpu) -> bool { return qtc_rhi_bindings_create(srb.h) == 0; }

fn pipeline(r: Gpu) -> Gpu { return Gpu { h: qtc_rhi_pipeline(r.h) }; }
fn shaders(p: Gpu, vertex: Gpu, fragment: Gpu) -> bool { return qtc_rhi_pipeline_shaders(p.h, vertex.h, fragment.h) == 0; }
fn vertex_binding(p: Gpu, stride: i64, per_instance: bool) -> bool { return qtc_rhi_pipeline_vertex_binding(p.h, stride as i32, per_instance) == 0; }
fn vertex_attribute(p: Gpu, binding: i64, location: i64, format: i64, offset: i64) -> bool {
    return qtc_rhi_pipeline_vertex_attribute(p.h, binding as i32, location as i32, format as i32, offset as i32) == 0;
}
fn options(p: Gpu, topology: i64, cull: i64, blend: bool, depth_test: bool, depth_write: bool) -> bool {
    return qtc_rhi_pipeline_options(p.h, topology as i32, cull as i32, blend, depth_test, depth_write) == 0;
}
fn create(p: Gpu, srb: Gpu, target: Gpu) -> bool { return qtc_rhi_pipeline_create(p.h, srb.h, target.h) == 0; }
fn compute_pipeline(r: Gpu, shader: Gpu, srb: Gpu) -> Gpu { return Gpu { h: qtc_rhi_compute_pipeline(r.h, shader.h, srb.h) }; }

fn upload(buf: Gpu, offset: i64, bytes: const u8[:]) -> bool { return qtc_rhi_upload(buf.h, offset, bytes) == 0; }
// Floats as the 32-bit floats shaders read.
fn upload_f32(buf: Gpu, offset: i64, xs: const f64[:]) -> bool {
    var b: u8[>..] = [];
    for x in xs { binary::write_f32le(b, x as f32); }
    return qtc_rhi_upload(buf.h, offset, b) == 0;
}
fn upload_u16(buf: Gpu, offset: i64, xs: const i64[:]) -> bool {
    var b: u8[>..] = [];
    for x in xs { binary::write_u16le(b, x as u16); }
    return qtc_rhi_upload(buf.h, offset, b) == 0;
}
fn upload_u32(buf: Gpu, offset: i64, xs: const i64[:]) -> bool {
    var b: u8[>..] = [];
    for x in xs { binary::write_u32le(b, x as u32); }
    return qtc_rhi_upload(buf.h, offset, b) == 0;
}
fn upload_image(tex: Gpu, image: Val) -> bool { return qtc_rhi_upload_image(tex.h, image.h) == 0; }
fn upload_pixels(tex: Gpu, pixels: const u8[:]) -> bool { return qtc_rhi_upload_pixels(tex.h, pixels) == 0; }
fn read_texture(tex: Gpu) -> Gpu { return Gpu { h: qtc_rhi_read_texture(tex.h) }; }
fn read_buffer(buf: Gpu, offset: i64, size: i64) -> Gpu { return Gpu { h: qtc_rhi_read_buffer(buf.h, offset, size) }; }
fn read_swapchain(sc: Gpu) -> Gpu { return Gpu { h: qtc_rhi_read_swapchain(sc.h) }; }
fn ready(rb: Gpu) -> bool { return qtc_rhi_readback_ready(rb.h); }
fn bytes(rb: Gpu) -> u8[>..] { return view(qtc_rhi_readback_bytes(rb.h)); }
fn image(rb: Gpu) -> Val { return Val { h: qtc_rhi_readback_image(rb.h) }; }

// OK, RHI_SKIPPED (the window cannot show a frame now), or an error.
fn begin_frame(r: Gpu) -> i64 { return qtc_rhi_begin_frame(r.h, 0); }
fn begin_frame(r: Gpu, sc: Gpu) -> i64 { return qtc_rhi_begin_frame(r.h, sc.h); }
fn end_frame(r: Gpu) -> bool { return qtc_rhi_end_frame(r.h) == 0; }
fn begin_pass(r: Gpu, target: Gpu, clear_argb: u32) -> bool { return qtc_rhi_begin_pass(r.h, target.h, clear_argb, 1.0, 0) == 0; }
fn begin_pass(r: Gpu, target: Gpu, clear_argb: u32, depth: f64, flags: i64) -> bool {
    return qtc_rhi_begin_pass(r.h, target.h, clear_argb, depth, flags as u32) == 0;
}
fn begin_compute(r: Gpu) -> bool { return qtc_rhi_begin_compute(r.h, 0) == 0; }
fn end_pass(r: Gpu) -> bool { return qtc_rhi_end_pass(r.h) == 0; }
fn set_pipeline(r: Gpu, p: Gpu) -> bool { return qtc_rhi_set_pipeline(r.h, p.h) == 0; }
fn set_bindings(r: Gpu, srb: Gpu) -> bool { return qtc_rhi_set_bindings(r.h, srb.h) == 0; }
fn set_viewport(r: Gpu, x: f64, y: f64, w: f64, h: f64) -> bool { return qtc_rhi_set_viewport(r.h, x, y, w, h) == 0; }
fn set_vertex_buffer(r: Gpu, binding: i64, buf: Gpu, offset: i64) -> bool {
    return qtc_rhi_set_vertex_buffer(r.h, binding as i32, buf.h, offset) == 0;
}
fn set_index_buffer(r: Gpu, buf: Gpu, offset: i64, index32: bool) -> bool { return qtc_rhi_set_index_buffer(r.h, buf.h, offset, index32) == 0; }
fn draw(r: Gpu, vertices: i64) -> bool { return qtc_rhi_draw(r.h, vertices, 1, 0, 0) == 0; }
fn draw(r: Gpu, vertices: i64, instances: i64, first_vertex: i64, first_instance: i64) -> bool {
    return qtc_rhi_draw(r.h, vertices, instances, first_vertex, first_instance) == 0;
}
fn draw_indexed(r: Gpu, indices: i64) -> bool { return qtc_rhi_draw_indexed(r.h, indices, 1, 0, 0, 0) == 0; }
fn draw_indexed(r: Gpu, indices: i64, instances: i64, first_index: i64, vertex_offset: i64, first_instance: i64) -> bool {
    return qtc_rhi_draw_indexed(r.h, indices, instances, first_index, vertex_offset, first_instance) == 0;
}
fn dispatch(r: Gpu, x: i64, y: i64, z: i64) -> bool { return qtc_rhi_dispatch(r.h, x as i32, y as i32, z as i32) == 0; }

// In a QRhiWidget's initialize or render override: its RHI (with the call's frame) and target.
fn rhi_widget(w: Obj) -> Gpu { return Gpu { h: qtc_rhi_widget(w.h) }; }
fn rhi_widget_target(w: Obj) -> Gpu { return Gpu { h: qtc_rhi_widget_target(w.h) }; }

fn native(r: Gpu) -> NativeHandles {
    var n = default<NativeHandles>();
    qtc_rhi_native(r.h, n);
    return n;
}
fn native_object(res: Gpu) -> u64 {
    var layout: i32 = 0;
    return qtc_rhi_native_object(res.h, layout);
}
fn make_current(r: Gpu) -> bool { return qtc_rhi_make_current(r.h) == 0; }
// The native command buffer (VkCommandBuffer, ...; 0 for OpenGL and Direct3D 11).
fn begin_external(r: Gpu) -> u64 {
    var cb: u64 = 0;
    qtc_rhi_begin_external(r.h, cb);
    return cb;
}
fn end_external(r: Gpu) -> bool { return qtc_rhi_end_external(r.h) == 0; }

// Vulkan for code that calls it itself: an instance (JSON arrays of extension and layer names).
fn vk_create(extensions: const u8[:], layers: const u8[:]) -> Gpu { return Gpu { h: qtc_vk_create(extensions, layers) }; }
fn vk_instance(h: Gpu) -> u64 { return qtc_vk_instance(h.h); }
fn vk_proc_address(h: Gpu, name: const u8[:]) -> u64 { return qtc_vk_proc_address(h.h, name); }
fn vk_attach(h: Gpu, window: Obj) -> bool { return qtc_vk_attach(h.h, window.h) == 0; }
fn vk_surface(h: Gpu, window: Obj) -> u64 { return qtc_vk_surface(h.h, window.h); }
