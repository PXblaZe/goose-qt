// goose-qt: Qt 6 for Goose, on top of libqtc.
//
//   import qt from "path/to/goose-qt";
//
//   fn main() {
//       qt::init();
//       let win = qt::QWidget();
//       let btn = qt::QPushButton("Click me", win);
//       qt::connect(btn, "clicked", 1);
//       win.show();
//       var ev = default<qt::Event>();
//       while qt::wait(-1) != qt::WAIT_QUIT {
//           while qt::poll(ev) { if ev.tag == 1 { btn.setText("Clicked"); } }
//       }
//       qt::shutdown();
//   }
//
// Objects are qt::Obj and values (colors, fonts, images, lists, ...) are qt::Val:
// handles, never pointers. Using one after it was destroyed is an error that
// qtc reports, never a crash. Every Qt method is a function in this namespace,
// so UFCS works: label.setText("hi"), slider.value(), img.pixelColor(2, 3).
// Static methods are Class_method(...), constructors are the class name, and
// enum values are fields of a value named after their scope: qt::Qt.AlignLeft,
// qt::QImage.Format_ARGB32.
namespace qt;

import ffi;
import api;
import values;
import extra;

struct Obj { h: u64 }
struct Val { h: u64 }
struct View { ptr: u64, len: i64 }
// Matches qtc_event (96 bytes, no padding).
struct Event { seq: u64, tag: u64, source: u64, id: u64, i0: i64, i1: i64, i2: i64, i3: i64,
               d0: f64, d1: f64, kind: i32, argc: i32, count: i32, flags: i32 }

