# Subclassing Qt classes

Much of Qt is used by subclassing: a model that serves your data, a widget that paints itself,
a validator, an item delegate, a `QIODevice`. goose-qt does this without C++: you make an
object of an *overridable* class, say which virtual methods Goose handles, and export one
function that Qt's calls to those methods come to.

## The handler

```goose
let T_ROWS: u64 = 1;
let T_DATA: u64 = 2;

export "goose_qt_override" fn on_override(obj: u64, tag: u64, nargs: i64, depth: i64) -> i32 {
    if tag == T_ROWS {
        qt::ov_ret(if qt::ov_arg_index(0).valid { 0 } else { 1000 });  // only the root has rows
        return qt::OV_DONE;
    }
    if tag == T_DATA {
        let ix = qt::ov_arg_index(0);
        if qt::ov_arg_int(1) == 0 {                       // Qt::DisplayRole
            qt::ov_ret(str("row ", ix.row));
            return qt::OV_DONE;
        }
    }
    return qt::OV_BASE;                                   // the class's own implementation
}

fn main() {
    qt::init();
    qt::use_overrides();                                  // points libqtc at goose_qt_override
    let model = qt::new_overridable("QAbstractListModel");
    qt::override(model, "rowCount", T_ROWS);
    qt::override(model, "data", T_DATA);
    let view = qt::QListView();
    view.setModel(model);
    view.show();
    ...
}
```

- `qt::use_overrides()` returns `false` when the program exports no handler.
- `qt::new_overridable(class)` makes the object (constructor arguments pushed with `qt::arg`
  first). It is a real instance of the class, usable anywhere one is expected.
- `qt::override(o, method, tag)` routes one method of one object to the handler, by name or,
  for an overload, by signature (`"event(QEvent*)"`); tag 0 stops overriding it.
- The handler gets the object's handle, the tag, the argument count and the nesting depth,
  and answers `qt::OV_DONE` (it set the result) or `qt::OV_BASE` (run the class's own
  implementation).

`qt::overridable_classes()` lists the classes that can be subclassed this way (one per
line), and `qt::overridable_methods("QAbstractItemModel")` their overridable methods.

## Reading arguments, setting results

| Read | |
|---|---|
| `ov_arg_int(i)`, `ov_arg_f64(i)`, `ov_arg_bool(i)`, `ov_arg_str(i)` | scalars and strings |
| `ov_arg_obj(i)`, `ov_arg_val(i)` | objects and values (free the value) |
| `ov_arg_index(i)` | a `QModelIndex` as `qt::ModelIndex { row, column, id, valid }` |
| `ov_arg_event(i, ev)`, `ov_event_text(i)` | an event argument (`QMouseEvent *`, `QKeyEvent *` …) as `qt::poll` would deliver it |
| `ov_arg_kind(i)`, `ov_arg_type(i)` | what an argument is |
| `ov_buffer_read(i)` | `QIODevice::writeData`'s buffer |

| Result | |
|---|---|
| `ov_ret(v)` | bool, i64, f64, text or a value |
| `ov_ret_uint`, `ov_ret_bytes`, `ov_ret_index(row, column, id)` | the rest |
| `ov_set_arg_int(i, v)`, `ov_set_arg_str(i, v)` | write an in-out argument (`QValidator::validate`'s string and position) |
| `ov_buffer_write(i, bytes)` | fill `QIODevice::readData`'s buffer |
| `ov_accept_event(i, accepted)` | accept or ignore an event argument |
| `ov_call_base()` | run the class's implementation now, then adjust its result |

Painting overrides draw with the same calls as everything else: `qt::draw_begin(qt::Obj { h:
obj })` in a widget's `paintEvent`, or `qt::draw_begin_painter(i)` for methods that receive a
`QPainter *`. See [Drawing](drawing.md#inside-paintevent).

Protected methods a subclass needs (`beginInsertRows`, `endInsertRows`, `beginResetModel`,
`createIndex`) are not in `api.goose`, which binds public methods, but the generic call
reaches them on overridable objects:

```goose
qt::call(model, "beginResetModel");   // the data behind the model is about to change
reload_rows();
qt::call(model, "endResetModel");     // views ask again
```

## Rules that keep it safe

The handler runs inside Qt's call, so a few things are refused there:

- It runs on the GUI thread. Methods Qt calls on other threads (`QThread::run`) run Qt's own
  implementation instead (Goose's exported functions run on the main thread only).
- It may call goose-qt freely, but not run the event loop (`qt::wait`) or shut Qt down; calls
  nest at most 64 deep (`depth` says how deep this one is).
- Results Qt cannot use are refused where qtc can see them: negative counts, a model index
  made by another model, begin/end calls out of order. A model whose `data()` contradicts its
  `rowCount()` gives views wrong answers, as in C++, but does not crash them.

## Speed

Overrides are fast enough for models of any size a view can show. The
[million sample](../samples/million/million.goose) filters a million rows through
`QSortFilterProxyModel`, a call into Goose per row, at 1.4 million calls a second: 2.3–4.4× what
Go and the Python bindings manage ([comparison](comparison.md)).

## Classes made at run time

For objects that QML or other Qt code should see as a class of their own, with signals,
slots, invokable methods and properties, define the class while the program runs:

```goose
qt::class_begin("Counter", "QObject");
qt::class_property("count", "int", qt::PROP_WRITE | qt::PROP_NOTIFY);   // countChanged is made
qt::class_invokable("twice(int)", "int", T_TWICE);   // QML can call it; it comes to the handler
qt::class_slot("reset()", "", T_RESET);              // return type "" is void
qt::class_signal("ping(QString)");
qt::class_end();

let c = qt::class_new("Counter");
qt::set(c, "count", 5);                              // properties keep their own values
qt::arg("hello");
qt::emit(c, "ping");                                 // emit a signal with pushed arguments
```

Invokables and slots arrive at `goose_qt_override` with their tag; read their arguments with
`ov_arg_*` and answer with `ov_ret`, as above. Property flags: `qt::PROP_READ` (0),
`PROP_WRITE`, `PROP_NOTIFY`, `PROP_CONSTANT`. A class name can be defined once per run;
`qt::class_cancel()` abandons a definition in progress.
