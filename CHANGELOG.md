# Changelog

## Unreleased

### Platforms
- macOS and Windows. `include/goose_qt.h` declares the override and signal handlers in a
  way MSVC links (it has no weak symbols); the test, example and sample scripts find qtc
  on Windows (through `PATH`) and run on macOS (which has no `timeout` command or bash 5);
  ctest runs them with Git's bash on Windows. CI builds and tests on macOS and Windows as
  well as Linux, allowed to fail there for now. The `shared/` example runs on Linux only.
- The scope sample's workers keep to 51,200 samples a second by the clock rather than by
  sleeping between blocks, which ran them at a fifth of that rate on macOS.

### Documentation
- Links to qtc's documentation point at https://github.com/PXblaZe/qtc; they assumed the two
  repositories side by side on disk, which left them broken on GitHub.
- Overrides and direct signal handlers on a current Goose: Goose from 24 November 2026
  refuses the callbacks they rely on, and stops the program at the first one. The README
  and [docs/subclassing.md](docs/subclassing.md#which-goose-runs-them) say which Goose runs
  them and link the proposal that would make them safe
  ([aardappel/goose#423](https://github.com/aardappel/goose/issues/423)).

## 1.0.0 — 2026-11-12

The first release: Qt 6.12 LTS for the Goose language, through qtc 1.0.0.

### What it binds
- Qt's classes as Goose functions generated from qtc's manifest: a constructor per class,
  a function per method name and parameter shape, statics and enums, called with Goose's
  method syntax (`label.setText("hi")`). `import qt from "...";` brings Qt Core, Gui and
  Widgets; every other Qt module is imported when used (`import qt.network;`,
  `import qt.qml;`, `import qt.all;`), so a program compiles only what it uses.
- Small values as structs with Qt's layout (`qt::color`, `qt::rect`, ...), other values
  as `qt::Val` handles.
- Signals queued and polled (`qt::connect`, `qt::poll`), or run inside the emission
  (`qt::CONN_DIRECT` with an exported `goose_qt_signal`).
- Qt Quick and QML with a bridge for structured values; subclassing Qt classes in Goose
  (models, painted widgets, validators, delegates); classes with signals, slots and
  properties made at run time; worker threads and futures; GPU rendering and compute
  through Qt's RHI; a Goose UI built as a shared library for a C or C++ program.
- Six samples that each push one part hard and check the result, and a guide in `docs/`.

### Safety
- Every call goes through qtc's checks: stale and forged handles, wrong argument types and
  ranges, the wrong thread, and nearly 400 inputs known to crash Qt are errors the program
  can check (`qt::last_error()`), log or abort on (`qt::set_error_policy`).
- In `bench/compare/misuse`, ten common mistakes made in six bindings: goose-qt catches all
  ten; PyQt6 and PySide6 five, Rust three at compile time, Go and C++ none.

### Speed
- `bench/compare` runs the same benchmark in C++, qtc, goose-qt, PyQt6, PySide6, Go's miqt
  and Rust's cxx-qt: goose-qt is ahead of miqt on every method call, 2–6× faster than
  PyQt6, level with miqt on making and destroying objects, and 2.4–4.9× faster than the
  Python and Go bindings where Qt calls back into the program. A native program starts in
  24 ms with 39 MiB; the JIT starts a widgets program in about 0.43 s.

### Tested
- 11 tests, each with the JIT and as a native build, among them a call of each of the 8,461
  generated wrappers with a null receiver; 12 examples; the samples, including a seeded
  storm of hostile calls (a million operations, no crash, no leak).

### Known issue
- In the current Goose compiler, an override or direct-signal handler that allocates
  (`str(...)`, a growable array) can overwrite strings and arrays of the Goose code that
  called into Qt. The bug is in Goose, and a fix has been sent to the Goose project. Until
  then, handlers can keep to fixed-size values, as the million sample does:
  [docs/subclassing.md](docs/subclassing.md#which-goose-runs-them).
