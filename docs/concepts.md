# Concepts

Five ideas explain how goose-qt behaves. The rest of the documentation builds on them.

## Handles, not pointers

Qt objects (`QWidget`, `QTimer`, `QTcpSocket`, anything derived from `QObject`) are
`qt::Obj`. Qt values (`QColor`, `QFont`, `QImage`, `QDateTime`, lists, maps …) are `qt::Val`.
Both are structs holding a 64-bit handle that qtc hands out; neither is a pointer.

```goose
let label = qt::QLabel("hi");          // qt::Obj { h: ... }
let red = qt::QColor(255, 0, 0, 255);  // qt::Val { h: ... }
```

A handle names its object until the object is gone, and never another one: a handle is a
slot and a generation, and the generation changes when the object goes. Calling through a handle whose object was destroyed is an error
(`qt::ERR_STALE_HANDLE`), a handle qtc never gave out is `qt::ERR_BAD_HANDLE`, and the null
handle (`qt::NONE`, or `qt::Val { h: 0 }`) is `qt::ERR_NULL_HANDLE`. None of these crashes.
`qt::alive(h)` asks without calling anything.

Handles are plain data: copy them, keep them in arrays, compare them (`a.h == b.h`). Two
handles to the same object are equal, because qtc gives one handle per object.

## Who owns what

**Objects** follow Qt's parent–child rules, with qtc filling the gap Qt leaves:

- An object made without a parent belongs to qtc until it gets one. `qt::shutdown()` destroys
  whatever qtc still owns, so nothing outlives the program by accident.
- Giving it a parent (`qt::QLabel("x", parent)`, `layout.addWidget(w)`,
  `window.setCentralWidget(w)`) hands it to Qt, which deletes it with its parent.
- `qt::destroy(o)` hides a widget, makes the handle stale at once, and deletes the object
  (and its children): right away, as `delete` would in C++, or, inside an override handler
  (where Qt may be busy with that very object) and while events are still queued for it,
  once control returns to the event loop. Destroying an object that
  another one holds by a plain pointer (a scroll area's viewport, a combo box's view) makes
  the holder let go first; what cannot be let go of is refused, with the owner named.
- Objects Qt hands out without an owner (what `QQmlComponent::create` or
  `QUiLoader::load` return) can be given to qtc with `qt::adopt(o)`.

**Values** are yours. Every `qt::Val` a function returns is a new handle on its own copy, and
you free it with `v.free()` (or `qt::free(v)`) when you are done. Freeing twice is refused,
not a crash. `qt::live_values()` counts the ones still alive, which makes leaks easy to test
for; `qt::shutdown()` frees the rest.

Strings are not handles. Methods that take a `QString`, `QByteArray` or `QUrl` take Goose
bytes (UTF-8), and ones that return text return a new `u8[>..]` you own.

## Errors instead of crashes

Every call reports how it went. The error policy decides what you see:

| Policy | What happens on an error |
|---|---|
| `qt::ERRORS_LOG` | the call returns a default (0, false, "", a null handle) and the error is printed to stderr. `qt::init()` sets this unless you chose another policy first |
| `qt::ERRORS_RETURN` | the same, without printing: check `qt::last_error()` yourself |
| `qt::ERRORS_ABORT` | the program stops at the first error, for development |

```goose
qt::set_error_policy(qt::ERRORS_RETURN);
qt::clear_error();
spin.setValue(10000000000);                     // past int's range
if qt::last_error() == qt::ERR_OUT_OF_RANGE {
    print("refused: ", qt::last_error_message());
}
```

`qt::last_error()` is the status of the most recent call that **failed** (errors are
negative, with names from `qt::status_name`), and it stays until the next failure or
`qt::clear_error()`; a successful call does not reset it. So clear it before the calls you
want to check, or use their results: functions that return `bool` return `true` on success,
and functions that return a handle return a null one on failure.

What is refused goes well past bad handles: arguments out of range, enum values the enum does
not have, objects that would end up inside themselves, allocations above a limit (256 MiB in
one go by default, `qt::set_alloc_limit`), operations Qt would take minutes over, and
hundreds of specific inputs that crash Qt itself. [Stability](stability.md) has the scope and
how it is tested, and its limits.

## One GUI thread

The thread that called `qt::init` is the GUI thread, and qt calls must come from it. A call
from another thread fails with `qt::ERR_WRONG_THREAD` instead of racing Qt. The exceptions
are `qt::post`, which any thread may call to send the GUI thread an event, and the promise
side of futures (`qt::add`, `qt::progress`, `qt::finish`, `qt::canceled` …), which workers
use to hand results back. See [Threads and futures](threads.md).

The JIT (`goose file.goose`) runs no threads, so programs that use `thread_fn` need a native
build (`goose build`).

## You run the event loop

Qt calls nothing in your program behind your back. A signal does not call a Goose function;
it queues an event with the tag you gave `qt::connect`, and your loop picks it up:

```goose
var ev = default<qt::Event>();
while qt::wait(-1) == qt::WAIT_EVENTS {   // run Qt until something is queued
    while qt::poll(ev) {                  // take the queued events, one at a time
        // ev.tag, ev.kind, ev.source, ev.i0 .. ev.i3, ev.d0, ev.d1
    }
}
```

So a handler can do anything, including destroying the object whose signal it is handling:
by the time your code runs, Qt has finished emitting. Events from objects destroyed after
the event was queued carry a flag (`qt::stale_source(ev)`).

There is one place Qt does call into Goose: methods you override when subclassing a Qt class
(a model's `data()`, a widget's `paintEvent`). Those run inside Qt's call, through a single
exported handler; [Subclassing](subclassing.md) explains the rules that keep that safe.

## How the API is shaped

Every Qt method qtc binds is a function in the `qt` namespace taking the receiver first, so
Goose's method syntax reads like C++:

```goose
label.setText("hi");          // qt::setText(label, "hi")
let w = slider.value_int();   // a typed variant: see Calling Qt
let c = img.pixelColor(2, 3); // a qt::Val
```

Constructors are named after the class (`qt::QLabel(...)`), static methods are
`qt::Class_method(...)` (`qt::QDateTime_currentDateTime()`), and enums are fields of a value
named after their scope (`qt::Qt.AlignCenter`, `qt::QImage.Format_ARGB32`). Anything the
generated functions do not cover is reachable by name through the generic call. All of this is
in [Calling Qt](calling-qt.md).
