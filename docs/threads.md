# Threads and futures

Qt objects belong to the GUI thread, the one that called `qt::init`. Other threads compute;
the GUI thread shows. goose-qt makes that split explicit: a qt call from another thread fails
with `qt::ERR_WRONG_THREAD` instead of racing Qt, and two channels carry work back.

Goose's threads (`thread_fn`, `thread_spawn`, `thread_wait`) exist in native builds only;
the JIT runs no threads. Build threaded programs with `goose build`.

## Posting: the simple channel

`qt::post(tag, a, b)` is the one qt call any thread may make. It queues an event with two
integers and wakes `qt::wait` on the GUI thread:

```goose
thread_fn work(id: i64, steps: i64) {
    for step in steps {
        crunch(step);
        qt::post(T_PROGRESS, id, step + 1);
    }
    qt::post(T_DONE, id, 0);
}

fn main() {
    qt::init();
    let bar = qt::QProgressBar();
    bar.setMaximum(4 * 250);
    bar.show();
    var threads: i64[>..] = [];
    for t in 4 { threads.push(thread_spawn(work, t, 250)); }
    var reports = 0;
    var ev = default<qt::Event>();
    while qt::wait(-1) == qt::WAIT_EVENTS {
        while qt::poll(ev) {
            if ev.tag == T_PROGRESS { reports++; bar.setValue(reports); }
        }
    }
    for t in threads { thread_wait(t); }
    qt::shutdown();
}
```

Two integers go a long way: the [scope sample](../samples/scope/scope.goose) packs eight
16-bit samples into each post and moves 200,000 samples a second from four threads this way,
none dropped. A post with its poll costs about 60 ns.

## Futures: results, progress, cancellation

A future carries a whole result back, with progress and cancellation. The GUI thread makes a
promise and passes its id to a worker; the worker fills it with the promise functions (which
any thread may call) and finishes it:

```goose
thread_fn band(id: u64, row0: i64, rows: i64) {
    let f = qt::Future { id: id };
    qt::progress_range(f, 0, rows);
    var out: u8[>..] = [];
    for r in rows {
        if qt::canceled(f) { break; }               // the GUI side canceled: stop early
        render_row(out, row0 + r);
        qt::progress(f, r + 1);
    }
    qt::add_bytes(f, out);                          // results: add(f, i64 | f64 | text | f64[]), add_json
    qt::finish(f);                                  // or qt::fail(f, "why")
}

let f = qt::promise();
let t = thread_spawn(band, f.id, 0, 192);
if qt::wait(f, 60000) == qt::WAIT_FINISHED {        // the event loop runs while it waits
    let bytes = qt::result_str(f, 0);               // result_int, result_f64, result_str, result_val
}
qt::release(f);
thread_wait(t);
```

Instead of waiting, watch it: `qt::watch(f, tag)` delivers `qt::EV_FUTURE_PROGRESS`
(`i0` value, `i1`/`i2` the range, `qt::text(ev)` the progress text), `EV_FUTURE_RESULTS` and
finally `EV_FUTURE_FINISHED` (`i0` the state, `i1` the result count), so a progress bar and a
Cancel button stay responsive.

| GUI thread | Worker |
|---|---|
| `qt::promise()`, `qt::release(f)` | `qt::Future { id: id }` |
| `qt::wait(f, ms)`, `qt::watch(f, tag)`, `qt::unwatch_future(w)` | `qt::add(f, …)`, `qt::add_bytes`, `qt::add_json` |
| `qt::state(f)`, `is_finished`, `is_failed`, `qt::error(f)` | `qt::progress_range`, `qt::progress(f, value[, text])` |
| `qt::result_count(f)`, `result_int/f64/str/val(f, i)` | `qt::finish(f)`, `qt::fail(f, message)` |
| `qt::cancel(f)`, `qt::suspend(f, on)` | `qt::canceled(f)`, `qt::suspend_if_requested(f)` |
| `qt::all(a, b)`, `qt::any(a, b)` | |

Every way a future can end finishes it, so nothing waits forever on a worker that died.
`qt::live_futures()` counts the ones not yet released.

A future also makes a good stop token for long-running workers: the scope sample's workers
loop `while !qt::canceled(token)`, and the GUI thread cancels it on close.

The [mandelbrot sample](../samples/mandelbrot/mandelbrot.goose) renders a 1024 × 768 image
in four bands this way, in 67 ms on two cores.

## Worker objects

Qt's own pattern, an object living on a `QThread` with its own event loop, works too, for
Qt objects that should do their work away from the GUI (a socket handling a protocol, a
`QFileSystemWatcher`):

```goose
let thread = qt::QThread();
thread.start();
let worker = qt::QTimer();
worker.start(5);
qt::connect(worker, "timeout", T_TICK);          // its signals still reach your loop
qt::move_to_thread(worker, thread);              // from now on it lives on that thread
worker.isActive();                               // refused: ERR_WRONG_THREAD
```

Set a worker up before moving it: once moved, direct calls to it are refused. Its signals
keep arriving as events. An object moves only when nothing on the GUI thread can still reach
it. `qt::destroy(worker)` deletes it on its own thread; end the thread with `thread.quit()`
and `thread.wait()`.

`qt::invoke_queued(o, method)` queues a call to a slot or invokable of an object whose class
qtc does not bind itself (a QML object, a runtime class) on that object's thread, and
`qt::invoke_future(o, method)` does the same and returns a future for the result.

## What is not available

qtc's thread-pool tasks (`qtc_task_*` in C) take C function pointers, which Goose does not
have, so goose-qt does not bind them; Goose threads filling promises do the same job.
