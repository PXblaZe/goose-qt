# Calling Qt

`api.goose` and the module files turn qtc's manifest into about 11,000 Goose functions: a
constructor for each class qtc can make, a function for each method name and parameter
shape, one for each static method, and a value for each enum scope. This page explains how
Qt's C++ API maps onto them, and how to reach what the generated functions do not cover.

## Qt modules

`import qt from "...";` brings Qt Core, Gui and Widgets. Every other Qt module is a file of
its own, imported when the program uses it:

```goose
import qt from "path/to/goose-qt";
import qt.network;      // QTcpSocket, QNetworkAccessManager, ...
import qt.qml;          // QQmlApplicationEngine, ...
import qt.all;          // or every module goose-qt binds
```

The names are the Qt module's in lower case: `network`, `sql`, `xml`, `printsupport`, `svg`,
`qml`, `quick`, `quickwidgets`, `multimedia`, `charts`, `serialport`, `websockets`, ... (see
`all.goose`). Everything stays in the `qt` namespace. A program compiles only the modules it
imports, so the JIT starts faster: about 0.45 s for a widgets program against 0.7 s with
everything. A function a module's class needs but a widgets class also has, such as
`setText`, is in `api.goose`; what is missing without the import is that module's
constructors, enums and the methods only its classes have.

## Constructors

A constructor is a function named after the class, overloaded like the C++ constructors:

```goose
let win = qt::QWidget();
let label = qt::QLabel("text", win);                       // QLabel(QString, QWidget *parent)
let img = qt::QImage(400, 300, qt::QImage.Format_ARGB32);  // a value: qt::Val
let font = qt::QFont("monospace", 12);
```

Classes derived from `QObject` give a `qt::Obj`; value types give a `qt::Val` you free later
([Values](values.md)). `qt::new_object("QLabel")` and `qt::new_value("QColor")` make one by
name, with constructor arguments pushed first with `qt::arg` (see the generic call below).
`qt::class_exists("QChartView")` says whether this libqtc binds a class at all.

## Methods

A method is a function whose first parameter is the receiver, so Goose's method syntax gives
C++'s look:

```goose
label.setText("hello");
label.setAlignment(qt::Qt.AlignRight | qt::Qt.AlignVCenter);
let t = label.text();                  // u8[>..]
let w = label.width();                 // i64
let c = img.pixelColor(2, 3);          // qt::Val
```

One Goose function covers every class with a method of that name and parameter shape:
`setText(o: Obj, a0: const u8[:])` serves `QLabel`, `QPushButton`, `QLineEdit` and the rest.
Where C++ has several overloads that fit, qtc picks the one for the receiver's class at run
time, from the arguments' kinds and values: `QSpinBox::setValue(int)` for a spin box,
`QDoubleSpinBox::setValue(double)` for a double spin box. A call that two overloads fit
equally fails with `qt::ERR_AMBIGUOUS` and names both; pass a signature through the generic
call to choose.

Parameter types map like this:

| C++ | Goose |
|---|---|
| `bool` | `bool` |
| integers, enums, flags | `i64` (range-checked against the C++ type) |
| `double`, `float`, `qreal` | `f64` |
| `QString`, `QByteArray`, `QUrl`, `const char *` … | `const u8[:]` (UTF-8) |
| `QObject *` and subclasses | `qt::Obj` |
| any value type (`QColor`, `QRect`, `QVariant`, `QList<…>` …) | `qt::Val` |

### When one name returns different types: typed variants

A name like `value()` returns an `int` on a `QSlider`, a `double` on a `QDoubleSpinBox` and a
`QVariant` elsewhere. The generic function returns the common type (`f64` when the choices are
numbers, otherwise `qt::Val`), and a typed variant gives each other type directly, with a
suffix: `_int`, `_f64`, `_bool`, `_str`, `_obj`, `_val`.

```goose
let v = slider.value_int();        // QAbstractSlider::value() is an int
let d = dspin.value();             // f64: the common type of value()
let m = view.model_obj();          // QAbstractItemView::model() is a QObject
```

Names that are Goose keywords, Goose built-ins or goose-qt's own functions get a trailing
underscore: `thread.exit_()`, `file.copy_("to")`, `format_()`.

Once a function's return type has been published, regenerating keeps it, so programs keep
compiling when a newly bound class brings a method of the same name with another result; that
class's result comes through a typed variant. See [Internals](internals.md).

## Static methods

`Class::method` becomes `qt::Class_method`:

