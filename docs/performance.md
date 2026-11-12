# Performance

Every Qt call from Goose goes through qtc: arguments are pushed, the method is looked up
(cached per class and name), the arguments are checked, the call is made, and the result is
converted back. That costs a fraction of a microsecond per call, on top of what Qt itself
spends. For a user interface that is invisible; for hot loops it is worth knowing where the
time goes.

All numbers here are from one machine: two cores of a 2.3 GHz Xeon, 7 GB of memory, Linux,
Qt 6.12.0, qtc 1.2.0. Yours will differ; run the benchmarks to see.

## What a call costs

`test/bench.goose` (nanoseconds per operation, qtc 1.2.0):

| Operation | Native | JIT |
|---|---:|---:|
| `label.setText("hello")` (a generated wrapper) | 47 | 54 |
| `qt::set(label, "text", …)` (the property system) | 107 | 114 |
| `slider.setValue(i)` | 41 | 43 |
| `slider.value_int()` | 17 | 20 |
| `label.text()` (a string back) | 56 | 66 |
| `qt::val(i)` and free | 45 | 65 |
| `color.red()` (a method on a value) | 18 | 20 |
| `button.click()` and `qt::poll` (a signal round trip) | 155 | 181 |
| `qt::post` and `qt::poll` | 62 | 69 |
| `qt::alive(handle)` | 5 | 7 |
| a call on a stale handle (refused) | 137 | 156 |

```sh
goose build test/bench.goose -o bench && ./bench
```

A direct C++ call to `QLabel::setText` costs about 5 ns. The rest of a goose-qt call is qtc's
work. A generated wrapper calls qtc's entry point for that exact signature
(`qtcm_setText__QString`), which looks the signature up once per class and then goes
straight to the thunk; the thunk checks the receiver handle (alive, its thread, its class)
and each argument, converts the string, and makes the call. The JIT and native builds are
close, because the time is spent outside Goose. qtc 1.1.0 took 3–6× as long for most of
these. [How goose-qt compares](comparison.md) has the work that changed that, and the same
operations in C++, PyQt6, PySide6 and Go.

## What the samples sustain

The million row is from qtc 1.2.0; the others were measured with qtc 1.1.1, and are bound by
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
- **Use the typed constructors and methods** (`qt::QObject()`, `label.setText(...)`) rather
  than `qt::new_object("QObject")` and `qt::call(...)` by name: they call qtc's direct entry
  points and skip the lookup by name.
- **Skip argument capture** for signals whose arguments you ignore: `qt::CONN_NO_ARGS`.
- **Use typed getters.** `slider.value_int()` is cheaper than going through the property
  system by name.
- **Build natively** for code that computes in Goose (the mandelbrot bands, the loopback
  checksum): the JIT is close for calls into Qt, but Goose's own loops run faster native.
