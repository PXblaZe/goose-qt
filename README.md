# goose-qt — Qt 6 for Goose

goose-qt binds [qtc](../qtc), the C library for Qt 6, to the Goose language:
widgets, Qt Quick and QML, painting, models, networking, multimedia and the rest
of what qtc binds — about 9,500 functions and 1,500 constructors, generated from
qtc's manifest — with the same guarantee: misusing an object returns an error
instead of crashing the program, within the limits qtc's
[LIMITS.md](../qtc/docs/LIMITS.md) spells out.

```goose
import qt from "path/to/goose-qt";

fn main() {
    qt::init();
    let win = qt::QWidget();
    let layout = qt::QVBoxLayout(win);
    let label = qt::QLabel("Not clicked yet");
    let button = qt::QPushButton("Click me");
    layout.addWidget(label);
    layout.addWidget(button);
    qt::connect(button, "clicked", 1);
    win.show();

    var clicks = 0;
    var ev = default<qt::Event>();
    while qt::wait(-1) == qt::WAIT_EVENTS {
        while qt::poll(ev) {
            if ev.tag == 1 {
                clicks++;
                label.setText(str("Clicked ", clicks, " times"));
            }
        }
    }
    qt::shutdown();
}
```

## Installing

1. Build and install qtc on Qt 6.12 LTS (see its README). goose-qt loads `libqtc.so.1`
   (`libqtc.1.dylib`, `qtc.dll`) at run time, from the library path.
2. Put this directory somewhere and import it by path:
   `import qt from "path/to/goose-qt";`

Run with the JIT, or build a native program:

```sh
goose app.goose
goose build app.goose -o app && ./app
```

If qtc is not installed system-wide, point the loader at its build directory:
`LD_LIBRARY_PATH=/path/to/qtc/build goose app.goose`.

## How the API looks

- **Objects** are `qt::Obj`, **values** (colours, fonts, images, dates, lists,
  maps …) are `qt::Val`. Both are handles; using one after it is gone is an error
  qtc reports (`qt::ERR_STALE_HANDLE`), not a crash. Free values with `v.free()`.
- **Constructors** are functions named after the class: `qt::QLabel("text")`,
  `qt::QImage(400, 300, qt::QImage.Format_ARGB32)`. An object made without a
  parent belongs to qtc until it gets one; `qt::shutdown()` destroys the rest.
- **Methods** are functions taking the receiver first, so UFCS reads like C++:
  `label.setText("hi")`, `slider.value_int()`, `img.pixelColor(2, 3)`. One
  function covers every class with a method of that name and shape; qtc picks the
  overload for the receiver's class at run time. Where Qt methods of one name
  return different kinds, the variants carry a suffix: `value()` (a double) and
  `value_int()`, `model()` and `model_obj()`.
- **Static methods** are `qt::Class_method(...)`: `qt::QDateTime_currentDateTime()`.
- **Enums** are fields of a value named after their scope: `qt::Qt.AlignCenter`,
  `qt::QImage.Format_ARGB32`; flags combine with `|`.
- **Properties** without a setter function, and properties of QML objects:
  `qt::set(obj, "name", value)`, `qt::get_int(obj, "name")`, `qt::get_str(...)`.
- **Anything else** goes through the generic call: push arguments with
  `qt::arg(...)` and `qt::call(obj, "method")` / `qt::call(obj, "method(int,QString)")`,
  then read `qt::ret_int()`, `qt::ret_str()`, `qt::ret_obj()`, `qt::ret_val()`.

### Events

```goose
qt::connect(button, "clicked", 1);                 // a signal, queued with tag 1
qt::connect(edit, "textEdited", 2, qt::CONN_COALESCE);
qt::watch(canvas, qt::bit(qt::EV_MOUSE_PRESS), 3); // input events of a widget
let timer = qt::timer(1000, 4);                     // qt::single_shot(ms, tag) fires once
var ev = default<qt::Event>();
while qt::wait(-1) == qt::WAIT_EVENTS {
    while qt::poll(ev) {
        // ev.tag, ev.kind, ev.i0..i3, ev.d0, ev.d1; the signal's arguments:
        // ev.arg_str(0), ev.arg_int(0), ev.arg_val(0), ev.arg_obj(0)
    }
}
```