```goose
let now = qt::QDateTime_currentDateTime();     // a value
let tmp = qt::QDir_tempPath();                 // a string
qt::QCoreApplication_setApplicationName("notes");
```

## Enums and flags

Each enum scope is a value whose fields are its keys:

```goose
label.setAlignment(qt::Qt.AlignHCenter | qt::Qt.AlignTop);
let fmt = qt::QImage.Format_ARGB32;
let a, ok = qt::enum_value("Qt::AlignHCenter");   // by name, when the name is data
```

An enum argument is checked: a value the enum does not have, or flags outside the flag
type, is refused with `qt::ERR_OUT_OF_RANGE`.

## Properties

Every Qt property can be read and written by name, which is also how QML objects' properties
are reached:

```goose
qt::set(win, "minimumWidth", 120);                 // i64, f64, bool, a string, Obj or Val
let n = win.prop<i64>("minimumWidth");             // the getter is picked by the type argument
let t = label.prop<u8[]>("text");
let on = check.prop<bool>("checked");
let parent = label.prop<qt::Obj>("parent");
let geo = win.prop<qt::Val>("geometry");           // free it
```

`qt::get_int`, `get_f64`, `get_bool`, `get_str`, `get_obj` and `get_val` are the same getters
by name. A write goes through the property's setter method when it has one, so it gets the
same checks as calling the setter.

## The generic call

Everything above is built on one mechanism you can use directly: push arguments, call a
method by name or by signature, then read the result.

```goose
qt::arg(10);
qt::arg(20);
qt::call(win, "resize");                           // the overload is chosen from the arguments

qt::arg("Title");
qt::call(win, "setWindowTitle(QString)");          // or named by signature

qt::call(label, "text");
let text = qt::ret_str();                          // ret_int, ret_f64, ret_bool, ret_obj, ret_val
if qt::call(list, "count") { let n = qt::ret<i64>(); }  // ret<T> picks by type, like prop<T>

qt::call_static("QDateTime", "currentDateTime");
let now = qt::ret_val();
```

| Push | Fits |
|---|---|
| `qt::arg(bool)`, `qt::arg(i64)`, `qt::arg(f64)` | bool, any integer or enum, floating point |
| `qt::arg(text)` | `QString`, `QByteArray`, `QUrl` and the like |
| `qt::arg_bytes(data)` | a `QByteArray` of raw bytes |
| `qt::arg(obj)` | a `QObject *` of the right class |
| `qt::arg(val)` | any value type, or `QVariant` |
| `qt::arg_null()` | a null pointer |

`qt::call` returns `true` on success. Trailing parameters with defaults may be left out, also
from a signature. Use the generic call for:

- methods the generated functions cannot express (a signature you want to force),
- QML objects' functions (`qt::call(window, "press")`) and runtime classes' invokables,
- classes this program learns about at run time, from strings.

### Out-parameters

Pointer out-parameters (`bool *ok`, `int *x`) are left out of the call and read after it, in
parameter order:

```goose
let n = qt::val("ff").toInt(16);         // QString::toInt(bool *ok, int base): ok left out
if !qt::out_bool(0) { print("not a number"); }
color.getRgb();                          // four int * out-parameters
let r = qt::out_int(0);                  // out_count, out_bool, out_int, out_f64
```

(The `qt::val("ff")` value above should be freed in real code; see [Values](values.md).)

## Finding and inspecting objects

```goose
let ok_button = qt::find_child(dialog, "okButton");                 // by objectName, at any depth
let edit = qt::find_child(form, "name", "QLineEdit");               // and class
qt::class_name(o);                       // "QPushButton"
qt::inherits(o, "QAbstractButton");      // true
qt::describe(o);                         // JSON: properties, signals, methods, constructors
qt::describe_class("QSlider");           // the same, for a class
qt::class_count(); qt::class_at(0);      // every bound class
qt::stats();                             // JSON about this libqtc: modules, counts
```

`describe` works on QML objects too, which is the quickest way to see what a QML item offers
from Goose.

## What is not bound

qtc binds what it can make safe; [qtc's coverage](https://github.com/PXblaZe/qtc/blob/main/docs/COVERAGE.md) lists by module
what is in and why the rest is out (raw pointers to non-QObject data, functions taking
callbacks, APIs that hand over ownership in ways that cannot be checked). With a default,
LGPL-only libqtc, the GPL-3.0-only modules' functions are in their module files but fail with
`qt::ERR_NOT_FOUND`; see [Build and install](build-and-install.md#licensing).