extern "qtc" {
    fn qtc_set_error_policy(policy: i32);
    fn qtc_error_policy() -> i32;
    fn qtc_last_error() -> i32;
    fn qtc_last_error_message() -> View;
    fn qtc_clear_error();
    fn qtc_status_name(status: i32) -> View;
    fn qtc_init(kind: i32, args: const u8[:]) -> i32;
    fn qtc_shutdown() -> i32;
    fn qtc_is_initialized() -> bool;
    fn qtc_version() -> View;
    fn qtc_qt_version() -> View;
    fn qtc_qt_build_version() -> View;
    fn qtc_app() -> u64;
    fn qtc_wait(timeout_ms: i64) -> i32;
    fn qtc_poll(ev: Event&) -> bool;
    fn qtc_pending() -> i64;
    fn qtc_process_events() -> i32;
    fn qtc_quit(code: i32) -> i32;
    fn qtc_quit_requested() -> bool;
    fn qtc_exit_code() -> i32;
    fn qtc_cancel_quit() -> i32;
    fn qtc_set_quit_on_last_window_closed(on: bool) -> i32;
    fn qtc_post(tag: u64, a: i64, b: i64) -> i32;
    fn qtc_set_queue_limit(max_events: i64) -> i32;
    fn qtc_dropped_events() -> i64;
    fn qtc_event_arg_kind(seq: u64, index: i32) -> i32;
    fn qtc_event_arg_bool(seq: u64, index: i32, out: bool&) -> i32;
    fn qtc_event_arg_int(seq: u64, index: i32, out: i64&) -> i32;
    fn qtc_event_arg_double(seq: u64, index: i32, out: f64&) -> i32;
    fn qtc_event_arg_str(seq: u64, index: i32) -> View;
    fn qtc_event_arg_obj(seq: u64, index: i32) -> u64;
    fn qtc_event_arg_val(seq: u64, index: i32) -> u64;
    fn qtc_event_text(seq: u64) -> View;
    fn qtc_event_signal(seq: u64) -> View;
    fn qtc_connect(sender: u64, signal: const u8[:], tag: u64, flags: u32) -> u64;
    fn qtc_disconnect(connection: u64) -> i32;
    fn qtc_connect_to(sender: u64, signal: const u8[:], receiver: u64, method: const u8[:]) -> u64;
    fn qtc_watch(obj: u64, mask: u64, consume: u64, tag: u64) -> u64;
    fn qtc_unwatch(watch: u64) -> i32;
    fn qtc_timer(interval_ms: i64, single_shot: bool, tag: u64) -> u64;
    fn qtc_new(class_name: const u8[:]) -> u64;
    fn qtc_destroy(obj: u64) -> i32;
    fn qtc_adopt(obj: u64) -> i32;
    fn qtc_alive(h: u64) -> bool;
    fn qtc_is_object(h: u64) -> bool;
    fn qtc_is_value(h: u64) -> bool;
    fn qtc_class_name(obj: u64) -> View;
    fn qtc_inherits(obj: u64, class_name: const u8[:]) -> bool;
    fn qtc_find_child(parent: u64, object_name: const u8[:], class_name: const u8[:], recurse: bool) -> u64;
    fn qtc_live_objects() -> i64;
    fn qtc_live_values() -> i64;
    fn qtc_val_bool(v: bool) -> u64;
    fn qtc_val_int(v: i64) -> u64;
    fn qtc_val_uint(v: u64) -> u64;
    fn qtc_val_double(v: f64) -> u64;
    fn qtc_val_str(v: const u8[:]) -> u64;
    fn qtc_val_bytes(v: const u8[:]) -> u64;
    fn qtc_val_obj(v: u64) -> u64;
    fn qtc_val_list() -> u64;
    fn qtc_val_map() -> u64;
    fn qtc_val_new(type_name: const u8[:]) -> u64;
    fn qtc_val_from_json(json: const u8[:]) -> u64;
    fn qtc_val_free(v: u64) -> i32;
    fn qtc_val_copy(v: u64) -> u64;
    fn qtc_val_kind(v: u64) -> i32;
    fn qtc_val_type_name(v: u64) -> View;
    fn qtc_val_get_bool(v: u64, out: bool&) -> i32;
    fn qtc_val_get_int(v: u64, out: i64&) -> i32;
    fn qtc_val_get_double(v: u64, out: f64&) -> i32;
    fn qtc_val_get_str(v: u64) -> View;
    fn qtc_val_get_obj(v: u64) -> u64;
    fn qtc_val_convert(v: u64, type_name: const u8[:]) -> u64;
    fn qtc_val_equal(a: u64, b: u64) -> bool;
    fn qtc_val_to_json(v: u64) -> View;
    fn qtc_val_to_string(v: u64) -> View;
    fn qtc_list_len(list: u64) -> i64;
    fn qtc_list_get(list: u64, index: i64) -> u64;
    fn qtc_list_append(list: u64, item: u64) -> i32;
    fn qtc_list_set(list: u64, index: i64, item: u64) -> i32;
    fn qtc_list_remove(list: u64, index: i64) -> i32;
    fn qtc_list_clear(list: u64) -> i32;
    fn qtc_map_len(map: u64) -> i64;
    fn qtc_map_get(map: u64, key: const u8[:]) -> u64;
    fn qtc_map_set(map: u64, key: const u8[:], item: u64) -> i32;
    fn qtc_map_remove(map: u64, key: const u8[:]) -> i32;
    fn qtc_map_has(map: u64, key: const u8[:]) -> bool;
    fn qtc_map_keys(map: u64) -> u64;
    fn qtc_args_clear();
    fn qtc_args_count() -> i32;
    fn qtc_arg_bool(v: bool);
    fn qtc_arg_int(v: i64);
    fn qtc_arg_uint(v: u64);
    fn qtc_arg_double(v: f64);
    fn qtc_arg_str(v: const u8[:]);
    fn qtc_arg_bytes(v: const u8[:]);
    fn qtc_arg_obj(v: u64);
    fn qtc_arg_val(v: u64);
    fn qtc_arg_null();
    fn qtc_call(receiver: u64, method: const u8[:]) -> i32;
    fn qtc_call_static(class_name: const u8[:], method: const u8[:]) -> i32;
    fn qtc_ret_kind() -> i32;
    fn qtc_ret_bool() -> bool;
    fn qtc_ret_int() -> i64;
    fn qtc_ret_uint() -> u64;
    fn qtc_ret_double() -> f64;
    fn qtc_ret_str() -> View;
    fn qtc_ret_obj() -> u64;
    fn qtc_ret_val() -> u64;
    fn qtc_out_count() -> i32;
    fn qtc_out_bool(index: i32) -> bool;
    fn qtc_out_int(index: i32) -> i64;
    fn qtc_out_double(index: i32) -> f64;
    fn qtc_set_alloc_limit(bytes: i64) -> i32;
    fn qtc_alloc_limit() -> i64;
    fn qtc_prop_set(obj: u64, name: const u8[:]) -> i32;
    fn qtc_prop_get(obj: u64, name: const u8[:]) -> i32;
    fn qtc_dynprop_set(obj: u64, name: const u8[:]) -> i32;
    fn qtc_set_bool(obj: u64, prop: const u8[:], v: bool) -> i32;
    fn qtc_set_int(obj: u64, prop: const u8[:], v: i64) -> i32;
    fn qtc_set_double(obj: u64, prop: const u8[:], v: f64) -> i32;
    fn qtc_set_str(obj: u64, prop: const u8[:], v: const u8[:]) -> i32;
    fn qtc_get_bool(obj: u64, prop: const u8[:]) -> bool;
    fn qtc_get_int(obj: u64, prop: const u8[:]) -> i64;
    fn qtc_get_double(obj: u64, prop: const u8[:]) -> f64;
    fn qtc_get_str(obj: u64, prop: const u8[:]) -> View;
    fn qtc_class_exists(class_name: const u8[:]) -> bool;
    fn qtc_class_count() -> i64;
    fn qtc_class_at(index: i64) -> View;
    fn qtc_describe(handle: u64, class_name: const u8[:]) -> View;
    fn qtc_enum_value(name: const u8[:], out: i64&) -> i32;
    fn qtc_enum_key(enum_name: const u8[:], value: i64) -> View;
    fn qtc_enum_describe(enum_name: const u8[:]) -> View;
    fn qtc_stats() -> View;
    fn qtc_draw_begin(target: u64) -> i32;
    fn qtc_draw_end() -> i32;
    fn qtc_draw_clear(argb: u32) -> i32;
    fn qtc_draw_pen(argb: u32, width: f64, style: i32, cap: i32, join: i32) -> i32;
    fn qtc_draw_no_pen() -> i32;
    fn qtc_draw_brush(argb: u32, style: i32) -> i32;
    fn qtc_draw_no_brush() -> i32;
    fn qtc_draw_linear_gradient(x1: f64, y1: f64, x2: f64, y2: f64, argb1: u32, argb2: u32) -> i32;
    fn qtc_draw_font(family: const u8[:], point_size: f64, weight: i32, italic: bool) -> i32;
    fn qtc_draw_antialias(on: bool) -> i32;
    fn qtc_draw_opacity(opacity: f64) -> i32;
    fn qtc_draw_save() -> i32;
    fn qtc_draw_restore() -> i32;
    fn qtc_draw_translate(dx: f64, dy: f64) -> i32;
    fn qtc_draw_rotate(degrees: f64) -> i32;
    fn qtc_draw_scale(sx: f64, sy: f64) -> i32;
    fn qtc_draw_clip_rect(x: f64, y: f64, w: f64, h: f64) -> i32;
    fn qtc_draw_point(x: f64, y: f64) -> i32;
    fn qtc_draw_line(x1: f64, y1: f64, x2: f64, y2: f64) -> i32;
    fn qtc_draw_rect(x: f64, y: f64, w: f64, h: f64) -> i32;
    fn qtc_draw_rounded_rect(x: f64, y: f64, w: f64, h: f64, rx: f64, ry: f64) -> i32;
    fn qtc_draw_ellipse(x: f64, y: f64, w: f64, h: f64) -> i32;
    fn qtc_draw_arc(x: f64, y: f64, w: f64, h: f64, start: f64, span: f64) -> i32;
    fn qtc_draw_pie(x: f64, y: f64, w: f64, h: f64, start: f64, span: f64) -> i32;
    fn qtc_draw_polyline(xy: const f64[:]) -> i32;
    fn qtc_draw_polygon(xy: const f64[:]) -> i32;
    fn qtc_draw_path_move(x: f64, y: f64) -> i32;
    fn qtc_draw_path_line(x: f64, y: f64) -> i32;
    fn qtc_draw_path_quad(cx: f64, cy: f64, x: f64, y: f64) -> i32;
    fn qtc_draw_path_cubic(c1x: f64, c1y: f64, c2x: f64, c2y: f64, x: f64, y: f64) -> i32;
    fn qtc_draw_path_close() -> i32;
    fn qtc_draw_path_end() -> i32;
    fn qtc_draw_text(x: f64, y: f64, text: const u8[:]) -> i32;
    fn qtc_draw_text_in(x: f64, y: f64, w: f64, h: f64, flags: i32, text: const u8[:]) -> i32;
    fn qtc_draw_image(image: u64, x: f64, y: f64, w: f64, h: f64) -> i32;
    fn qtc_draw_count() -> i64;
}

