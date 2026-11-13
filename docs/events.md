# Events and signals

A goose-qt program owns its event loop. Signals, input events, timers and messages from
worker threads all arrive the same way: as `qt::Event` records, queued by qtc and handed
over by `qt::poll`. Nothing in Qt calls a Goose function to deliver them.

## The loop

```goose
var ev = default<qt::Event>();
while qt::wait(-1) == qt::WAIT_EVENTS {
    while qt::poll(ev) {
        if ev.tag == T_SAVE { save(); }
        else if ev.tag == T_QUIT { qt::quit(); }
    }
}
```

`qt::wait(timeout_ms)` runs Qt's own event loop (painting, input, sockets, timers) until
something is queued for you, the timeout passes, or the application quits. It returns:

| Result | Meaning |
|---|---|
| `qt::WAIT_EVENTS` | events are queued: poll them |
| `qt::WAIT_TIMEOUT` | the timeout passed with nothing queued |
| `qt::WAIT_QUIT` | `qt::quit()` was called, or the last window closed |

A timeout of `-1` waits as long as it takes, `0` only processes what is pending. A loop that
also does its own work on a schedule uses a timeout:

```goose
while qt::wait(16) != qt::WAIT_QUIT {          // about 60 times a second
    while qt::poll(ev) { handle(ev); }
    animate();
}
```

`qt::process_events()` runs Qt's pending work once without waiting, `qt::pending()` says how
many events are queued, and `qt::quit(code)` / `qt::exit_code()` end the loop with an exit
code. By default closing the last window quits; `qt::set_quit_on_last_window_closed(false)`
keeps going (a tray app, a program with no windows), and `qt::cancel_quit()` takes back a
quit that has not been acted on yet.

## The event record

| Field | Holds |
|---|---|
| `tag` | the tag you gave `qt::connect`, `qt::watch`, `qt::timer` or `qt::post` |
| `kind` | `qt::EV_SIGNAL`, `EV_POST`, `EV_TIMER`, `EV_MOUSE_PRESS`, `EV_KEY_PRESS` … |
| `source` | the object it came from, as a handle (`qt::sender(ev)` gives it as a `qt::Obj`) |
| `id` | the connection, watch or timer that made it |
| `i0` … `i3`, `d0`, `d1` | small payloads: the first integer-like and floating arguments of a signal, a post's two values, an input event's position and buttons |
| `count` | how many emissions were merged into it (coalescing) |
| `argc` | how many signal arguments were captured |
| `flags` | `qt::EVF_STALE_SOURCE` when the source was destroyed after the event was queued |

## Signals

```goose
let c = qt::connect(button, "clicked", T_CLICKED);
qt::connect(slider, "valueChanged", T_VALUE);              // ev.i0 is the new value
qt::connect(edit, "textChanged", T_TEXT, qt::CONN_COALESCE);
qt::disconnect(c);
```

The signal is named without its signature when the name is unique (`"clicked"`), or with it
(`"valueChanged(int)"`). Every argument is available while the event is among the 64 most
recent:

```goose
if ev.tag == T_TEXT {
    let text = qt::arg_str(ev, 0);       // or ev.arg_str(0)
}
// qt::arg_kind, arg_bool, arg_int, arg_f64, arg_str, arg_obj, arg_val (free it), qt::signal(ev)
```

Flags for `qt::connect`:

| Flag | Effect |
|---|---|
| `qt::CONN_COALESCE` | while an event from this connection is still queued, a new emission updates it instead of queueing another; `ev.count` says how many were merged. Use it for chatty signals: typing, scrolling, progress, `readyRead` |
| `qt::CONN_ONCE` | the connection ends after its first event |
| `qt::CONN_NO_ARGS` | the arguments are not captured (faster, for signals whose arguments you ignore) |
| `qt::CONN_DIRECT` | the program's `goose_qt_signal` runs inside the emission instead (below) |

Because the handler runs after the emission is over, it may destroy anything, the sender
included. Later events from a destroyed sender are still delivered, flagged:
`qt::stale_source(ev)`.

## Direct signals

A connection made with `qt::CONN_DIRECT` runs a function of the program inside the
emission, as a slot runs in C++, instead of queueing an event. Goose has no function
pointers, so the program exports it under the name `goose_qt_signal`, and turns direct
signals on once:

