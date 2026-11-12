# goose-qt — Qt 6 for Goose

goose-qt binds [qtc](../qtc), the C library for Qt 6.12 LTS, to the Goose language: widgets,
Qt Quick and QML, painting, item models, networking, multimedia, Qt's GPU layer and the rest
of what qtc binds — about 11,000 functions generated from qtc's manifest — with qtc's
guarantee: misusing an object returns an error instead of crashing the program, within the
limits qtc's [LIMITS.md](../qtc/docs/LIMITS.md) spells out.

```goose
import qt from "path/to/goose-qt";

fn main() {
    qt::init();
    let win = qt::QWidget();
    let layout = qt::QVBoxLayout(win);
    let label = qt::QLabel("Not clicked yet");
    let button = qt::QPushButton("Click me");
    layout.addWidget(label);
    layout.addWidget(button);
    qt::connect(button, "clicked", 1);
    win.show();

    var clicks = 0;
    var ev = default<qt::Event>();
    while qt::wait(-1) == qt::WAIT_EVENTS {
        while qt::poll(ev) {
            if ev.tag == 1 {
                clicks++;
                label.setText(str("Clicked ", clicks, " times"));
            }
        }
    }
    qt::shutdown();
}
```

## What it can do

- **All of Qt's widgets, models and main-window machinery**, called as in C++ through Goose's
  method syntax: `label.setText("hi")`, `qt::QDateTime_currentDateTime()`, `qt::Qt.AlignCenter`.
- **Qt Quick and QML**, with a bridge that carries structured values both ways.
- **Subclassing Qt classes in Goose**: models, painted widgets, validators, delegates, and
  classes with signals, slots and properties made at run time.
- **Threads and futures**: Goose worker threads report through `qt::post` and fill promises.
- **GPU rendering and compute** through Qt's RHI on Vulkan, Metal, Direct3D or OpenGL, with
  every command checked.
- **Embedding**: a Goose-written Qt UI built as a shared library for a C or C++ program.
- **No crashes from misuse**: stale handles, wrong arguments, wrong threads and hundreds of
  inputs known to crash Qt are refused with an error code.

## Samples

[`samples/`](samples) has six larger programs that each push one part of goose-qt hard and
check the result. On a two-core cloud machine:

| Sample | Shows |
|---|---|
| [million](samples/million) | a model in Goose serving a million rows; filtering calls into Goose 1.4 million times a second |
| [notes](samples/notes) | a complete desktop app: menus, shortcuts, live Markdown preview, atomic JSON files |
| [loopback](samples/loopback) | an echo server and 16 clients: 780,000 TCP round trips a second on one thread |
| [scope](samples/scope) | four worker threads streaming 200,000 samples a second into a widget painted at 94 fps |
| [mandelbrot](samples/mandelbrot) | the same fractal from four CPU threads and a GPU compute shader, compared pixel by pixel |
| [chaos](samples/chaos) | a seeded storm of hostile calls: 36,000 a second, no crash, no leak |

```sh
samples/run.sh            # every sample's self-test, with the JIT and native
```

## Documentation

