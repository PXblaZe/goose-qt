# Troubleshooting

## Starting

**`goose runtime error: cannot load qtc (libqtc.so.1)`**
The loader cannot find libqtc. Install goose-qt with CMake (it writes qtc's path into the
installed `qt.build`), set `LD_LIBRARY_PATH` (`DYLD_LIBRARY_PATH` on macOS, `PATH` on
Windows) to qtc's library directory, or name the library in your program's `app.build`:
`dylibs_linux = ["qtc=/path/to/libqtc.so.1"];`.

**Errors about `const if`, `same<T, …>` or type arguments when compiling**
The Goose compiler is older than goose-qt needs (8 November 2026). Update Goose.

**`qt::init` fails, or Qt says it could not connect to a display**
There is no display. Pass `"-platform\0offscreen"` in `qt::init`'s arguments or set
`QT_QPA_PLATFORM=offscreen`; for real GPU rendering without a screen, use `xvfb-run`.

**Qt complains about the locale (`Detected locale "C" … not UTF-8`)**
Set a UTF-8 locale: `LC_ALL=C.UTF-8`.

## Calls

**`QTC_ERR_NOT_FOUND: … no such method`**
The receiver's class has no bound method of that name and argument shape. Check the class
with `print(qt::describe(o))`; the method may be on another class, protected (reach it with
`qt::call` on an overridable object), or not bound (qtc's
[coverage](https://github.com/PXblaZe/qtc/blob/main/docs/COVERAGE.md) says why). With a default libqtc, the GPL-3.0-only
modules' classes are absent: `qt::class_exists("QChartView")` is false.

**`QTC_ERR_AMBIGUOUS`**
Two C++ overloads fit the arguments equally; the message names both. Call by signature:
`qt::arg(…); qt::call(o, "setValue(int)")`.

**`QTC_ERR_STALE_HANDLE`**
The object was destroyed (by you, by its parent, or by Qt, as with a closed window that had
`WA_DeleteOnClose`), or the value was freed. Keep handles only as long as their objects live;
`qt::alive(h)` checks.

**`QTC_ERR_WRONG_THREAD`**
A qt call from a worker thread. Only `qt::post` and the promise functions may be called off
the GUI thread; see [Threads](threads.md).

**`QTC_ERR_OUT_OF_RANGE`**, **`QTC_ERR_LIMIT`**, **`QTC_ERR_REJECTED`**
An argument outside what the parameter allows, an allocation or operation above qtc's limits
(`qt::set_alloc_limit` raises the size limit), or an input refused because it is known to
crash Qt. The message says which.

**A method returns `f64` or `qt::Val` where I expected an integer or an object**
The same name returns different types on different classes, so the generic function returns
the common type. Use the typed variant: `value_int()`, `model_obj()`. See
[Calling Qt](calling-qt.md#when-one-name-returns-different-types-typed-variants).

**A Qt method's name is missing, but `name_` exists**
It clashed with a Goose keyword or built-in (`exit`, `copy`, `format`); the wrapper has a
trailing underscore.

## Events

**My signal never arrives**
Is the loop running (`qt::wait` and `qt::poll`)? Did `qt::connect` return non-zero (a wrong
signal name returns 0 and sets an error)? Events for a destroyed source still arrive,
flagged; events past the queue limit are dropped (`qt::dropped_events()`).

**The program quits when I close a dialog**
Closing the last visible window quits. Call `qt::set_quit_on_last_window_closed(false)` for
programs that keep running without windows.

**Many events where I expected one**
Connect chatty signals with `qt::CONN_COALESCE`.

## Overrides

**My override is never called**
Call `qt::use_overrides()` after `qt::init` (it returns `false` when the program exports no
`goose_qt_override`), make the object with `qt::new_overridable`, and check that
`qt::override` returned `true` (`qt::overridable_methods(class)` lists the names). Calls Qt
makes on other threads run the class's own implementation.

## Threads

**A program with `thread_fn` fails under the JIT**
The JIT runs no threads; build natively with `goose build`.

## Quieting Qt

Qt prints its own warnings to stderr (the offscreen platform's, a missing GPU backend's,
Qt rejecting a value). Silence categories with Qt's logging rules in the environment:

```sh
QT_LOGGING_RULES="*.warning=false" ./app            # Qt's warnings off; errors still show
QT_LOGGING_RULES="qt.vulkan.warning=false;default.warning=false" ./app
```

qtc's own messages about refused calls follow the error policy instead
(`qt::ERRORS_RETURN` to keep them quiet and check `qt::last_error()` yourself).
