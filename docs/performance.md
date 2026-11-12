# Performance

Every Qt call from Goose goes through qtc: arguments are pushed, the method is looked up
(cached per class and name), the arguments are checked, the call is made, and the result is
converted back. That costs a fraction of a microsecond per call, on top of what Qt itself
spends. For a user interface that is invisible; for hot loops it is worth knowing where the
time goes.

All numbers here are from one machine: two cores of a 2.1 GHz Xeon, 7 GB of memory, Linux,
Qt 6.12.0. Yours will differ; run the benchmarks to see.

## What a call costs

`test/bench.goose` (nanoseconds per operation, medians of five native runs and three JIT
runs; this machine is noisy, so differences under about 15% mean little):

| Operation | Native | JIT |
|---|---:|---:|
| `label.setText("hello")` (a generated wrapper) | 59 | 98 |
| `qt::set(label, "text", …)` (the property system) | 139 | 193 |
| `slider.setValue(i)` | 50 | 49 |
| `slider.value_int()` | 16 | 25 |
| `label.text()` (a string back) | 61 | 73 |
| `qt::val(i)` and free | 53 | 84 |
| `color.red()` (a method on a `qt::Val`) | 18 | 26 |
| `c.red()` on a `qt::Color` (a struct) | 10 | 14 |
| `qt::color(…)` made and read (a struct) | 18 | 27 |
| `button.click()` and `qt::poll` (a signal round trip) | 186 | 216 |
| `qt::post` and `qt::poll` | 77 | 91 |
| `qt::alive(handle)` | 4 | 6 |
| a call on a stale handle (refused) | 180 | 191 |

A direct signal (`qt::CONN_DIRECT`, see [Events](events.md#direct-signals)) runs its handler
inside the click: 157 ns in [the comparison](comparison.md)'s run.

```sh
goose build test/bench.goose -o bench && ./bench
```

A direct C++ call to `QLabel::setText` costs about 5 ns. The rest of a goose-qt call is qtc's
work. A generated wrapper calls qtc's entry point for that exact signature
(`qtcm_setText__QString`), which looks the signature up once per class and then goes
straight to the thunk; the thunk checks the receiver handle (alive, its thread, its class)
and each argument, converts the string, and makes the call. The JIT and native builds are
close, because the time is spent outside Goose. Early in development these took 3–6× as
long. [How goose-qt compares](comparison.md) has the work that changed that, and the same
operations in C++, PyQt6, PySide6, Go and Rust.

## What the samples sustain

These were measured during development, before the last call-path work; they are bound by
Qt, the network stack or the arithmetic in Goose more than by calls.

| Sample | Sustained |
|---|---|
| [million](../samples/million/million.goose) | a model in Goose answering about 1.8 million `data()` calls a second while `QSortFilterProxyModel` filters a million rows; about 500 pages scrolled and painted a second |
| [loopback](../samples/loopback/loopback.goose) | 780,000 TCP round trips a second between 16 clients and a server on one thread; a 64 MB stream at 298 MB/s, checksummed in Goose |
| [scope](../samples/scope/scope.goose) | 94 frames a second of four 1,024-point polylines painted in Goose, fed by 200,000 samples a second from four threads, none dropped |
| [mandelbrot](../samples/mandelbrot/mandelbrot.goose) | a 1024 × 768 fractal in 67 ms from four Goose threads on two cores |
| [notes](../samples/notes/notes.goose) | 2,000 notes made in 8 ms, searched in 6 ms, saved as 326 KB of JSON in 5 ms and loaded in 17 ms |
| [chaos](../samples/chaos/chaos.goose) | 36,000–40,000 random API operations a second, most of them refused |

## Making programs fast

- **Let Qt do bulk work.** One call that does a lot (`setPlainText` with the whole text,
  `upload_f32` with a whole array, `draw_polyline` with every point, `readAll`) costs one
  call's overhead. A loop of small calls costs the overhead every time.
- **Models, not widgets, for many items.** A view asks a model only for the cells it shows;
  a million-row model costs no more to show than a hundred-row one.
- **Coalesce chatty signals** (`qt::CONN_COALESCE`): a burst of `textChanged`,
  `valueChanged` or `readyRead` becomes one event.
- **Batch what threads post.** A post carries two integers; pack several values into them,
  or hand larger results over through a future.
- **Keep values you reuse.** Making and freeing a value costs 70 ns and up; a `QColor` or
  `QFont` used every frame can be made once.
- **Keep objects you reuse.** Making and destroying a `QObject` costs about 0.2 µs (each gets
  a handle and its ownership is tracked, so that a stale handle is an error, not a crash).
  That is cheap, but a reused object costs nothing.
- **Use the value structs** for points, sizes, rectangles, lines, margins and colors
  (`qt::rect(...)`, `qt::color(...)`, see [Values](values.md)): no handle to make, look up
  and free, a few nanoseconds per method.
- **Use the typed constructors and methods** (`qt::QObject()`, `label.setText(...)`) rather
  than `qt::new_object("QObject")` and `qt::call(...)` by name: they call qtc's direct entry
  points and skip the lookup by name.
- **Skip argument capture** for signals whose arguments you ignore: `qt::CONN_NO_ARGS`.
- **Use typed getters.** `slider.value_int()` is cheaper than going through the property
  system by name.
- **Build natively** for code that computes in Goose (the mandelbrot bands, the loopback
  checksum): the JIT is close for calls into Qt, but Goose's own loops run faster native.