Signals never run Goose code inside Qt: they are queued and read at the top of
the loop, so a handler may destroy anything, including the sender.
`qt::post(tag, a, b)` queues an event from any thread (native builds) and is how
worker threads report back.

### Drawing

```goose
let canvas = qt::new_object("QtcCanvas");    // a widget that shows the last recording
if qt::draw_begin(canvas) {
    qt::draw_clear(0xff202020);
    qt::draw_pen(0xffffffff, 2.0);
    qt::draw_line(0.0, 0.0, 100.0, 100.0);
    qt::draw_end();
}
```

The same calls paint into a `QImage` value.

### QML

Load QML with `QQmlApplicationEngine` as in C++. A `QtcBridge` object set as a
context property carries structured messages both ways: QML's
`bridge.send(name, payload)` arrives as a `sent` event, and
`qt::call(bridge, "post")` with a name and a value emits `message` in QML. QML
properties and functions are reached with `qt::get_*`, `qt::set` and `qt::call`.

### Subclassing Qt classes

Make an overridable object, name the methods to override with a tag each, and
export the one handler they all come to:

```goose
let ROWS: u64 = 1;

export "goose_qt_override" fn on_override(obj: u64, tag: u64, nargs: i64, depth: i64) -> i32 {
    if tag == ROWS { qt::ov_ret(42); return qt::OV_DONE; }
    return qt::OV_BASE;                      // the class's own implementation
}

fn main() {
    qt::init();
    qt::use_overrides();                     // points qtc at goose_qt_override
    let model = qt::new_overridable("QAbstractListModel");
    qt::override(model, "rowCount", ROWS);
    ...
}
```

The handler reads the call with `qt::ov_arg_*` and sets its result with
`qt::ov_ret`. It runs on the GUI thread; methods Qt calls on other threads run
Qt's own implementation. Runtime classes (`qt::class_begin`, `class_property`,
`class_invokable`, `class_end`, `class_new`) send their slots to the same handler.

### Futures

`qt::promise()` makes a future that Goose worker threads (`thread_fn`, native
builds) fill with `qt::add`, `qt::progress`, `qt::finish` or `qt::fail`, checking
`qt::canceled`; the GUI thread waits with `qt::wait(f, ms)`, watches it as
`EV_FUTURE_*` events, and reads `qt::result_int(f, i)` and friends. Calls queued
to objects (`qt::invoke_future`) and worker objects on a `QThread`
(`qt::move_to_thread`) work as in C.

### Graphics

```goose
let r = qt::rhi_create(qt::RHI_VULKAN);     // or RHI_OPENGL, RHI_D3D11, RHI_METAL, RHI_NULL
let tex = qt::texture(r, qt::RGBA8, 256, 256, qt::RENDER_TARGET | qt::READABLE);
let rt = qt::render_target(tex, false);
let vb = qt::buffer(r, qt::IMMUTABLE, qt::VERTEX_BUFFER, 3 * 20);
qt::upload_f32(vb, 0, [0.0, 0.8, 1.0, 0.0, 0.0,  -0.7, -0.6, 0.0, 1.0, 0.0,  0.7, -0.6, 0.0, 0.0, 1.0]);
let p = qt::pipeline(r);
qt::shaders(p, qt::shader_bake(qt::VERTEX, vertex_glsl), qt::shader_bake(qt::FRAGMENT, fragment_glsl));
...
qt::begin_frame(r);
qt::begin_pass(r, rt, 0xff000000);
qt::set_pipeline(r, p);
...
qt::draw(r, 3);
qt::end_pass(r);
let rb = qt::read_texture(tex);
qt::end_frame(r);
let image = qt::image(rb);                    // a QImage value
```

Every RHI handle is a `qt::Gpu`; `test/t09_graphics.goose` is a complete
program. Swapchains on windows, `QRhiWidget` rendering, compute and the native
interop (`qt::native`, `qt::vk_*`, `qt::gl_proc_address`) are there too.

