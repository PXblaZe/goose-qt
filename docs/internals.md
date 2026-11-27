# Internals

How goose-qt is put together, for people changing it or binding qtc to another language the
same way.

## Layers

```
your program
  │  qt::QLabel("hi").setText(...)        Goose functions
  ▼
api.goose      generated: one wrapper per method name and shape, constructors, statics, enums
               (Qt Core, Gui, Widgets; each other module in a file of its own: network.goose, ...)
values.goose   generated: small value types as structs (qtc_inline.h), gen/generate_values.py
qt.goose       hand-written: init, the event loop, the generic call, properties, values, drawing
extra.goose    hand-written: overrides, runtime classes, futures, graphics
  │  extern "qtc" { fn qtc_call(...) ... }  Goose's FFI
  ▼
libqtc         C ABI: handles, argument frames, checks, events
  ▼
Qt 6.12
```

A generated wrapper is one line: it pushes its arguments and calls by name or signature.

```goose
fn setText(o: Obj, a0: const u8[:]) { qtc_arg_str(a0); qtc_call(o.h, "setText(QString)"); }
fn value_int(o: Obj) -> i64 { qtc_call(o.h, "value()"); return qtc_ret_int(); }
```

All checking happens in qtc, so a wrapper and the generic call behave the same.

## Generating api.goose

```sh
python3 gen/generate_goose.py --manifest /path/to/qtc/manifest/qtc_api.json --out .
# or: cmake --build build --target goose_qt_api
```

qtc's manifest describes every bound class, method, constructor, static and enum. The
generator:

- writes Qt Core, Gui and Widgets to `api.goose` and each other Qt module to a file named
  after it (`network.goose`), with `all.goose` importing them all. A function shared by
  classes of more than one file goes in `api.goose`, as does each extern several files use;

- groups instance methods across classes by name, receiver kind (`Obj` or `Val`) and Goose
  parameter types: one Goose function per group. When every Qt overload behind a group has
  the same signature, the wrapper names it; otherwise it calls by name and qtc picks the
  overload for the receiver at run time;
- gives each group the common return type of its methods (`f64` when they are numbers,
  otherwise `qt::Val`), plus a typed variant per other return type (`value_int`,
  `model_obj`);
- keeps return types stable: a function keeps the type the `api.goose` it replaces gave it
  (`--baseline` names another file to compare against), so programs keep compiling when a
  new qtc binds a class with a same-named method returning something else;
- renames what clashes with Goose's keywords, built-ins or `qt.goose`'s own functions, with a
  trailing underscore (`exit_`, `copy_`);
- writes statics as `Class_method`, constructors as the class name, and each enum scope as a
  struct value with the keys as fields (`qt::Qt.AlignLeft`);
- writes `test/t90_wrappers.goose`, which calls every instance wrapper on a null receiver.

Not generated: `qt.goose`, `extra.goose`, `include/goose_qt.h` and `qt.build`.

## Typed getters

`prop<T>` and `ret<T>` pick their getter when they are specialized, with Goose's `const if`:

```goose
fn ret<T>() -> T {
    const if same<T, i64> { return ret_int(); }
    else const if same<T, f64> { return ret_f64(); }
    else const if same<T, bool> { return ret_bool(); }
    else const if same<T, Obj> { return ret_obj(); }
    else const if same<T, Val> { return ret_val(); }
    else { return ret_str(); }
}
```

## The override trampoline

libqtc calls an override handler through a C function pointer, which Goose cannot make. So
`include/goose_qt.h` (listed in `qt.build`'s `c_headers`) defines the handler in C: a
trampoline that unpacks qtc's call record and calls the Goose function the program exports
as `goose_qt_override`, declared there as a weak symbol so programs without overrides link
too. `qt::use_overrides()` tells libqtc where the trampoline is. Calls that arrive on other
threads get `QTC_OV_BASE` from the trampoline (the class's own implementation), since
exported Goose functions run on the main thread only.

MSVC has no weak symbols: there the header defines a stand-in for each handler and tells the
linker to use it when the program exports none (`/alternatename`), and checks for the
stand-in where GCC, Clang and TinyCC check for a null weak symbol.

## Strings

qtc returns strings as views valid until its next call that returns one; `qt.goose`'s
`view()` copies each into a Goose array (`ffi::bytes`) at once, so a Goose program never
holds a view. Strings into qtc are passed as pointer and length, so they may contain NUL
bytes.

## Versions

| | |
|---|---|
| `qt::version()` | the libqtc version loaded |
| `qt::qt_version()` | the Qt version running |
| `qt::qt_build_version()` | the Qt version libqtc was built against |

The CMake project requires the qtc version `api.goose` was generated from or later
(`GOOSE_QT_QTC_MIN`). The enum values are Qt 6.12's; on an older Qt (an untested opt-in), a
value that release lacks is refused when it is passed.