// ------------------------------------------------------------- constants

let OK = 0;
let ERR_NOT_INITIALIZED = -1;
let ERR_WRONG_THREAD = -2;
let ERR_NULL_HANDLE = -3;
let ERR_STALE_HANDLE = -4;
let ERR_BAD_HANDLE = -5;
let ERR_WRONG_TYPE = -6;
let ERR_NOT_FOUND = -7;
let ERR_AMBIGUOUS = -8;
let ERR_BAD_ARGS = -9;
let ERR_OUT_OF_RANGE = -10;
let ERR_READ_ONLY = -11;
let ERR_CONVERSION = -12;
let ERR_UNSUPPORTED = -13;
let ERR_EXCEPTION = -14;
let ERR_STATE = -15;
let ERR_LIMIT = -16;
let ERR_IO = -17;
let ERR_INVALID_ARG = -18;
let ERR_REJECTED = -19;

let ERRORS_RETURN = 0;
let ERRORS_LOG = 1;
let ERRORS_ABORT = 2;

let APP_WIDGETS = 0;
let APP_GUI = 1;
let APP_CORE = 2;

let WAIT_TIMEOUT = 0;
let WAIT_EVENTS = 1;
let WAIT_QUIT = 2;

let EV_SIGNAL = 1;
let EV_POST = 2;
let EV_TIMER = 3;
let EV_LAST_WINDOW_CLOSED = 4;
let EV_MOUSE_PRESS = 16;
let EV_MOUSE_RELEASE = 17;
let EV_MOUSE_DOUBLE_CLICK = 18;
let EV_MOUSE_MOVE = 19;
let EV_WHEEL = 20;
let EV_KEY_PRESS = 21;
let EV_KEY_RELEASE = 22;
let EV_FOCUS_IN = 23;
let EV_FOCUS_OUT = 24;
let EV_ENTER = 25;
let EV_LEAVE = 26;
let EV_RESIZE = 27;
let EV_MOVE = 28;
let EV_SHOW = 29;
let EV_HIDE = 30;
let EV_CLOSE = 31;
let EV_CONTEXT_MENU = 32;
let EV_DRAG_ENTER = 33;
let EV_DRAG_MOVE = 34;
let EV_DRAG_LEAVE = 35;
let EV_DROP = 36;
let EV_PAINT = 37;
let EV_WINDOW_STATE = 38;
let EV_DESTROYED = 39;
let EVF_STALE_SOURCE = 1;

let CONN_COALESCE = 1;
let CONN_ONCE = 2;
let CONN_NO_ARGS = 4;

