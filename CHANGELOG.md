# Changelog

## 1.5.0 — 2026-11-12

For qtc 1.2.0, which CMake now requires. Needs a Goose from 8 November 2026 or later.

- **Faster calls.** The generated wrappers in `api.goose` call qtc's direct entry points
  (`qtc_direct.h`, one C function per bound signature) instead of pushing arguments and
  calling by name: 7,861 methods and 1,399 constructors. In `test/bench.goose`,
  `label.setText("hello")` went from 146 to 47 ns, `slider.value_int()` from 96 to 17 ns,
  `color.red()` from 101 to 18 ns, a property write from 288 to 107 ns and a signal round trip
  from 344 to 155 ns. Every check stays.
- **Cheaper objects, startup and memory (through qtc 1.2.0).** Making and destroying a
  `QObject` went from 1.6 µs to 0.2 µs. A program loads only the Qt modules it uses: a
  widgets program starts in 22 ms instead of 51 ms and peaks at 39 MiB instead of 65 MiB.
- `samples/million` filters its million rows through Goose at 1.8 million calls a second,
  up from 1.38 million.
- `bench/compare/` adds Rust through cxx-qt (KDAB's crate, 0.10), with the same benchmark and
  misuse probes, and the C implementation uses qtc's direct entry points. In the new run,
  goose-qt is 2–6× faster than PyQt6 per call and ahead of Go's miqt on every call but
  object creation; cxx-qt, with no run-time checks, is the closest to C++. goose-qt is still
  the only one that turns all three misuses into errors. `docs/comparison.md` has the results
  and the run against 1.4.0 next to them; `results/goose-qt-1.4.0/` keeps that run.

## 1.4.0 — 2026-11-11

For qtc 1.1.1, which CMake now requires. Needs a Goose from 8 November 2026 or later.

- **Fixed (in qtc 1.1.1):** on Wayland, every sample and example crashed when a window closed,
  and `notes` crashed when an open menu was dismissed by a click elsewhere. The crash was in
  qtc's event filter, which asked Qt's Wayland plugin for the paint device of a window that
  no longer had a platform window. qtc now has a test that runs on a headless weston.
- **Faster (through qtc 1.1.1):** in the comparison benchmark, `label.setText("hello")`
  went from 657 to 157 ns, `slider.value()` from 391 to 100 ns, a signal round trip from 747
  to 374 ns, and a `QColor` made, read and freed from 1,379 to 443 ns. The `million` sample
  filters its million rows through Goose at 1.38 million calls a second, up from 1.1 million.
  Every check stays.
- `bench/compare/`: the same benchmark in C++, qtc's C API, goose-qt (native and JIT),
  PyQt6, PySide6 and Go's miqt (eight calls, three whole tasks, startup and memory), and
  three misuses in each. `docs/comparison.md` reports the results. Per call, goose-qt is level
  with PyQt6 and ahead of PySide6, and it is 2.3–4.4× faster than any of them on a model
  written in the language. It is the only one that turned all three misuses into errors.
  Making and destroying objects, startup and memory are where it is behind.
- `samples/mandelbrot` shows its two images at half size, so the window fits on smaller
  screens. Every number in `samples/README.md` and `docs/` was measured again with qtc 1.1.1.

## 1.3.0 — 2026-11-11

For qtc 1.1.0. Needs a Goose from 8 November 2026 or later.

- `docs/`: a guide in 19 pages and an index — getting started, concepts (handles, ownership,
  errors, the GUI thread, the event loop), calling Qt, values, events, interfaces,
  drawing, QML, subclassing, threads and futures, graphics, networking, embedding,
  testing, build and install, performance, stability, troubleshooting and internals.
  Its claims were checked against a running build; the README is shorter and points
  there.
- `samples/`: six larger programs that showcase power, performance and stability, each
  with a `--selftest` that measures, checks its results and checks that nothing leaked:
  `million` (a Goose model serving a million rows through a sort/filter proxy),
  `notes` (a complete desktop app with menus, shortcuts, a live Markdown preview and
  atomic JSON files), `loopback` (a TCP echo server, 16 clients and a 64 MB stream),
  `scope` (four worker threads streaming into a widget painted in Goose), `mandelbrot`
  (CPU threads against a GPU compute shader, compared pixel by pixel) and `chaos` (a
  seeded storm of hostile calls). `samples/run.sh` runs them all with the JIT and
  native; screenshots and measured numbers are in `samples/README.md`.
- ctest runs the samples too (`goose_qt_samples`), and the install includes `docs/` and
  `samples/`.
- Documented precisely: `qt::last_error()` is the status of the most recent *failed*
  call and stays until the next failure or `qt::clear_error()`.

## 1.2.0 — 2026-11-11

For qtc 1.1.0. Needs a Goose from 8 November 2026 or later.

- A CMake build and install: it uses an installed qtc (`find_package(qtc)`) or
  builds qtc from its source in the same build (`QTC_SOURCE_DIR`), installs the
  package under `share/goose-qt` with qtc's installed path written into
  `qt.build` (programs need no library path), and registers the tests, the
  examples and a check of the installed package with ctest. `uninstall` and
  `goose_qt_api` (regenerate `api.goose`) targets. Configuring checks that the
  Goose found is new enough.
- CI builds and tests through it.

## 1.1.1 — 2026-11-11

For qtc 1.1.0. Needs a Goose from 8 November 2026 or later.

- `obj.prop<T>("name")` reads a property as `i64`, `f64`, `bool`, `qt::Obj`,
  `qt::Val` or a string, and `qt::ret<T>()` the result of a call, with the type
  picked when the function is specialized (Goose's new `const if` and type
  arguments in method calls). `get_int`, `get_str` and the rest stay.
- `examples/shared/`: a Qt window written in Goose, built as a shared library
  with `goose build --shared` and driven from a C program; `examples/run.sh`
  builds and runs it.
- Shader sources in `examples/rhi.goose` and `t09_graphics` are multi-line raw
  strings instead of one line of `\n` escapes.
- CI checks out the Goose commit this release was tested with.

## 1.1.0 — 2026-11-11

For qtc 1.1.0.

- `extra.goose`: overridable objects through one exported handler
  (`goose_qt_override`, called through the C trampoline in
  `include/goose_qt.h`), runtime-defined classes, futures and promises for Goose
  worker threads, queued calls and worker objects, and the graphics API (Qt's
  RHI as `qt::Gpu` handles, Qt Quick's graphics API, native interop).
- `api.goose` regenerated: 9,512 method functions, 1,481 constructors, 9,148
  enum values in 405 scopes (QRhiWidget among the new classes).
- Return types of generated functions no longer change when newly bound classes
  disagree: the generator keeps the type the published `api.goose` had and reaches
  the other classes' results through the typed variants. Without this, six
  functions would have changed to `qt::Val` (`name`, `host`, `query`, `message`,
  `filter`, `scope`); `QCoapOption`'s `name()` is `name_int()`.
- Tests `t07_overrides`, `t08_futures` (native) and `t09_graphics`.

## 1.0.0 — 2026-11-10

The first release, for qtc 1.0.0 on Qt 6.12 LTS.

- `api.goose`, generated from qtc's manifest: 9,081 method functions (UFCS on
  `qt::Obj` and `qt::Val`), 1,399 constructors, 8,855 enum values in 388 scopes
  (`qt::Qt.AlignLeft`).
- `qt.goose`: init and shutdown, the event loop, signals, watches, timers,
  posts, values, lists and maps, the generic call, drawing, test input.
- Tests run with the JIT and natively; examples that test themselves.
