# How goose-qt compares

The same benchmark was written seven ways and run on one machine. The ways are C++ calling Qt
directly, qtc from C, goose-qt (native and JIT), PyQt6, PySide6, and Go's
[miqt](https://github.com/mappu/miqt). All use Qt 6.12. The benchmark's source, and how to
rerun it, are in [bench/compare](../bench/compare); the raw numbers are in
[results.md](../bench/compare/results/results.md).

**In short:**
- **Per call**, goose-qt is now level with PyQt6, the fastest Python binding, and well ahead
  of PySide6. A plain call costs 100–160 ns. Go's miqt is faster on integer getters and
  setters, value types and signals, and slower on strings and properties.
- **Where Qt calls back into your code**, goose-qt is 2.3–4.4× faster than the others: a
  model written in Goose, a painted widget.
- **Whole tasks Qt does the work of** run at about C++ speed: painting, laying out 2,000
  widgets.
- **It is slower in three places.** Creating and destroying objects costs about 1.6 µs, against
  0.2–0.3 µs for PyQt6 and Go. Startup takes 51 ms, against 18–22 ms for C++ and Go. Memory
  at startup is 65 MiB, against 29–56 MiB.
- **It is the only one where all three misuse probes come back as errors.** The others
  crash, hang or silently do the wrong thing on at least one.

Machine: two cores of a 2.1 GHz Xeon, 7 GB, Linux. Medians of five runs, each in its own
process; startup over 15 runs. Qt 6.12.0 everywhere: conda-forge's build for the compiled
programs, and Qt's own build inside the Python wheels. The C++ program ran on both, and the
two Qt builds are within a few percent of each other except for painting.

## Calls

![What one call costs](../bench/compare/results/calls.png)

| ns per call | C++ | qtc (C) | **goose-qt** | PyQt6 | PySide6 | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|
| `label.setText("hello")` | 5 | 164 | **157** | 169 | 270 | 241 |
| `label.text()` | 3 | 135 | **151** | 154 | 274 | 185 |
| `slider.setValue(i)` | 30 | 159 | **158** | 166 | 285 | 93 |
| `slider.value()` | 2 | 104 | **100** | 118 | 227 | 67 |
| `setProperty("text", …)` | 69 | 306 | **297** | 542 | 597 | 617 |
| `button.click()` reaching a handler | 103 | 383 | **374** | 836 | 418 | 306 |
| `QColor(255, 0, 0).red()` | 3 | 433 | **443** | 986 | 613 | 190 |
| a `QObject` made and deleted | 44 | 1,667 | **1,577** | 260 | 2,396 | 172 |

goose-qt is the native build; the JIT adds 3–22%. C++ is the floor: a binding cannot beat a
direct call, and every binding here pays 20–100× it for a simple getter.

Notes on the rows:
- **Calls.** goose-qt and PyQt6 lead `setText`, `text()` and property writes. Go's miqt,
  generated straight from Qt's headers, is fastest for integer getters and setters.
- **Signals.** C++, Python and Go run a function inside the emission. goose-qt queues the
  emission and the program polls it, which lets a handler destroy the sender safely. Even
  so, the round trip costs less than either Python binding.
- **Value types.** Each goose-qt value is a handle in qtc's registry, checked on every use.
  Go keeps a raw pointer, which is faster and unchecked.
- **Objects made and destroyed.** This is goose-qt's weakest row. Every object gets a handle,
  a watch on its destruction, and a check of which objects hold it and whether Qt owns it.
  That bookkeeping is what turns "use after delete" into an error instead of a crash (see
  below). It matters only for programs that make tens of thousands of objects a second.

## Whole tasks

![Whole tasks](../bench/compare/results/workloads.png)

| | C++ | qtc (C) | **goose-qt** | PyQt6 | PySide6 | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|
| filter 1,000,000 rows of a model written in the language | 288 ms | 720 ms | **683 ms** | 2,518 ms | 2,975 ms | 1,552 ms |
| paint 100,000 lines into an image | 30 ms | 35 ms | **38 ms** | 69 ms | 52 ms | 35 ms |
| 2,000 buttons: create, show, paint, destroy | 59 ms | 56 ms | **57 ms** | 80 ms | 133 ms | 61 ms |
| startup to exit (a label shown and painted) | 18 ms | 44 ms | **51 ms** | 70 ms | 141 ms | 22 ms |
| peak memory of that program | 29 MiB | 65 MiB | **65 MiB** | 48 MiB | 56 MiB | 36 MiB |

The model filter calls into the language once per row: Qt asks the model for each row's
text. goose-qt answers a million of those calls in 683 ms. That is 2.3× faster than Go, 3.7×
faster than PyQt6 and 4.4× faster than PySide6, and within 2.4× of a model written in C++.
That speed is what lets the [million sample](../samples/million/million.goose) serve a
million rows from Goose.

Startup and memory are the cost of qtc's tables: about 13,600 bound methods and signals of
658 classes, loaded when the program starts. The JIT also compiles `api.goose`'s 11,000 functions at
start, which takes about half a second (541 ms startup, 240 MiB); native builds do that
ahead of time.

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

The Python bindings track deleted wrappers and check integer ranges. Neither they nor any of
the others protect against inputs that crash Qt itself. qtc refuses nearly 400 such
inputs, each found by fuzzing, see [Stability](stability.md). Those checks are part of the
per-call cost above: the call path still does all of them.

## What changed to get here

The first run of this comparison, with qtc 1.1.0, had goose-qt behind PyQt6 on every call.
Profiling qtc under callgrind showed most of the cost was bookkeeping that could be cached,
not the checks. qtc 1.1.1 changed that without dropping a check; its
[changelog](../../qtc/CHANGELOG.md) lists what changed.

| goose-qt, native | qtc 1.1.0 | qtc 1.1.1 | |
|---|---:|---:|---:|
| `label.setText("hello")` | 657 ns | 157 ns | 4.2× |
| `label.text()` | 432 ns | 151 ns | 2.9× |
| `slider.setValue(i)` | 613 ns | 158 ns | 3.9× |
| `slider.value()` | 391 ns | 100 ns | 3.9× |
| `setProperty("text", …)` | 902 ns | 297 ns | 3.0× |
| signal round trip | 747 ns | 374 ns | 2.0× |
| `QColor(255, 0, 0).red()` | 1,379 ns | 443 ns | 3.1× |
| a `QObject` made and deleted | 2,431 ns | 1,577 ns | 1.5× |
| million-row model filter | 862 ms | 683 ms | 1.3× |

The release went through the same validation as 1.1.0. Its 19 test suites pass in release
and AddressSanitizer builds, and the method fuzzer ran clean on the new call path: the fixed
order, by name, object lifetimes and 16 random orders in the release build, plus fixed, by
name, lifetimes and 3 random orders under AddressSanitizer. One random order hit the known
OpenSSL crash at exit, which [LIMITS.md](../../qtc/docs/LIMITS.md) describes.

## Caveats

- One machine and one Qt version. The ratios carry over better than the absolute numbers.
- Each row measures one operation in a tight loop. Real programs spend most of their time
  in Qt (layout, painting, text), where every binding costs the same.
- PyQt6 and PySide6 run on Qt's official build. The other programs run on conda-forge's
  build. The C++ row on both builds shows the difference: noise, except painting, where the
  official build is faster.
- miqt is version 0.15.0. Building its Qt 6 package took 21 minutes and more than 7 GB of
  memory (it was built with swap and the Go compiler's parallelism off).