let T_NONE = 0;
let T_BOOL = 1;
let T_INT = 2;
let T_UINT = 3;
let T_DOUBLE = 4;
let T_STR = 5;
let T_BYTES = 6;
let T_OBJ = 7;
let T_LIST = 8;
let T_MAP = 9;
let T_VALUE = 10;
let T_NULL = 11;

let NONE = Obj { h: 0 };

// ---------------------------------------------------------------- basics

fn view(v: View) -> u8[>..] { return ffi::bytes(v.ptr, v.len); }

// Starts Qt with QApplication (widgets, QML, everything). Errors are logged to stderr.
fn init() -> bool { return init(APP_WIDGETS, "goose-qt"); }
fn init(kind: i64) -> bool { return init(kind, "goose-qt"); }
// args: the command line as NUL-separated arguments, e.g. "app\0-platform\0offscreen".
fn init(kind: i64, args: const u8[:]) -> bool {
    if qtc_error_policy() == ERRORS_RETURN { qtc_set_error_policy(ERRORS_LOG); }
    return qtc_init(kind as i32, args) == 0;
}
fn shutdown() -> bool { return qtc_shutdown() == 0; }
fn is_initialized() -> bool { return qtc_is_initialized(); }
fn version() -> u8[>..] { return view(qtc_version()); }
fn qt_version() -> u8[>..] { return view(qtc_qt_version()); }
fn qt_build_version() -> u8[>..] { return view(qtc_qt_build_version()); }

// What a failed call does besides returning its status: ERRORS_RETURN, ERRORS_LOG (default) or ERRORS_ABORT.
fn set_error_policy(policy: i64) { qtc_set_error_policy(policy as i32); }
fn last_error() -> i64 { return qtc_last_error(); }
fn last_error_message() -> u8[>..] { return view(qtc_last_error_message()); }
fn clear_error() { qtc_clear_error(); }
fn status_name(status: i64) -> u8[>..] { return view(qtc_status_name(status as i32)); }

// ------------------------------------------------------------ event loop

fn wait(timeout_ms: i64) -> i64 { return qtc_wait(timeout_ms); }
fn poll(ev: Event&) -> bool { return qtc_poll(ev); }
fn pending() -> i64 { return qtc_pending(); }
fn process_events() { qtc_process_events(); }
fn quit() { qtc_quit(0); }
fn quit(code: i64) { qtc_quit(code as i32); }
fn quit_requested() -> bool { return qtc_quit_requested(); }
fn exit_code() -> i64 { return qtc_exit_code(); }
fn cancel_quit() { qtc_cancel_quit(); }
fn set_quit_on_last_window_closed(on: bool) { qtc_set_quit_on_last_window_closed(on); }
// Thread-safe: queues an EV_POST event.
fn post(tag: u64, a: i64, b: i64) -> bool { return qtc_post(tag, a, b) == 0; }
fn set_queue_limit(n: i64) { qtc_set_queue_limit(n); }
fn dropped_events() -> i64 { return qtc_dropped_events(); }

// The object an event came from.
fn sender(ev: Event) -> Obj { return Obj { h: ev.source }; }
fn stale_source(ev: Event) -> bool { return (ev.flags & EVF_STALE_SOURCE) != 0; }
// Key text, dropped text or URLs, or a signal's first string argument.
fn text(ev: Event) -> u8[>..] { return view(qtc_event_text(ev.seq)); }
fn signal(ev: Event) -> u8[>..] { return view(qtc_event_signal(ev.seq)); }
fn arg_kind(ev: Event, i: i64) -> i64 { return qtc_event_arg_kind(ev.seq, i as i32); }
fn arg_bool(ev: Event, i: i64) -> bool {
    var b = false;
    qtc_event_arg_bool(ev.seq, i as i32, b);
    return b;
}
fn arg_int(ev: Event, i: i64) -> i64 {
    var x = 0;
    qtc_event_arg_int(ev.seq, i as i32, x);
    return x;
}
fn arg_f64(ev: Event, i: i64) -> f64 {
    var x = 0.0;
    qtc_event_arg_double(ev.seq, i as i32, x);
    return x;
}
fn arg_str(ev: Event, i: i64) -> u8[>..] { return view(qtc_event_arg_str(ev.seq, i as i32)); }
fn arg_obj(ev: Event, i: i64) -> Obj { return Obj { h: qtc_event_arg_obj(ev.seq, i as i32) }; }
fn arg_val(ev: Event, i: i64) -> Val { return Val { h: qtc_event_arg_val(ev.seq, i as i32) }; }

// --------------------------------------------------------------- signals

