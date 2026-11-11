# Getting started

## What you need

- **Goose** from 8 November 2026 or later (commit `f4637bfb` was tested). goose-qt uses
  `const if` and type arguments in method calls, which older compilers lack; the CMake
  project checks this when it configures.
- **Qt 6.12 LTS**, and **qtc** built against it. qtc is the C library goose-qt loads at run
  time; goose-qt itself is Goose source and needs no building.
- For native builds, the C compiler Goose uses (it is also what compiles the small C header
  override handlers go through).

## Install

The short way, building qtc in the same step (`../qtc` is found on its own when it sits next
to goose-qt):

```sh
cmake -S goose-qt -B build -DQTC_SOURCE_DIR=path/to/qtc -DCMAKE_PREFIX_PATH=/opt/Qt/6.12.0/gcc_64
cmake --build build
cmake --install build --prefix /usr/local
```

The installed package knows where its qtc is, so programs need no library path. Other ways
(an installed qtc, by hand, from git) are in [Build and install](build-and-install.md).

## A first window

```goose
import qt from "/usr/local/share/goose-qt";

let T_CLICKED: u64 = 1;

fn main() {
    if !qt::init() { print("Qt did not start: ", qt::last_error_message()); exit(1); }
    let win = qt::QWidget();
    win.setWindowTitle("Hello");
    let layout = qt::QVBoxLayout(win);
    let label = qt::QLabel("Not clicked yet");
    let button = qt::QPushButton("Click me");
    layout.addWidget(label);
    layout.addWidget(button);
    qt::connect(button, "clicked", T_CLICKED);
    win.show();

    var clicks = 0;
    var ev = default<qt::Event>();
    while qt::wait(-1) == qt::WAIT_EVENTS {      // until the last window closes
        while qt::poll(ev) {
            if ev.tag == T_CLICKED {
                clicks++;
                label.setText(str("Clicked ", clicks, " times"));
            }
        }
    }
    qt::shutdown();
}
```

Run it with the JIT, or build it:

```sh
goose hello.goose
goose build hello.goose -o hello && ./hello
```

What is going on:

- `qt::init()` starts a `QApplication`. `qt::init(qt::APP_GUI)` starts a `QGuiApplication`
  (QML and painting, no widgets) and `qt::init(qt::APP_CORE)` a `QCoreApplication` (no
  windows: networking, files, timers).
- `qt::QWidget()` and the other class-named functions are constructors. They return a
  `qt::Obj`, a handle, not a pointer.
- `win.setWindowTitle("Hello")` is a generated function, `qt::setWindowTitle(win, "Hello")`,
  called through Goose's method syntax.
- `qt::connect` does not take a callback. The signal is queued as an event with your tag, and
  your loop handles it: `qt::wait` runs Qt until something is queued, `qt::poll` hands the
  events over. See [Events and signals](events.md).
- `qt::shutdown()` destroys everything Qt still holds for you.

## Without a display

Every Qt program can run on Qt's offscreen platform, which is how tests, CI and the samples'
self-tests run. Pass the platform when starting Qt, or set it in the environment:

```goose
qt::init(qt::APP_WIDGETS, "hello\0-platform\0offscreen");   // NUL-separated command line
```

```sh
QT_QPA_PLATFORM=offscreen ./hello
```

## When something is wrong

Misuse is an error, not a crash. After `qt::init`, failures are printed to stderr:

```goose
let spin = qt::QSpinBox();
spin.setValue(10000000000);             // qtc: QTC_ERR_OUT_OF_RANGE: ... expected an integer in range
qt::destroy(win);
win.show();                             // qtc: QTC_ERR_STALE_HANDLE: receiver
```

To handle them yourself instead, `qt::set_error_policy(qt::ERRORS_RETURN)` and check the
calls that matter (`bool` results, or `qt::last_error()`). [Concepts](concepts.md#errors-instead-of-crashes)
explains the policies.

## Where next

- [Concepts](concepts.md), then [Calling Qt](calling-qt.md): how the whole of Qt maps onto
  Goose functions.
- The [examples](../examples): `hello`, `form`, `canvas`, `qml`, `threads`, `rhi`, and a Goose
  UI built as a shared library. Each runs interactively or with `--selftest`.
- The [samples](../samples): a million-row table, a notes app, a network echo server, an
  oscilloscope fed by threads, a GPU fractal, and a stability storm.
