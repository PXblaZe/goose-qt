# goose-qt documentation

goose-qt is Qt 6 for the Goose language. It binds [qtc](../../qtc), a C library over Qt 6.12
LTS that refuses misuse instead of crashing, and generates a Goose function for every method
qtc binds: widgets, Qt Quick and QML, painting, item models, networking, multimedia, Qt's GPU
layer, and the rest. These pages explain how to use it; the [samples](../samples) show what it
does at scale, with measured numbers.

## Start here

- [Getting started](getting-started.md): install, a first window, running with the JIT and as
  a native build.
- [Concepts](concepts.md): handles instead of pointers, who owns what, errors instead of
  crashes, the GUI thread, and the event loop you run yourself. Read this before anything big.

## Guides

| Page | What it covers |
|---|---|
| [Calling Qt](calling-qt.md) | constructors, methods, overloads, typed variants, statics, enums, properties, the generic call, out-parameters |
| [Values](values.md) | `qt::Val`: Qt value types, lists, maps, JSON, conversion, freeing |
| [Events and signals](events.md) | the loop, signals, coalescing, input events, timers, posts, quitting |
| [Building interfaces](interfaces.md) | windows, layouts, main windows with menus and actions, item views and models, dialogs, screenshots |
| [Drawing](drawing.md) | the recording painter: canvases, images, painting inside overridden `paintEvent` |
| [QML and Qt Quick](qml.md) | loading QML, the bridge both ways, QML properties and functions |
| [Subclassing Qt classes](subclassing.md) | overriding virtual methods in Goose; classes made at run time |
| [Threads and futures](threads.md) | worker threads, `qt::post`, futures and promises, worker objects |
| [Graphics](graphics.md) | Qt's RHI over Vulkan, Metal, Direct3D and OpenGL: render passes, compute, readback, interop |
| [Networking](networking.md) | TCP servers and sockets, HTTP, and what to watch for |
| [Embedding in C and C++](embedding.md) | a Goose-written Qt UI built as a shared library |
| [Testing your program](testing.md) | simulated input, offscreen runs, screenshots, checking for leaks |

## Reference

| Page | What it covers |
|---|---|
| [Build and install](build-and-install.md) | CMake options, installing by hand, fetching from git, `qt.build` |
| [Performance](performance.md) | what calls cost, and what the samples sustain |
| [How goose-qt compares](comparison.md) | the same benchmark in C++, qtc, goose-qt, PyQt6, PySide6 and Go, and three misuses in each |
| [Stability](stability.md) | what "misuse is an error" covers, how it is tested, the known limits |
| [Troubleshooting](troubleshooting.md) | error messages and what to do about them |
| [Internals](internals.md) | how `api.goose` is generated, typed variants, the override trampoline |

The C library underneath has its own documents, which these link to where they matter:
[API](../../qtc/docs/API.md), [design](../../qtc/docs/DESIGN.md),
[limits](../../qtc/docs/LIMITS.md), [testing](../../qtc/docs/TESTING.md),
[coverage](../../qtc/docs/COVERAGE.md) and [licensing](../../qtc/docs/LICENSING.md).

## The source, at a glance

| File | What it is |
|---|---|
| `qt.goose` | the hand-written core: start and stop, the event loop, the generic call, properties, values, drawing, test helpers |
| `extra.goose` | overrides, runtime classes, futures, worker objects, graphics |
| `api.goose` | generated: wrappers for Qt Core, Gui and Widgets' methods, constructors, statics and enums |
| `network.goose`, `qml.goose`, ... | generated: the same for each other Qt module (`import qt.network;`); `all.goose` imports every one |
| `qt.build` | which shared libraries the package loads (`libqtc`, `libqtc_test`) |
| `include/goose_qt.h` | the C trampoline override handlers go through |
| `examples/` | short programs, one feature each |
| `samples/` | larger programs that showcase power, performance and stability |
| `test/` | the test suite and the call benchmark |