// signal: "clicked" or "clicked(bool)". Returns a connection id (0 on failure).
fn connect(o: Obj, signal: const u8[:], tag: u64) -> u64 { return qtc_connect(o.h, signal, tag, 0); }
// flags: CONN_COALESCE, CONN_ONCE, CONN_NO_ARGS.
fn connect(o: Obj, signal: const u8[:], tag: u64, flags: i64) -> u64 { return qtc_connect(o.h, signal, tag, flags as u32); }
fn disconnect(connection: u64) -> bool { return qtc_disconnect(connection) == 0; }
// A direct Qt connection between two objects, e.g. slider valueChanged -> progress setValue.
fn connect_to(sender: Obj, signal: const u8[:], receiver: Obj, method: const u8[:]) -> u64 {
    return qtc_connect_to(sender.h, signal, receiver.h, method);
}
// The watch bit of an event kind, for watch().
fn bit(kind: i64) -> u64 { return (1 as u64) << ((kind - 16) as u64); }
fn watch(o: Obj, mask: u64, tag: u64) -> u64 { return qtc_watch(o.h, mask, 0, tag); }
// Events in consume_mask are delivered to you and kept from the object.
fn watch(o: Obj, mask: u64, consume_mask: u64, tag: u64) -> u64 { return qtc_watch(o.h, mask, consume_mask, tag); }
fn unwatch(w: u64) -> bool { return qtc_unwatch(w) == 0; }
// A started timer delivering EV_TIMER events (coalesced). Destroy it to stop it.
fn timer(interval_ms: i64, tag: u64) -> Obj { return Obj { h: qtc_timer(interval_ms, false, tag) }; }
fn single_shot(interval_ms: i64, tag: u64) -> Obj { return Obj { h: qtc_timer(interval_ms, true, tag) }; }

// --------------------------------------------------------------- objects

fn app() -> Obj { return Obj { h: qtc_app() }; }
// Creates an object of any class by name, with arguments pushed by arg().
fn new_object(class_name: const u8[:]) -> Obj { return Obj { h: qtc_new(class_name) }; }
fn destroy(o: Obj) -> bool { return qtc_destroy(o.h) == 0; }
fn adopt(o: Obj) { qtc_adopt(o.h); }
fn alive(o: Obj) -> bool { return qtc_alive(o.h); }
fn is_null(o: Obj) -> bool { return o.h == 0; }
fn class_name(o: Obj) -> u8[>..] { return view(qtc_class_name(o.h)); }
fn inherits(o: Obj, class_name: const u8[:]) -> bool { return qtc_inherits(o.h, class_name); }
fn find_child(o: Obj, object_name: const u8[:]) -> Obj { return Obj { h: qtc_find_child(o.h, object_name, "", true) }; }
fn find_child(o: Obj, object_name: const u8[:], class_name: const u8[:]) -> Obj {
    return Obj { h: qtc_find_child(o.h, object_name, class_name, true) };
}
fn live_objects() -> i64 { return qtc_live_objects(); }
fn live_values() -> i64 { return qtc_live_values(); }
fn format(out: u8[>..]&, o: Obj) {
    if o.h == 0 { out.append("qt::Obj(null)"); return; }
    if !qtc_alive(o.h) { out.append(str("qt::Obj(stale #", o.h & 4294967295, ")")); return; }
    out.append(str(view(qtc_class_name(o.h)), "#", o.h & 4294967295));
}

// ---------------------------------------------------------- dynamic calls

fn arg(v: bool) { qtc_arg_bool(v); }
fn arg(v: i64) { qtc_arg_int(v); }
fn arg(v: f64) { qtc_arg_double(v); }
fn arg(v: const u8[:]) { qtc_arg_str(v); }
fn arg(o: Obj) { qtc_arg_obj(o.h); }
fn arg(v: Val) { qtc_arg_val(v.h); }
fn arg_bytes(v: const u8[:]) { qtc_arg_bytes(v); }
fn arg_null() { qtc_arg_null(); }
// Calls any method by name or signature with the pushed arguments.
fn call(o: Obj, method: const u8[:]) -> bool { return qtc_call(o.h, method) == 0; }
fn call(v: Val, method: const u8[:]) -> bool { return qtc_call(v.h, method) == 0; }
fn call_static(class_name: const u8[:], method: const u8[:]) -> bool { return qtc_call_static(class_name, method) == 0; }
fn ret_kind() -> i64 { return qtc_ret_kind(); }
fn ret_bool() -> bool { return qtc_ret_bool(); }
fn ret_int() -> i64 { return qtc_ret_int(); }
fn ret_f64() -> f64 { return qtc_ret_double(); }
fn ret_str() -> u8[>..] { return view(qtc_ret_str()); }
fn ret_obj() -> Obj { return Obj { h: qtc_ret_obj() }; }
fn ret_val() -> Val { return Val { h: qtc_ret_val() }; }
// The last call's result as T, picked when it is specialized: qt::call(o, "count"); let n = qt::ret<i64>();
fn ret<T>() -> T {
    const if same<T, i64> { return ret_int(); }
    else const if same<T, f64> { return ret_f64(); }
    else const if same<T, bool> { return ret_bool(); }
    else const if same<T, Obj> { return ret_obj(); }
    else const if same<T, Val> { return ret_val(); }
    else { return ret_str(); }
}

// Out-parameters (bool *ok, int *x, ...): leave them out of a call and read them after it,
// in parameter order: let n = s.toInt(16); if !qt::out_bool(0) { ... }
fn out_count() -> i64 { return qtc_out_count(); }
fn out_bool(index: i64) -> bool { return qtc_out_bool(index as i32); }
fn out_int(index: i64) -> i64 { return qtc_out_int(index as i32); }
fn out_f64(index: i64) -> f64 { return qtc_out_double(index as i32); }

