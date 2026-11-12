# How goose-qt compares

The same benchmark was written eight ways and run on one machine: C++ calling Qt directly,
qtc from C, goose-qt (native and JIT), PyQt6, PySide6, Go's
[miqt](https://github.com/mappu/miqt) and Rust's [cxx-qt](https://github.com/KDAB/cxx-qt).
All use Qt 6.12. The benchmark's source, and how to rerun it, are in
[bench/compare](../bench/compare); the raw numbers are in
[results.md](../bench/compare/results/results.md).

**In short:**
- **Per call, goose-qt is 2–5× faster than PyQt6** and 2–10× faster than PySide6, and
  ahead of Go's miqt on every call but object creation: level on signals, up to 3.5× on
  properties. A plain call costs 20–67 ns, where C++ pays 1–29 ns.
- **Small values are structs.** `qt::color(255, 0, 0).red()` takes 18 ns: 50× faster than
  PyQt6, 9× faster than Go, within 2× of Rust. Points, sizes, rectangles, lines, margins and
  colors need no handle (since goose-qt 1.6.0, qtc 1.3.0).
- **Rust's cxx-qt is the closest to C++.** It calls Qt through `cxx` bridges with nothing in
  between: 1–7× a direct C++ call, and a fraction of goose-qt's cost. It checks nothing at
  run time. Its misuse probes need `unsafe`, and all three crashed or silently truncated.
- **Where Qt calls back into your code** (a model written in the language), goose-qt is
  2.3× faster than Go and 3.8× faster than PyQt6, within 2.2× of C++.
- **Startup and memory are near C++.** Startup takes 28 ms, against 22 ms for C++, Rust and
  Go and 75 ms for PyQt6. Peak memory is 39 MiB, against 29–30 MiB for C++ and Rust,
  43 MiB for Go and 48 MiB for PyQt6.
- **Making and destroying a `QObject` takes 178 ns:** faster than PyQt6 (223 ns), behind Go
  (139 ns). That is a handle, its ownership tracking and the checks that turn "use after
  delete" into an error. qtc 1.4.0 cut it from 245 ns in the previous run.
- **It is the only one where all three misuse probes come back as errors.** The others
  crash, hang or silently do the wrong thing on at least one.

Machine: two cores of a Xeon VM (2.1 GHz nominal; not the machine of the earlier runs, so
compare numbers within a table), 7 GB, Linux. Medians of five runs, each in its own
process; startup over 15 runs. Qt 6.12.0 everywhere: conda-forge's build for the compiled
programs, and Qt's own build inside the Python wheels. The C++ program ran on both, and the
two Qt builds are within a few percent of each other except for painting.

## Calls

![What one call costs](../bench/compare/results/calls.png)

| ns per call | C++ | Rust (cxx-qt) | qtc (C) | **goose-qt** | PyQt6 | PySide6 | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|
| `label.setText("hello")` | 5.5 | 34 | 58 | **58** | 143 | 265 | 198 |
| `label.text()` | 2.1 | 15 | 66 | **67** | 130 | 266 | 157 |
| `slider.setValue(i)` | 29 | 31 | 55 | **54** | 139 | 255 | 74 |
| `slider.value()` | 0.7 | 3.5 | 21 | **20** | 96 | 194 | 51 |
| `setProperty("text", …)` | 53 | 71 | 131 | **135** | 418 | 589 | 478 |
| `button.click()` reaching a handler | 96 | 99 | 215 | **213** | 607 | 426 | 209 |
| `QColor(255, 0, 0).red()` | 1.7 | 9.9 | 18 | **18** | 902 | 586 | 167 |
| a `QObject` made and deleted | 41 | 43 | 178 | **178** | 223 | 2,003 | 139 |

goose-qt is the native build; the JIT adds 3–58% (more on the 18 ns color row). C++ is the floor: a binding cannot beat a
direct call.

Notes on the rows:
- **Calls.** goose-qt calls qtc's direct entry points: one C function per bound signature
  (`qtcm_setText__QString`), resolved once per class and then a jump to the thunk, with
  every check still made. Goose's typed wrappers compile to a direct call to them.
- **Rust.** cxx-qt declares each Qt method in a `cxx` bridge and calls it through a C++
  shim: nothing is looked up or checked at run time, so it pays only for the shim and string
  conversion. It is the fastest binding on every call row.
- **Signals.** C++, Python, Go and Rust run a function inside the emission. goose-qt queues
  the emission and the program polls it, which lets a handler destroy the sender safely.
  Even so, the round trip costs less than either Python binding or Go.
- **Value types.** goose-qt makes the color as a `qt::Color` struct with `QColor`'s own
  layout (`values.goose`, qtc's `qtc_inline.h`): no handle, a direct call into Qt, and still
  a check that the struct holds a valid color. Go keeps a raw pointer to a heap `QColor`,
  Rust a C++ value on its stack. Values without a struct form (`QFont`, `QImage`, ...) are
  handles in qtc's registry, as before.
- **Objects made and destroyed.** Every object gets a handle and its ownership is tracked:
  which objects hold it, whether Qt owns it, whether it is the internal part of another.
  That bookkeeping turns "use after delete" into an error instead of a crash (see below).
  qtc 1.2.0 cut it from 1.6 µs to 0.2 µs by making objects as a subclass whose destructor
  releases the handle (sip's technique) and by deleting at once. qtc 1.4.0 skips the
  cleanups an object has nothing for: each handle's slot records whether the event layer
  or the ownership tracking keeps anything for its object, and most objects have neither.
  It also takes one lock fewer per object. That is 17% fewer instructions per object, and
  sanitizer builds check each skipped cleanup at run time.

## Whole tasks

![Whole tasks](../bench/compare/results/workloads.png)

| | C++ | Rust (cxx-qt) | qtc (C) | **goose-qt** | PyQt6 | PySide6 | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|
| filter 1,000,000 rows of a model written in the language | 260 ms | 254 ms | 588 ms | **553 ms** | 2,113 ms | 2,455 ms | 1,270 ms |
| paint 100,000 lines into an image | 27 ms | 25 ms | 31 ms | **33 ms** | 67 ms | 45 ms | 35 ms |
| 2,000 buttons: create, show, paint, destroy | 63 ms | 55 ms | 43 ms | **45 ms** | 79 ms | 114 ms | 61 ms |
| startup to exit (a label shown and painted) | 22 ms | 22 ms | 29 ms | **28 ms** | 75 ms | 152 ms | 21 ms |
| peak memory of that program | 29 MiB | 30 MiB | 39 MiB | **39 MiB** | 48 MiB | 56 MiB | 43 MiB |

The model filter calls into the language once per row: Qt asks the model for each row's
text. goose-qt answers a million of those calls in 553 ms. That is 2.3× faster than Go,
3.8× faster than PyQt6 and 4.4× faster than PySide6. A model in C++ or Rust, which Qt calls
as a virtual function, takes 0.25 s.

Startup and memory used to be the cost of loading all of qtc at once: 25 Qt modules and the
tables of 13,600 methods. Since qtc 1.2.0, `libqtc` holds Qt Core, Gui and Widgets, and each
other module is a library of its own, loaded when the program first uses one of its classes.
A widgets program maps 4 Qt libraries instead of about 30. The JIT still compiles
`api.goose` at start, which takes over half a second (646 ms, 241 MiB here): nearly all of it
is the Goose compiler checking every function of `api.goose`, also those the program never
calls. Native builds do that ahead of time.

## Misuse

Three mistakes, each made once in each binding ([bench/compare/misuse](../bench/compare/misuse); output in
[misuse.txt](../bench/compare/results/misuse.txt)):

| | a child used after its parent was deleted | an `int` argument of 10,000,000,000 | a call Qt itself crashes on: `combo.setView(combo.view())` |
|---|---|---|---|
| C++ | segfault | silently truncated | segfault |
| **goose-qt** | **error: `QTC_ERR_STALE_HANDLE`** | **error: `QTC_ERR_OUT_OF_RANGE`** | **error: `QTC_ERR_STATE`, refused** |
| PyQt6 | exception (`RuntimeError`) | exception (`OverflowError`) | segfault |
| PySide6 | exception (`RuntimeError`) | exception (`OverflowError`) | segfault (in another run, a hang) |
| Go (miqt) | segfault (`SIGSEGV` in cgo) | silently truncated | segfault |
| Rust (cxx-qt) | segfault (in an `unsafe` block) | silently truncated (an `as i32` cast) | segfault (in an `unsafe` block) |

The Python bindings track deleted wrappers and check integer ranges. Rust makes the program
spell out the dangerous parts: a raw pointer to an object Qt owns can only be used in
`unsafe`, and the 64-bit value has to be cast. None of them protects against inputs that
crash Qt itself. qtc refuses nearly 400 such inputs, each found by fuzzing, see
[Stability](stability.md). Those checks are part of the per-call cost above: the call path
still does all of them.

## What changed to get here

The first run of this comparison, with qtc 1.1.0, had goose-qt behind PyQt6 on every call.
qtc 1.1.1 cached what could be cached. qtc 1.2.0 added three things, without dropping a
check ([changelog](../../qtc/CHANGELOG.md)): a C function per bound signature, called
directly by goose-qt's wrappers; objects made as a subclass that tells qtc when it dies;
and a library per Qt module, loaded on first use. qtc 1.3.0 added small values as structs
and made the handle registry cheaper. qtc 1.4.0 made objects cheaper to make and destroy.

The machine changed between runs, so this table gives each goose-qt number as a multiple
of PyQt6's speed in the same run:

| goose-qt, native, × PyQt6's speed | 1.4.0 (qtc 1.1.1) | 1.5.0 (qtc 1.2.0) | 1.6.0 (qtc 1.3.0) | 1.6.1 (qtc 1.4.0) |
|---|---:|---:|---:|---:|
| `label.setText("hello")` | 1.1× | 3.2× | 3.4× | 2.5× |
| `label.text()` | 1.0× | 2.1× | 2.3× | 1.9× |
| `slider.setValue(i)` | 1.1× | 3.1× | 2.9× | 2.6× |
| `slider.value()` | 1.2× | 5.5× | 5.3× | 4.7× |
| `setProperty("text", …)` | 1.8× | 3.6× | 3.6× | 3.1× |
| signal round trip | 2.2× | 3.3× | 3.4× | 2.8× |
| `QColor(255, 0, 0).red()` | 2.2× | 5.7× | 51× | 50× |
| a `QObject` made and deleted | 0.16× | 0.94× | 0.97× | 1.25× |
| million-row model filter | 3.7× | 3.7× | 3.9× | 3.8× |
| startup | 1.4× | 3.0× | 2.9× | 2.6× |
| peak memory (PyQt6's ÷ goose-qt's) | 0.74× | 1.25× | 1.25× | 1.24× |

qtc 1.4.0 changed nothing on the call path. goose-qt's per-call times are about what they
were in 1.6.0's run (58, 67, 54, 20 and 135 ns against 58, 66, 55, 20 and 130); PyQt6
measured faster on this machine, so those ratios dropped.

qtc 1.4.0 passes its 19 test suites in release and AddressSanitizer + UndefinedBehaviorSanitizer
builds; the sanitizer build also checks, at every destruction that skipped a cleanup, that
there was nothing to clean up. The method fuzzer ran on it under the sanitizers: the fixed
order, by name, object lifetimes and two random orders, clean but for OpenSSL's known
double free at exit in one order (Qt's, see qtc's LIMITS.md). goose-qt's 20 tests and 12
examples pass against it.

## Caveats

- One machine and one Qt version. The ratios carry over better than the absolute numbers.
- Each row measures one operation in a tight loop. Real programs spend most of their time
  in Qt (layout, painting, text), where every binding costs the same.
- PyQt6 and PySide6 run on Qt's official build. The other programs run on conda-forge's
  build. The C++ row on both builds shows the difference: noise, except painting, where the
  official build is faster.
- miqt is version 0.15.0. Building its Qt 6 package took 21 minutes and more than 7 GB of
  memory (it was built with swap and the Go compiler's parallelism off).
- cxx-qt is version 0.10 with cxx-qt-lib's `qt_gui` feature. Widgets have no bindings in
  cxx-qt-lib, so the Rust program declares the `QWidget` classes it uses in its own `cxx`
  bridge (with a few lines of C++ for constructors), as a cxx-qt widgets program would.