```goose
export "goose_qt_signal" fn on_signal(tag: u64, source: u64, seq: u64) {
    if tag == T_CLICKED { clicks++; }
    if tag == T_VALUE { let v = qt::arg_int(qt::direct_event(), 0); }
}

fn main() {
    qt::init();
    qt::use_direct_signals();      // false if the program exports no goose_qt_signal
    qt::connect(button, "clicked", T_CLICKED, qt::CONN_DIRECT);
    qt::connect(slider, "valueChanged", T_VALUE, qt::CONN_DIRECT);
```

`qt::direct_event()` is the whole event. The function runs as an override handler does
([Subclassing](subclassing.md)): it may call Qt as usual and may destroy the sender, which is
deleted once Qt's call returns, but it may not run the event loop (`qt::wait` fails).
Emissions inside it nest, up to 64 deep. Queued events stay the default: they need no
exported function and their handler may do anything. A direct signal takes about a quarter
fewer instructions than a queued one. Until the Goose compiler fix is out, a direct handler
that allocates can overwrite its callers' locals ([Handlers that
allocate](subclassing.md#handlers-that-allocate)). Queued handlers are not affected.

`qt::connect_to(sender, "valueChanged", receiver, "setValue")` forwards a signal straight to
another object's method inside the emission, without an event: no Goose code runs, and the
call is checked like any other.

## Input events from any widget

Signals cover what widgets announce. To see raw input on a widget (a canvas, a custom
control), watch it:

```goose
let mask = qt::bit(qt::EV_MOUSE_PRESS) | qt::bit(qt::EV_MOUSE_MOVE) | qt::bit(qt::EV_KEY_PRESS);
let w = qt::watch(canvas, mask, T_INPUT);
// later: qt::unwatch(w)
```

| Kind | Payload |
|---|---|
| `EV_MOUSE_PRESS`, `_RELEASE`, `_DOUBLE_CLICK`, `_MOVE` | `d0`, `d1` position; `i0` button, `i1` buttons held, `i2` modifiers |
| `EV_WHEEL` | `i0` vertical and `i1` horizontal angle delta, `i2` modifiers, `d0`, `d1` position |
| `EV_KEY_PRESS`, `_RELEASE` | `i0` the `Qt::Key`, `i1` modifiers, `i2` auto-repeat; `qt::text(ev)` the typed text |
| `EV_RESIZE`, `EV_MOVE` | `i0`, `i1` new size or position; `i2`, `i3` old |
| `EV_DROP`, `EV_DRAG_*` | `d0`, `d1` position, `i0` proposed action; `qt::text(ev)` the text or URLs |
| `EV_CLOSE` | a close request |
| `EV_FOCUS_IN/OUT`, `EV_ENTER/LEAVE`, `EV_SHOW/HIDE`, `EV_PAINT`, `EV_CONTEXT_MENU`, `EV_WINDOW_STATE` | none |
| `EV_DESTROYED` | the watched object is gone |

The four-argument form takes a second mask of events to **consume**, which the widget then
never sees. Consuming `EV_CLOSE` keeps a window open, for "save changes?" questions:

```goose
qt::watch(window, qt::bit(qt::EV_CLOSE), qt::bit(qt::EV_CLOSE), T_CLOSE_REQUEST);
```

To change how a widget reacts to input itself, rather than watch it, override its event
methods ([Subclassing](subclassing.md)).

## Timers

```goose
let tick = qt::timer(1000, T_TICK);         // every second, until destroyed
qt::single_shot(250, T_LATER);              // once
qt::destroy(tick);
```

Timer events coalesce: if the loop falls behind, one event arrives with `ev.i0` saying how
many timeouts it stands for, rather than a backlog.

## Posting

`qt::post(tag, a, b)` queues an `EV_POST` event with two integers. It is the one call any
thread may make, which makes it the way worker threads report back
([Threads and futures](threads.md)), and it also works on the GUI thread to schedule
something for the next turn of the loop:

```goose
qt::post(T_REFRESH, 0, 0);      // handled after the events already queued
```

## Queue limits

The queue holds a million events by default. Past the limit, new events are dropped and
counted rather than letting memory grow without bound:

```goose
qt::set_queue_limit(10000);
qt::dropped_events();           // how many were dropped so far
```

A program that falls behind a fast producer should coalesce (`CONN_COALESCE`), batch (pack
more data per post, as the [scope sample](../samples/scope/scope.goose) packs eight samples
into each), or check `qt::dropped_events()`.

## Costs

A signal round trip (emit, queue, poll) costs about 0.2 µs from Goose, a direct signal about
0.15 µs, and a post with its poll about 0.06 µs; see [Comparison](comparison.md).