[**docs/**](docs/README.md) has the full guide: [getting started](docs/getting-started.md),
[concepts](docs/concepts.md), [calling Qt](docs/calling-qt.md), [values](docs/values.md),
[events](docs/events.md), [interfaces](docs/interfaces.md), [drawing](docs/drawing.md),
[QML](docs/qml.md), [subclassing](docs/subclassing.md), [threads](docs/threads.md),
[graphics](docs/graphics.md), [networking](docs/networking.md),
[embedding](docs/embedding.md), [testing](docs/testing.md),
[build and install](docs/build-and-install.md), [performance](docs/performance.md),
[stability](docs/stability.md), [troubleshooting](docs/troubleshooting.md) and
[internals](docs/internals.md), and [how it compares](docs/comparison.md) with C++, PyQt6, PySide6 and Go.

## Installing

You need a Goose from 8 November 2026 or later (commit `f4637bfb` was tested) and qtc, built
against Qt 6.12 LTS. The CMake project uses an installed qtc or builds it in the same step,
and installs the package so programs find qtc without a library path:

```sh
cmake -S goose-qt -B build -DQTC_SOURCE_DIR=path/to/qtc -DCMAKE_PREFIX_PATH=/opt/Qt/6.12.0/gcc_64
cmake --build build
ctest --test-dir build                  # tests, examples, samples, and a program run from the install
cmake --install build --prefix /usr/local
```

```goose
import qt from "/usr/local/share/goose-qt";
```

Installing by hand, from git, and the CMake options are in
[docs/build-and-install.md](docs/build-and-install.md).

## Examples and tests

`examples/` has short programs, one feature each: `hello`, `form`, `canvas`, `qml`, `threads`
(native only), `rhi`, and `shared/` (a Goose UI built as a shared library, with a C host).
Each runs interactively or checks itself with `--selftest`.

```sh
GOOSE=/path/to/goose QTC_LIB=/path/to/qtc/lib test/run.sh    # the suite, JIT and native
examples/run.sh                                              # every example's self-test
```

| Test | Covers |
|---|---|
| `t01_basics` | init, objects, calls, properties, values, enums, errors, stale handles |
| `t02_events` | signals, coalescing, watches, timers, posts, stale sources |
| `t03_widgets` | a form built from widgets, simulated input, a screenshot |
| `t04_drawing` | the canvas and image drawing calls |
| `t05_qml` | QML loading, the bridge both ways, QML properties and functions |
| `t06_threads` | workers posting from native threads |
| `t07_overrides` | a list model, a painted widget, a validator and key events written in Goose; a runtime class |
| `t08_futures` | futures filled by Goose worker threads: results, progress, failure, cancel, any/all, queued calls, a worker object (native only) |
| `t09_graphics` | the RHI: a pipeline checked against its shaders, a frame read back, compute, destruction order |
| `t90_wrappers` | every one of the 8,464 generated instance-method wrappers, called on a null receiver |

`test/bench.goose` measures what calls cost: about 50 ns for a generated wrapper call such
as `label.setText("hello")`, 20 ns for `slider.value_int()`, 10 ns for `c.red()` on a
`qt::Color` struct, 170–190 ns for a signal round trip, 70 ns for `qt::post` with its poll
([performance](docs/performance.md)).

## Compared with other bindings

[bench/compare](bench/compare) runs the same benchmark in C++, qtc's C, goose-qt, PyQt6,
PySide6, Go's miqt and Rust's cxx-qt. Per call, goose-qt is 2–5× faster than PyQt6 and
ahead of miqt (a `QColor` made and read: 18 ns, against 176 for miqt and 947 for PyQt6);
only cxx-qt, which calls Qt with no run-time checks at all, is closer to C++. Where Qt
calls back into the program (a model of a million rows), it is 2.2–4.7× faster than the
Python and Go bindings. It starts in 26 ms with 39 MiB (C++: 20 ms, 30 MiB). Of the
misuses tried, it is the only one that reports every one as an error instead of crashing
on some. Making and destroying an object (0.25 µs, which pays for ownership tracking) is
level with PyQt6 and behind Go. The numbers and charts are in
[docs/comparison.md](docs/comparison.md).

## Limits

Everything in [qtc's LIMITS.md](../qtc/docs/LIMITS.md) applies. goose-qt adds: the JIT runs
no threads; override handlers run for calls on the GUI thread only (other threads get Qt's
own implementation); qtc's thread-pool tasks, which take C function pointers, are not bound.
[docs/stability.md](docs/stability.md) has the details.

## License

MIT, see [LICENSE](LICENSE). Qt's own license terms apply to programs that use it; see
[docs/build-and-install.md](docs/build-and-install.md#licensing).