// Largest single allocation (bytes) that arguments may make Qt perform; 0 restores the 256 MiB default.
fn set_alloc_limit(bytes: i64) -> bool { return qtc_set_alloc_limit(bytes) == 0; }
fn alloc_limit() -> i64 { return qtc_alloc_limit(); }

// ------------------------------------------------------------ properties

fn set(o: Obj, prop: const u8[:], v: const u8[:]) -> bool { return qtc_set_str(o.h, prop, v) == 0; }
fn set(o: Obj, prop: const u8[:], v: i64) -> bool { return qtc_set_int(o.h, prop, v) == 0; }
fn set(o: Obj, prop: const u8[:], v: f64) -> bool { return qtc_set_double(o.h, prop, v) == 0; }
fn set(o: Obj, prop: const u8[:], v: bool) -> bool { return qtc_set_bool(o.h, prop, v) == 0; }
fn set(o: Obj, prop: const u8[:], v: Obj) -> bool { qtc_arg_obj(v.h); return qtc_prop_set(o.h, prop) == 0; }
fn set(o: Obj, prop: const u8[:], v: Val) -> bool { qtc_arg_val(v.h); return qtc_prop_set(o.h, prop) == 0; }
fn get_str(o: Obj, prop: const u8[:]) -> u8[>..] { return view(qtc_get_str(o.h, prop)); }
fn get_int(o: Obj, prop: const u8[:]) -> i64 { return qtc_get_int(o.h, prop); }
fn get_f64(o: Obj, prop: const u8[:]) -> f64 { return qtc_get_double(o.h, prop); }
fn get_bool(o: Obj, prop: const u8[:]) -> bool { return qtc_get_bool(o.h, prop); }
// One getter for every property type, picked when it is specialized:
//   let v = slider.prop<i64>("value"); let t = label.prop<u8[]>("text"); let p = w.prop<Obj>("parent");
// i64, f64, bool, Obj, Val, and a string type for the rest (u8[], or u8[>..] for the view get_str gives).
fn prop<T>(o: Obj, name: const u8[:]) -> T {
    const if same<T, i64> { return get_int(o, name); }
    else const if same<T, f64> { return get_f64(o, name); }
    else const if same<T, bool> { return get_bool(o, name); }
    else const if same<T, Obj> { return get_obj(o, name); }
    else const if same<T, Val> { return get_val(o, name); }
    else { return get_str(o, name); }
}
fn get_obj(o: Obj, prop: const u8[:]) -> Obj {
    if qtc_prop_get(o.h, prop) != 0 { return NONE; }
    return Obj { h: qtc_ret_obj() };
}
fn get_val(o: Obj, prop: const u8[:]) -> Val {
    if qtc_prop_get(o.h, prop) != 0 { return Val { h: 0 }; }
    return Val { h: qtc_ret_val() };
}

// ---------------------------------------------------------------- values

fn val(v: bool) -> Val { return Val { h: qtc_val_bool(v) }; }
fn val(v: i64) -> Val { return Val { h: qtc_val_int(v) }; }
fn val(v: f64) -> Val { return Val { h: qtc_val_double(v) }; }
fn val(v: const u8[:]) -> Val { return Val { h: qtc_val_str(v) }; }
fn val(o: Obj) -> Val { return Val { h: qtc_val_obj(o.h) }; }
fn bytes_val(v: const u8[:]) -> Val { return Val { h: qtc_val_bytes(v) }; }
fn new_list() -> Val { return Val { h: qtc_val_list() }; }
fn new_map() -> Val { return Val { h: qtc_val_map() }; }
// A Qt value by type name ("QColor", "QFont", ...) built from pushed arguments.
fn new_value(type_name: const u8[:]) -> Val { return Val { h: qtc_val_new(type_name) }; }
fn from_json(json: const u8[:]) -> Val { return Val { h: qtc_val_from_json(json) }; }
fn free(v: Val) -> bool { return qtc_val_free(v.h) == 0; }
fn clone(v: Val) -> Val { return Val { h: qtc_val_copy(v.h) }; }
fn alive(v: Val) -> bool { return qtc_alive(v.h); }
fn is_null(v: Val) -> bool { return v.h == 0; }
fn kind(v: Val) -> i64 { return qtc_val_kind(v.h); }
fn type_name(v: Val) -> u8[>..] { return view(qtc_val_type_name(v.h)); }
fn to_bool(v: Val) -> bool {
    var b = false;
    qtc_val_get_bool(v.h, b);
    return b;
}
fn to_int(v: Val) -> i64 {
    var x = 0;
    qtc_val_get_int(v.h, x);
    return x;
}
fn to_f64(v: Val) -> f64 {
    var x = 0.0;
    qtc_val_get_double(v.h, x);
    return x;
}
fn to_str(v: Val) -> u8[>..] { return view(qtc_val_get_str(v.h)); }
fn to_obj(v: Val) -> Obj { return Obj { h: qtc_val_get_obj(v.h) }; }
fn convert(v: Val, type_name: const u8[:]) -> Val { return Val { h: qtc_val_convert(v.h, type_name) }; }
fn equal(a: Val, b: Val) -> bool { return qtc_val_equal(a.h, b.h); }
fn json(v: Val) -> u8[>..] { return view(qtc_val_to_json(v.h)); }
fn describe(v: Val) -> u8[>..] { return view(qtc_val_to_string(v.h)); }
fn list_len(l: Val) -> i64 { return qtc_list_len(l.h); }
fn list_get(l: Val, i: i64) -> Val { return Val { h: qtc_list_get(l.h, i) }; }
fn list_append(l: Val, item: Val) -> bool { return qtc_list_append(l.h, item.h) == 0; }
fn list_append(l: Val, item: Obj) -> bool { return qtc_list_append(l.h, item.h) == 0; }
fn list_set(l: Val, i: i64, item: Val) -> bool { return qtc_list_set(l.h, i, item.h) == 0; }
fn list_remove(l: Val, i: i64) -> bool { return qtc_list_remove(l.h, i) == 0; }
fn list_clear(l: Val) -> bool { return qtc_list_clear(l.h) == 0; }
fn map_len(m: Val) -> i64 { return qtc_map_len(m.h); }
fn map_get(m: Val, key: const u8[:]) -> Val { return Val { h: qtc_map_get(m.h, key) }; }
fn map_set(m: Val, key: const u8[:], item: Val) -> bool { return qtc_map_set(m.h, key, item.h) == 0; }
fn map_remove(m: Val, key: const u8[:]) -> bool { return qtc_map_remove(m.h, key) == 0; }
fn map_has(m: Val, key: const u8[:]) -> bool { return qtc_map_has(m.h, key); }
fn map_keys(m: Val) -> Val { return Val { h: qtc_map_keys(m.h) }; }
fn format(out: u8[>..]&, v: Val) {
    if v.h == 0 { out.append("qt::Val(null)"); return; }
    if !qtc_alive(v.h) { out.append("qt::Val(stale)"); return; }
    out.append(view(qtc_val_to_string(v.h)));
}

