# Changelog

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
