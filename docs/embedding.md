# Embedding in C and C++

A Qt interface written in Goose can live inside a C or C++ program: build the Goose code as a
shared library with `goose build --shared`, and the program calls the functions it exports.
[examples/shared](../examples/shared) is a complete pair, `counter.goose` and `host.c`.

## The Goose side

```goose
import qt from "path/to/goose-qt";

var window = qt::NONE;
var label = qt::NONE;
var clicks = 0;
var text = str("");          // what counter_label hands out, kept until the next call

fn main() {                  // runs once, inside goose_init
    qt::init(qt::APP_WIDGETS);
}

export "counter_open" fn open(title: const u8[:]) -> i64 {
    window = qt::QWidget();
    window.setWindowTitle(title);
    let layout = qt::QVBoxLayout(window);
    label = qt::QLabel("no clicks yet", window);
    let button = qt::QPushButton("Click me", window);
    layout.addWidget(label);
    layout.addWidget(button);
    qt::connect(button, "clicked", 1);
    window.show();
    return 1;
}

// handles what happened for up to ms milliseconds; 0 once the window is closed
export "counter_run" fn run(ms: i64) -> i64 {
    if qt::wait(ms) == qt::WAIT_QUIT || !window.isVisible() { return 0; }
    var ev = default<qt::Event>();
    while qt::poll(ev) {
        if ev.tag == 1 { clicks++; label.setText(str(clicks, " clicks")); }
    }
    return 1;
}

export "counter_label" fn label_text() -> const u8[:] {
    text = label.prop<u8[]>("text");
    return text;              // stays valid until the next call
}

export "counter_close" fn close() { qt::shutdown(); }
```

```sh
goose build --shared --header counter.h -o libcounter.so counter.goose
```

`--header` writes the C declarations of the exported functions. A `const u8[:]` parameter is a
`sl_u8` struct (pointer and length) in C; a returned one is a pointer plus an `int64_t *`
length out-parameter, not NUL-terminated.

## The C side

```c
#include "counter.h"

int main(int argc, char **argv) {
    goose_init(argc, argv);                                  // runs counter.goose's main
    const char *title = "Counter";
    counter_open((sl_u8){(uint8_t *)title, (int64_t)strlen(title)});
    while (counter_run(50)) {}                               // the host's loop drives Qt
    counter_close();
    goose_exit();
}
```

```sh
cc host.c -I. -L. -lcounter -Wl,-rpath,'$ORIGIN' -o host
```

## Rules

- **One thread.** Call `goose_init` and every exported function from the same thread: it
  becomes Qt's GUI thread. Exported Goose functions run on the thread that started the
  program only.
- **The event loop is a function you export.** The host calls something like `counter_run`
  regularly (from its own loop, a timer, an idle handler); Qt does its work inside
  `qt::wait`. A host that already runs a Qt event loop of its own should not also call
  `qt::wait`; drive goose-qt's events with `qt::process_events()` and `qt::poll` from a
  `QTimer` instead.
- **Strings handed out** must stay alive after the function returns: keep them in a global, as
  `counter_label` does.
- **libqtc is found at run time** as for any goose-qt program: through the installed
  package's `qt.build`, or the library path. See [Build and install](build-and-install.md).
- A C++ host that also uses qtc directly can pass objects across with qtc's
  `qtc_wrap_pointer` and `qtc_unsafe_pointer` (see qtc's
  [API](../../qtc/docs/API.md#interop-with-c)); what C++ does with a raw pointer is outside
  qtc's checks.