// --------------------------------------------------------- introspection

fn class_exists(class_name: const u8[:]) -> bool { return qtc_class_exists(class_name); }
fn class_count() -> i64 { return qtc_class_count(); }
fn class_at(i: i64) -> u8[>..] { return view(qtc_class_at(i)); }
// JSON: properties, signals, methods and constructors of a class.
fn describe_class(class_name: const u8[:]) -> u8[>..] { return view(qtc_describe(0, class_name)); }
fn describe(o: Obj) -> u8[>..] { return view(qtc_describe(o.h, "")); }
fn enum_value(qualified_name: const u8[:]) -> i64, bool {
    var x = 0;
    let ok = qtc_enum_value(qualified_name, x) == 0;
    return x, ok;
}
fn stats() -> u8[>..] { return view(qtc_stats()); }

// --------------------------------------------------------------- drawing
// Record on a QtcCanvas widget (it repaints from the recording) or draw on a
// QImage / QPixmap value. Colours are 0xAARRGGBB.

fn draw_begin(canvas: Obj) -> bool { return qtc_draw_begin(canvas.h) == 0; }
fn draw_begin(image: Val) -> bool { return qtc_draw_begin(image.h) == 0; }
fn draw_end() -> bool { return qtc_draw_end() == 0; }
fn draw_clear(argb: u32) { qtc_draw_clear(argb); }
fn draw_pen(argb: u32, width: f64) { qtc_draw_pen(argb, width, 1, 0x10, 0x40); }
// style: Qt::PenStyle, cap: Qt::PenCapStyle, join: Qt::PenJoinStyle
fn draw_pen(argb: u32, width: f64, style: i64, cap: i64, join: i64) { qtc_draw_pen(argb, width, style as i32, cap as i32, join as i32); }
fn draw_no_pen() { qtc_draw_no_pen(); }
fn draw_brush(argb: u32) { qtc_draw_brush(argb, 1); }
fn draw_brush(argb: u32, style: i64) { qtc_draw_brush(argb, style as i32); }
fn draw_no_brush() { qtc_draw_no_brush(); }
fn draw_linear_gradient(x1: f64, y1: f64, x2: f64, y2: f64, argb1: u32, argb2: u32) {
    qtc_draw_linear_gradient(x1, y1, x2, y2, argb1, argb2);
}
fn draw_font(family: const u8[:], point_size: f64) { qtc_draw_font(family, point_size, 400, false); }
fn draw_font(family: const u8[:], point_size: f64, weight: i64, italic: bool) { qtc_draw_font(family, point_size, weight as i32, italic); }
fn draw_antialias(on: bool) { qtc_draw_antialias(on); }
fn draw_opacity(o: f64) { qtc_draw_opacity(o); }
fn draw_save() { qtc_draw_save(); }
fn draw_restore() { qtc_draw_restore(); }
fn draw_translate(dx: f64, dy: f64) { qtc_draw_translate(dx, dy); }
fn draw_rotate(degrees: f64) { qtc_draw_rotate(degrees); }
fn draw_scale(sx: f64, sy: f64) { qtc_draw_scale(sx, sy); }
fn draw_clip_rect(x: f64, y: f64, w: f64, h: f64) { qtc_draw_clip_rect(x, y, w, h); }
fn draw_point(x: f64, y: f64) { qtc_draw_point(x, y); }
fn draw_line(x1: f64, y1: f64, x2: f64, y2: f64) { qtc_draw_line(x1, y1, x2, y2); }
fn draw_rect(x: f64, y: f64, w: f64, h: f64) { qtc_draw_rect(x, y, w, h); }
fn draw_rounded_rect(x: f64, y: f64, w: f64, h: f64, rx: f64, ry: f64) { qtc_draw_rounded_rect(x, y, w, h, rx, ry); }
fn draw_ellipse(x: f64, y: f64, w: f64, h: f64) { qtc_draw_ellipse(x, y, w, h); }
fn draw_arc(x: f64, y: f64, w: f64, h: f64, start: f64, span: f64) { qtc_draw_arc(x, y, w, h, start, span); }
fn draw_pie(x: f64, y: f64, w: f64, h: f64, start: f64, span: f64) { qtc_draw_pie(x, y, w, h, start, span); }
fn draw_polyline(xy: const f64[:]) { qtc_draw_polyline(xy); }
fn draw_polygon(xy: const f64[:]) { qtc_draw_polygon(xy); }
fn draw_path_move(x: f64, y: f64) { qtc_draw_path_move(x, y); }
fn draw_path_line(x: f64, y: f64) { qtc_draw_path_line(x, y); }
fn draw_path_quad(cx: f64, cy: f64, x: f64, y: f64) { qtc_draw_path_quad(cx, cy, x, y); }
fn draw_path_cubic(c1x: f64, c1y: f64, c2x: f64, c2y: f64, x: f64, y: f64) { qtc_draw_path_cubic(c1x, c1y, c2x, c2y, x, y); }
fn draw_path_close() { qtc_draw_path_close(); }
fn draw_path_end() { qtc_draw_path_end(); }
fn draw_text(x: f64, y: f64, text: const u8[:]) { qtc_draw_text(x, y, text); }
// flags: Qt::AlignmentFlag | Qt::TextFlag
fn draw_text_in(x: f64, y: f64, w: f64, h: f64, flags: i64, text: const u8[:]) { qtc_draw_text_in(x, y, w, h, flags as i32, text); }
fn draw_image(image: Val, x: f64, y: f64, w: f64, h: f64) { qtc_draw_image(image.h, x, y, w, h); }
fn draw_count() -> i64 { return qtc_draw_count(); }

