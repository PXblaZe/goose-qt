# Values

`qt::Val` is a handle on a Qt value: a `QColor`, `QFont`, `QRect`, `QImage`, `QDateTime`, a
`QVariant`, a list or a map. Underneath, each is a `QVariant` qtc keeps for you. Values are
how anything that is not a `QObject` crosses between Goose and Qt.

## Small values as structs

Points, sizes, rectangles, lines, margins and colors also exist as plain Goose structs,
held by your program with no handle and nothing to free: `qt::Point`, `qt::PointF`,
`qt::Size`, `qt::SizeF`, `qt::Rect`, `qt::RectF`, `qt::Line`, `qt::LineF`, `qt::Margins`,
`qt::MarginsF` and `qt::Color` (`values.goose`, from qtc's `qtc_inline.h`). They have the
Qt type's own layout, their methods call Qt directly, and they cost a few nanoseconds where
a `qt::Val` costs over a hundred:

```goose
var r = qt::rect(0, 0, 640, 480);          // constructors: the lowercase type name
r.moveTo(10, 10);                          // methods that change it work in place (a var)
let w = r.width();
let c = qt::color(255, 128, 0);            // qt::Color
let h = qt::color_fromHsv(120, 255, 255);  // static methods: lowercase name, underscore, method
win.setGeometry(r);                        // object methods take them
win.move(qt::point(100, 100));
let g = qt::to_rect(win.geometry());       // a qt::Val result as a struct (to_point, to_color, ...)
let v = c.to_val();                        // and a struct as a qt::Val, for anything else
```

The geometry structs' fields are Qt's own, and may be read and set (`r.x1`, `p.xp`; a
`Rect` keeps its far corner, `x2 = x + width - 1`); a `Color` is opaque. The checks are the
usual ones: an integer that does not fit Qt's `int` is `qt::ERR_OUT_OF_RANGE`, and a
`Color` whose fields your program changed into something that is not a color is
`qt::ERR_INVALID_ARG`, not undefined behaviour in Qt. Object methods that return these
types still return a `qt::Val`; `qt::to_rect` and its siblings convert it.

## Making values

```goose
let n = qt::val(42);                       // from Goose: bool, i64, f64, text, or an Obj
let s = qt::val("hello");
let b = qt::bytes_val(raw);                // a QByteArray
let red = qt::QColor(255, 0, 0, 255);      // a Qt value type's constructor
let r = qt::QRect(0, 0, 640, 480);
let d = qt::new_value("QDate");            // by type name, default-constructed
let j = qt::from_json("{\"a\": [1, 2, 3]}"); // a map holding a list
```

Methods called on a value work on it in place, as on an object:

```goose
red.setGreen(128);
let name = red.name();                     // "#ff8000"
let year = qt::QDateTime_currentDateTime().date().year();   // two values made here: see below
```

## Freeing values

Every value a function returns is a new handle on its own copy, and it is yours: free it
when you are done.

```goose
let geo = win.prop<qt::Val>("geometry");
let w = geo.width_int();               // QRect::width; width() alone is a Val (see Calling Qt)
geo.free();
```

Freeing twice, or using a freed value, is an error (`qt::ERR_STALE_HANDLE`), never a crash.
A chain like `QDateTime_currentDateTime().date().year()` leaves two values unfreed: fine in a
script, a leak in a loop. Name the intermediate values when the code runs more than once.

`qt::live_values()` counts the values alive, so a test can check that a piece of code frees
everything it makes:

```goose
let before = qt::live_values();
do_the_work();
if qt::live_values() != before { print("leaked ", qt::live_values() - before, " values"); }
```

`qt::shutdown()` frees whatever is left.

## Reading values

| Function | Gives |
|---|---|
| `qt::kind(v)` | `qt::T_BOOL`, `T_INT`, `T_UINT`, `T_DOUBLE`, `T_STR`, `T_BYTES`, `T_OBJ`, `T_LIST`, `T_MAP`, `T_VALUE` (any other Qt type), `T_NULL` |
| `qt::type_name(v)` | Qt's name for the type: `"qlonglong"` (what `qt::val(42)` makes), `"QString"`, `"QColor"`, `"QVariantList"` |
| `v.to_bool()`, `to_int()`, `to_f64()`, `to_str()` | the value converted as `QVariant` would |
| `v.to_obj()` | the object a value refers to (a handle, still checked when used) |
| `qt::convert(v, "QString")` | a new value of another type |
| `qt::equal(a, b)` | Qt's equality |
| `qt::json(v)` | JSON text, for lists, maps and what they hold |
| `qt::describe(v)` | a readable description, for debugging |
| `qt::clone(v)` | an independent copy |

`print` and `str` know both handle types, so `print(v)` and `print(label)` show what they are.

## Lists and maps

```goose
let list = qt::new_list();
let n = qt::val(1);
qt::list_append(list, n);              // the list keeps its own copy: n is still yours
n.free();
qt::list_append(list, label);          // an object, stored as its handle
let first = qt::list_get(list, 0);     // a new value: free it
qt::list_len(list); qt::list_set(list, 0, v); qt::list_remove(list, 0); qt::list_clear(list);

let m = qt::new_map();
qt::map_set(m, "title", s);            // copies s
let t = qt::map_get(m, "title");       // a new value: free it
qt::map_has(m, "title"); qt::map_remove(m, "title"); qt::map_len(m);
let keys = qt::map_keys(m);            // a list of the keys
```

Getting returns a copy, so changing an element is get, change, set back:

```goose
let note = qt::list_get(notes, i);
let body = qt::val(text);
qt::map_set(note, "body", body);
qt::list_set(notes, i, note);
body.free();
note.free();
```

Lists and maps are `QVariantList` and `QVariantMap`, which is what Qt APIs taking a
`QVariant` expect, what QML sees as JavaScript arrays and objects, and what JSON maps onto.
Objects inside them are kept as handles, so a list may outlive an object it mentions without
holding a dangling pointer.

## JSON

`qt::from_json(text)` parses JSON into lists, maps, strings, numbers, booleans and nulls;
`qt::json(v)` writes them back. Invalid JSON gives a null handle and an error. Together with
Goose's `read_file` and `write_file_atomic`, that is a complete file format:

```goose
write_file_atomic(path, qt::json(notes));        // a crash mid-save leaves the old file

var text: u8[>..] = [];
if read_file(path, text) {
    let loaded = qt::from_json(text);
    if loaded.h != 0 && qt::type_name(loaded) == "QVariantList" { ... }
}
```

The [notes sample](../samples/notes/notes.goose) keeps all its data this way.

## Images

`QImage` is a value, so the drawing calls can paint into it ([Drawing](drawing.md)) and its
methods read and write pixels:

```goose
let img = qt::QImage(256, 256, qt::QImage.Format_ARGB32);
img.fill(0xff000000);
let px = img.pixelColor(10, 10);        // a QColor value
img.save("out.png");
let back = qt::QImage();
back.loadFromData(ppm_bytes, "PPM");    // decode bytes made in Goose
let pm = qt::QPixmap_fromImage(back);   // for a QLabel: label.setPixmap(pm)
```

An image larger than the allocation limit (256 MiB in one go by default) is refused rather
than allocated, since Qt allocates large images and the system kills the process when they
are touched; `qt::set_alloc_limit(bytes)` raises the limit.
