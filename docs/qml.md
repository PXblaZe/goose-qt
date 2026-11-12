# QML and Qt Quick

QML objects are ordinary Qt objects to goose-qt: their properties, functions and signals are
reached with the same calls as a widget's. A `QtcBridge` object adds a structured channel in
both directions. The [qml example](../examples/qml.goose) is a complete program.

## Loading QML

QML's classes are in the `qml` module, Qt Quick's in `quick`:

```goose
import qt from "path/to/goose-qt";
import qt.qml;
import qt.quick;      // QQuickView, QQuickItem, ... when the program uses them
```

```goose
qt::init(qt::APP_GUI);                     // QGuiApplication is enough for Qt Quick
let engine = qt::QQmlApplicationEngine();
let bridge = qt::new_object("QtcBridge");
engine.rootContext().setContextProperty("bridge", bridge);
qt::connect(bridge, "sent", T_FROM_QML);
engine.loadData(QML);                      // QML text; engine.load("main.qml") for a file

let roots = engine.rootObjects();          // a list value of the top-level objects
let first = roots.list_get(0);
let window = first.to_obj();
first.free();
roots.free();
```

Goose's raw strings (`"""…"""`) hold QML without escaping. With no display, run with the
offscreen platform and `QT_QUICK_BACKEND=software`.

## QML to Goose

In QML, `bridge.send(name, payload)` with any JavaScript value arrives as a `sent` signal
event, with the name and the payload (a value: lists, maps, numbers, strings) as its
arguments:

```qml
MouseArea { onClicked: bridge.send("clicked", { clicks: win.clicks, at: Date.now() }) }
```

```goose
if ev.tag == T_FROM_QML {
    let name = ev.arg_str(0);
    let payload = ev.arg_val(1);                 // a map here
    let clicks = payload.map_get("clicks");
    print(name, ": ", clicks.to_int(), " (", payload.json(), ")");
    clicks.free();
    payload.free();
}
```

## Goose to QML

`bridge.post(name, payload)` emits the bridge's `message(name, payload)` signal in QML:

```goose
let answer = qt::new_map();
let text = qt::val("saved");
answer.map_set("text", text);
qt::arg("status");
qt::arg(answer);
qt::call(bridge, "post");
text.free();
answer.free();
```

```qml
Connections {
    target: bridge
    function onMessage(name, payload) { status.text = payload.text }
}
```

## Properties, functions and signals declared in QML

```goose
let clicks = qt::get_int(window, "clicks");      // property int clicks
qt::set(window, "title", "From Goose");
qt::call(window, "press");                        // function press()
qt::arg(3); qt::call(window, "addRows");          // function addRows(n)
qt::connect(window, "closing", T_CLOSING);        // a signal QML declares or inherits
let item = qt::find_child(window, "okButton");    // objectName: "okButton"
print(qt::describe(item));                        // what it offers, as JSON
```

## Exposing Goose objects to QML

Beyond the bridge, a class made at run time ([Subclassing](subclassing.md#classes-made-at-run-time))
can be set as a context property: QML sees its properties (with change notifications), calls
its invokables and slots, which arrive in Goose's override handler, and connects to its
signals. A Goose-written model (`QAbstractListModel` subclassed in Goose) works as a QML
`ListView` model the same way it works for widgets.

## What to know

- QML and JavaScript run inside Qt; what they do is outside what qtc can check. A QML error
  (a missing import, a typo) prints Qt's message and loads nothing: check that `rootObjects`
  is not empty.
- Qt Quick picks its graphics API itself; `qt::quick_set_graphics_api(qt::GAPI_OPENGL)`
  (before the first window) chooses one, and `qt::quick_graphics_api(window)` says which is
  in use. See [Graphics](graphics.md).
