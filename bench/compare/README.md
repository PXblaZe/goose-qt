# Comparison benchmark

The same benchmark written against eight ways of using Qt 6.12 from a program, to put qtc's
and goose-qt's costs next to the alternatives. The findings are in
[docs/comparison.md](../../docs/comparison.md); this directory is how to reproduce them.

| Directory | Implementation |
|---|---|
| `cpp/` | C++ calling Qt directly: the baseline |
| `c/` | C through qtc's direct entry points (`qtc_direct.h`) |
| `goose/` | Goose through goose-qt (run as a native build and with the JIT) |
| `python/` | Python through PySide6 (Qt's own binding) or PyQt6 (Riverbank's), one script for both |
| `go/` | Go through miqt, a binding generated from Qt's headers through cgo |
| `rust/` | Rust through cxx-qt (KDAB), the most used Qt 6 crate: Qt's classes declared in a `cxx` bridge, the model a `#[qobject]` with `QAbstractTableModel` as its base |

Each program does the same things with the same counts, and prints
`RESULT <name> <value> <unit>` lines:

| Name | What | Count |
|---|---|---|
| `set_text` | `label.setText("hello")` (the same text: Qt returns early, so this is the binding's cost) | 200,000 |
| `get_text` | `label.text()`, the string brought into the language | 200,000 |
| `set_value` | `slider.setValue(i)` | 200,000 |
| `get_value` | `slider.value()` | 200,000 |
| `set_property` | `label.setProperty("text", "hello")` through the property system | 200,000 |
| `signal` | `button.click()` reaching the language's handler | 100,000 |
| `value_type` | make a `QColor(255, 0, 0)`, read `red()`, free it (goose-qt and C: as a struct, nothing to free) | 200,000 |
| `object_churn` | make a `QObject` and delete it | 50,000 |
| `model_filter` | a `QAbstractTableModel` written in the language, 1,000,000 rows, filtered for "4242" by a `QSortFilterProxyModel` (a call into the language per row; 299 match) | once |
| `paint_lines` | 100,000 short lines painted into a 1024 × 1024 `QImage` | once |
| `widgets` | 2,000 `QPushButton`s in a `QGridLayout`: create, show, paint once, destroy | once |
| startup | `--startup`: start Qt, show a label, paint it once, exit; timed from outside, with peak memory | 15 runs |

Everything runs on Qt's offscreen platform. Each implementation warms up `set_text` first.

## Running it

```sh
python3 -m venv venv && venv/bin/pip install PySide6-Essentials==6.12.0 PyQt6==6.12.0 PyQt6-Qt6==6.12.0
QT_PREFIX=/opt/qt612 QTC_LIB=/path/to/qtc/lib QTC_INCLUDE=/path/to/qtc/include \
GOOSE=/path/to/goose PYTHON=venv/bin/python python3 run.py --rounds 5
python3 report.py              # results/results.md, results/calls.png, results/workloads.png
```

The Rust implementation needs cargo (`CARGO`); its first build fetches cxx-qt 0.10 from
crates.io and builds it against `QT_PREFIX`'s `qmake6`, which takes a few minutes. Without
cargo, `run.py` leaves it out.

The Go implementation needs miqt in the module cache (`cd go && go mod download`). Building
miqt's Qt 6 package compiles its whole C++ binding once, which takes a long time and a lot of
memory: `run.py` builds with `go build -p 1 -gcflags=github.com/mappu/miqt/qt6=-c=1` and
`GOGC=50`, and on a 7 GB machine it still needed swap. Go caches the build by its flags, so
build anything else against miqt with the same flags or it compiles again. Without Go,
`run.py` leaves it out.

`run.py --only NAME` runs one implementation and `--merge` adds its results to the existing
ones. `results/before-fix/` holds the run against qtc 1.1.0, before the call path was made
faster, and `results/goose-qt-1.4.0/` to `goose-qt-1.6.1/` the runs against qtc 1.1.1,
1.2.0, 1.3.0 and 1.4.0, for comparison.

## Misuse

`misuse/` runs three mistakes in C++, goose-qt, Python (both bindings), Go and Rust, each in
its own process, and records whether the program got an error or crashed:

| Probe | The mistake |
|---|---|
| `deleted` | call a method on a label whose parent was already deleted |
| `range` | pass a value out of range for the argument (`QSpinBox.setValue(10000000000)`, past `int`) |
| `qtbug` | a call Qt itself does not guard: `combo.setView(combo.view())`, then open the popup |

```sh
python3 misuse/run.py          # results/misuse.txt
```

## What is fair and what is not

- **Same Qt version, two Qt builds.** The compiled implementations use the Qt in
  `QT_PREFIX` (here conda-forge's 6.12.0 build); the Python wheels bring Qt's official 6.12.0
  build. The C++ program is run on both (`C++ (direct), wheel Qt`) so the difference between
  the two Qt builds can be read off directly.
- **Signals differ by design.** C++, Python and Go connect a function that Qt calls inside
  the emission. qtc and goose-qt never call into the program from a signal: the emission is
  queued and the program polls it, so `signal` there includes the queue round trip.
- **Deletion.** `qtc_destroy` / `qt::destroy` invalidate the handle and delete the object at
  once (in the event loop only when events are still queued for it); the timing includes an
  event-loop pass at the end all the same.
- **Rust's misuse probes need `unsafe`.** cxx-qt hands out raw pointers for objects Qt owns
  (a child, `combo.view()`); using one after its owner deleted it, or giving it to another
  owner, has to be written in an `unsafe` block. The `range` probe is an `as i32` cast, which
  Rust makes the program write.
- **The checks are the point.** Every qtc call checks the receiver handle (alive, right
  thread, right class), each argument and the preconditions of the method, and converts the
  result; the others call Qt directly (C++, Go, Rust) or through generated wrappers with type
  checks (Python). See
  [docs/stability.md](../../docs/stability.md) for what those checks buy.
- One machine, small numbers: the medians are stable to a few percent between runs (the
  spread table in `results/results.md` shows the range), but another CPU will give other
  numbers. The ratios are what transfers.