## Examples

`examples/` has the same programs as qtc's C examples: `hello`, `form`,
`canvas`, `qml`, `threads` (native only) and `rhi` (a triangle drawn with
whichever of Vulkan, Metal, Direct3D, OpenGL or the Null backend the machine
has). Each runs interactively, or checks
itself:

```sh
goose examples/hello.goose -- --selftest
examples/run.sh                       # all of them, JIT and native
```

## Tests

```sh
GOOSE=/path/to/goose QTC_LIB=/path/to/qtc/build test/run.sh
```

runs the test programs with the JIT and as native builds (the threads and futures
tests natively only), on Qt's offscreen platform:

| test | covers |
|---|---|
| `t01_basics` | init, objects, calls, properties, values, enums, errors, stale handles |
| `t02_events` | signals, coalescing, watches, timers, posts, stale sources |
| `t03_widgets` | a form built from widgets, simulated input, a screenshot |
| `t04_drawing` | the canvas and image drawing calls |
| `t05_qml` | QML loading, the bridge both ways, QML properties and functions |
| `t06_threads` | workers posting from native threads |
| `t07_overrides` | a list model, a painted widget, a validator and key events written in Goose; a runtime class |
| `t08_futures` | futures filled by Goose worker threads: results, progress events, failure, cancel, any/all, queued calls and a worker object (native only) |
| `t09_graphics` | the RHI: a pipeline checked against its shaders, a frame read back, compute, destruction order (Null, and OpenGL or Vulkan where present) |
| `t90_wrappers` | every one of the 8,464 generated instance-method wrappers, called on a null receiver |

`test/bench.goose` measures what a call costs. On the development machine
(x86-64, Qt 6.12, native build), a generated wrapper call such as
`label.setText("hello")` takes about 0.6 µs, a signal round trip about 0.7 µs,
`qt::post` + `qt::poll` 0.1 µs.

## Regenerating

`api.goose` is generated from qtc's manifest; regenerate it after updating qtc:

```sh
python3 gen/generate_goose.py --manifest /path/to/qtc/manifest/qtc_api.json --out .
```

A function keeps the return type the `api.goose` it replaces gave it, so programs
keep compiling when a newly bound class has a method of the same name returning
something else; that class's result comes from the typed variant (`name_int`,
`width_val`). Pass `--baseline` to compare against another file.

`qt.goose` (the hand-written part: the event loop, values, drawing, the generic
call), `extra.goose` (overrides, runtime classes, futures, graphics),
`include/goose_qt.h` (the C trampoline for override handlers) and `qt.build`
(which shared libraries to load) are not generated.

## Limits

Everything in [qtc's LIMITS.md](../qtc/docs/LIMITS.md) applies. In addition:

- The enum constants are those of Qt 6.12. With qtc built on an older Qt (an
  untested opt-in), a value that release does not have is refused when it is
  passed.
- The JIT runs no threads; threaded programs need a native build.
- Goose has no function pointers, and its exported functions run on the main
  thread only: override handlers are the one exported `goose_qt_override`, which
  handles calls on the GUI thread (others run Qt's own implementation), and qtc's
  thread-pool tasks (`qtc_task_*`, which take C functions) are not bound — Goose
  workers fill promises instead. The trampoline (`include/goose_qt.h`) declares
  the handler as a weak symbol, which GCC, Clang and TinyCC support; it was
  tested on Linux only.
- The wrappers of the GPL-3.0-only modules (Charts and the network add-ons) are
  in `api.goose` like the rest: they are calls by name, and with a default
  (LGPL-only) libqtc they fail with `ERR_NOT_FOUND`. Whether a program is bound
  by the GPL depends on the libqtc it runs with, not on goose-qt.
- Overloads that differ only in Goose types that map to the same C kind (two
  integer types, say) are one Goose function; qtc chooses between them by the
  receiver's class and the argument values. Pass a signature through `qt::call`
  to pick one yourself.

## License

MIT, see [LICENSE](LICENSE). Qt's own license terms apply to programs that use it.