// --------------------------------------------------------------- testing
// Simulated input through libqtc_test (QtTest), for test programs. The library
// is only opened when one of these is called. Positions are in the widget's
// coordinates; x or y < 0 means its centre.

extern "qtc_test" {
    fn qtct_click(widget: u64, button: i32, modifiers: i32, x: i32, y: i32) -> i32;
    fn qtct_double_click(widget: u64, button: i32, modifiers: i32, x: i32, y: i32) -> i32;
    fn qtct_press(widget: u64, button: i32, modifiers: i32, x: i32, y: i32) -> i32;
    fn qtct_release(widget: u64, button: i32, modifiers: i32, x: i32, y: i32) -> i32;
    fn qtct_move(widget: u64, x: i32, y: i32) -> i32;
    fn qtct_wheel(widget: u64, delta_y: i32, delta_x: i32, x: i32, y: i32) -> i32;
    fn qtct_key(widget: u64, key: i32, modifiers: i32) -> i32;
    fn qtct_type(widget: u64, text: const u8[:]) -> i32;
    fn qtct_wait(ms: i64) -> i32;
    fn qtct_grab(widget: u64, png_path: const u8[:]) -> i32;
    fn qtct_show(widget: u64) -> i32;
}

fn test_click(w: Obj) -> bool { return qtct_click(w.h, 1, 0, -1, -1) == 0; }
fn test_click(w: Obj, x: i64, y: i64) -> bool { return qtct_click(w.h, 1, 0, x as i32, y as i32) == 0; }
fn test_click(w: Obj, button: i64, modifiers: i64, x: i64, y: i64) -> bool {
    return qtct_click(w.h, button as i32, modifiers as i32, x as i32, y as i32) == 0;
}
fn test_double_click(w: Obj, x: i64, y: i64) -> bool { return qtct_double_click(w.h, 1, 0, x as i32, y as i32) == 0; }
fn test_press(w: Obj, x: i64, y: i64) -> bool { return qtct_press(w.h, 1, 0, x as i32, y as i32) == 0; }
fn test_release(w: Obj, x: i64, y: i64) -> bool { return qtct_release(w.h, 1, 0, x as i32, y as i32) == 0; }
fn test_move(w: Obj, x: i64, y: i64) -> bool { return qtct_move(w.h, x as i32, y as i32) == 0; }
fn test_wheel(w: Obj, delta_y: i64) -> bool { return qtct_wheel(w.h, delta_y as i32, 0, -1, -1) == 0; }
fn test_key(w: Obj, key: i64) -> bool { return qtct_key(w.h, key as i32, 0) == 0; }
fn test_key(w: Obj, key: i64, modifiers: i64) -> bool { return qtct_key(w.h, key as i32, modifiers as i32) == 0; }
fn test_type(w: Obj, text: const u8[:]) -> bool { return qtct_type(w.h, text) == 0; }
fn test_wait(ms: i64) -> bool { return qtct_wait(ms) == 0; }
fn test_grab(w: Obj, png_path: const u8[:]) -> bool { return qtct_grab(w.h, png_path) == 0; }
fn test_show(w: Obj) -> bool { return qtct_show(w.h) == 0; }
