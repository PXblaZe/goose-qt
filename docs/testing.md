# Testing your program

Qt programs written with goose-qt test well: they can run without a display, input can be
simulated, and qtc counts what is alive, so a test can also check that nothing leaked. Every
example and sample here has a `--selftest` mode built from these pieces.

## Run offscreen

```goose
qt::init(qt::APP_WIDGETS, "mytest\0-platform\0offscreen");
```

or `QT_QPA_PLATFORM=offscreen` in the environment (and `QT_QUICK_BACKEND=software` for Qt
Quick). Widgets lay out and paint as usual; nothing is shown. Painting happens when Qt
decides to; `w.grab()` forces it, which makes offscreen paint code run when a test needs it.

The offscreen platform has no GPU. For graphics tests use the Null RHI backend (it checks
everything and draws nothing), or run under `xvfb-run` with Mesa for real Vulkan and OpenGL.

## Simulated input

The `qt::test_*` functions drive widgets through Qt Test, as a user would; they load
`libqtc_test`, which only test programs need:

```goose
qt::test_show(win);                         // show and wait until it is exposed
qt::test_click(button);                     // the centre; test_click(w, x, y) for a point
qt::test_type(edit, "hello");               // key presses, so textEdited fires
qt::test_key(edit, qt::Qt.Key_Return);      // test_key(w, key, modifiers)
qt::test_double_click(list, 10, 10);
qt::test_press(canvas, 5, 5); qt::test_move(canvas, 50, 50); qt::test_release(canvas, 50, 50);
qt::test_wheel(view, -120);
qt::test_wait(50);                          // run the event loop for 50 ms
qt::test_grab(win, "shot.png");             // a screenshot
```

Many tests do not need simulated input at all: calling what a click would call
(`button.click()`, `action.trigger()`, `edit.insert("x")`) emits the same signals. The
[notes sample](../samples/notes/notes.goose) tests its whole app this way, through its own
actions.

## Seeing events arrive

Signals reach the queue during `qt::wait` and `qt::process_events`, so after acting, give
the loop a turn before checking:

```goose
action.trigger();
while qt::wait(0) == qt::WAIT_EVENTS { while qt::poll(ev) { handle(ev); } }
```

`qt::post(tag, 0, 0)` after a sequence of actions marks the end of it: when your loop
receives that tag, everything queued before has been handled.

## Checking for leaks

```goose
let objects0 = qt::live_objects();
let values0 = qt::live_values();
run_the_scenario();
qt::process_events();                       // destruction completes in the event loop
assert(qt::live_objects() == objects0);
assert(qt::live_values() == values0);
```

`qt::live_futures()` and `qt::rhi_live()` do the same for futures and GPU resources.

## Making errors loud

`qt::set_error_policy(qt::ERRORS_ABORT)` stops a test at the first refused call, with the
message, which finds the call that went wrong faster than a wrong result later. Use
`qt::ERRORS_RETURN` in tests that misuse the API on purpose and check `qt::last_error()`.

## goose-qt's own tests

`test/run.sh` runs the suite with the JIT and as native builds: basics, events, widgets,
drawing, QML, threads, overrides, futures, graphics, and a call of each of the 8,464
generated instance-method wrappers on a null receiver. `examples/run.sh` and `samples/run.sh`
run the examples and samples in their self-test modes. With CMake, `ctest` runs all three
and a program against the installed package. See [Stability](stability.md) for what else is
tested, and how.
