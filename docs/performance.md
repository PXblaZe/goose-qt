# Performance

Every Qt call from Goose goes through qtc: arguments are pushed, the method is looked up
(cached per class and name), the arguments are checked, the call is made, and the result is
converted back. That costs a fraction of a microsecond per call, on top of what Qt itself
spends. For a user interface that is invisible; for hot loops it is worth knowing where the
time goes.

All numbers here are from one machine: two cores of a 2.1 GHz Xeon, 7 GB of memory, Linux,
Qt 6.12.0, qtc 1.1.0. Yours will differ; run the benchmarks to see.

## What a call costs

`test/bench.goose` (nanoseconds per operation):

| Operation | Native | JIT |
|---|---:|---:|
| `label.setText("hello")` (a generated wrapper) | 623 | 648 |
| `qt::set(label, "text", …)` (the property system) | 889 | 987 |
| `slider.setValue(i)` | 602 | 1,031 |
| `slider.value_int()` | 400 | 443 |
| `label.text()` (a string back) | 484 | 480 |
| `qt::val(i)` and free | 78 | 96 |
| `color.red()` (a method on a value) | 361 | 383 |
| `button.click()` and `qt::poll` (a signal round trip) | 730 | 753 |
| `qt::post` and `qt::poll` | 69 | 105 |
| `qt::alive(handle)` | 13 | 22 |
| a call on a stale handle (refused) | 394 | 446 |

```sh
goose build test/bench.goose -o bench && ./bench
```

qtc's own C benchmark puts `QLabel::setText` at 239 ns from C, against 5 ns in C++ directly
(see [qtc's testing notes](../../qtc/docs/TESTING.md#results)): that is the price of looking
the method up and checking the call. The rest is the crossing from Goose into the library
and converting strings. The JIT and native builds are close, because the time is spent
outside Goose.

## What the samples sustain

| Sample | Sustained |
|---|---|
| [million](../samples/million/million.goose) | a model in Goose answering 1.1 million `data()` calls a second while `QSortFilterProxyModel` filters a million rows; 385 pages scrolled and painted a second |
| [loopback](../samples/loopback/loopback.goose) | 616,000 TCP round trips a second between 16 clients and a server on one thread; a 64 MB stream at 277 MB/s, checksummed in Goose |
| [scope](../samples/scope/scope.goose) | 82 frames a second of four 1,024-point polylines painted in Goose, fed by 200,000 samples a second from four threads, none dropped |
| [mandelbrot](../samples/mandelbrot/mandelbrot.goose) | a 1024 × 768 fractal in 82 ms from four Goose threads on two cores |
| [notes](../samples/notes/notes.goose) | 2,000 notes made in 14 ms, searched in 8 ms, saved as 326 KB of JSON in 6 ms and loaded in 21 ms |
| [chaos](../samples/chaos/chaos.goose) | 33,700 random API operations a second, most of them refused |

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
- **Keep values you reuse.** Making and freeing a value costs about 80 ns; a `QColor` or
  `QFont` used every frame can be made once.
- **Skip argument capture** for signals whose arguments you ignore: `qt::CONN_NO_ARGS`.
- **Use typed getters.** `slider.value_int()` is cheaper than going through the property
  system by name.
- **Build natively** for code that computes in Goose (the mandelbrot bands, the loopback
  checksum): the JIT is close for calls into Qt, but Goose's own loops run faster native.
