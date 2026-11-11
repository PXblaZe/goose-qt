# Building interfaces

Qt's widgets are all there, called as in C++. This page covers the patterns a real
application needs; the [form example](../examples/form.goose) and the
[notes sample](../samples/notes/notes.goose) put them together.

## Windows and layouts

A widget without a parent is a window. Layouts arrange children, and adding a widget to a
layout gives it a parent, so Qt deletes it with the window:

```goose
let win = qt::QWidget();
win.setWindowTitle("Sign-up");
let form = qt::QFormLayout(win);           // a layout made with a widget is that widget's layout
let name = qt::QLineEdit();
name.setPlaceholderText("your name");
form.addRow("Name", name);
let row = qt::QHBoxLayout();
row.addWidget(qt::QPushButton("OK"));
row.addStretch();
form.addRow(row);
win.resize(400, 200);
win.show();
```

`QVBoxLayout`, `QHBoxLayout`, `QGridLayout`, `QFormLayout` and `QStackedLayout` work as in
C++, and so do `QSplitter`, `QTabWidget`, `QScrollArea` and `QDockWidget`. Placing a widget
somewhere it cannot go (inside itself, into a second owner that holds it by a plain pointer)
is refused.

Style with Qt style sheets (`win.setStyleSheet("QPushButton { padding: 6px; }")`) or fonts
and palettes as values (`label.setFont(qt::QFont("monospace", 12))`; free the font after).

## Main windows, menus and actions

```goose
let window = qt::QMainWindow();
let file = window.menuBar().addMenu("&File");
let keys = qt::QKeySequence("Ctrl+S");
let save = file.addAction("&Save", keys);          // a QAction
keys.free();
qt::connect(save, "triggered", T_SAVE);
file.addSeparator();

let tools = window.addToolBar("Main");
tools.addAction(save);                             // the same action: one handler for both

let preview = window.menuBar().addMenu("&View").addAction("&Preview");
preview.setCheckable(true);
preview.setChecked(true);

window.setCentralWidget(editor);
window.statusBar().showMessage("ready");
```

Actions are objects like any other: `save.trigger()` does what clicking it does (handy in
tests), `save.setEnabled(false)` greys out the menu entry and the toolbar button together.

## Item views and models

The quickest lists and tables are the item widgets:

```goose
let list = qt::QListWidget();
list.addItem("first");
list.addItem("second");
qt::connect(list, "currentRowChanged", T_ROW);     // ev.i0: the row
list.setRowHidden(1, true);
```

Rows of an item widget are reached through its model, which is a `QObject`:

```goose
let model = list.model_obj();
let ix = qt::index(model, 0, 0);                   // a QModelIndex value
let text = qt::val("renamed");
model.setData(ix, text);
let shown = model.data(ix);                        // a QVariant value
text.free(); ix.free(); shown.free();
model.removeRow(1);
```

(`QListWidgetItem` and `QTreeWidgetItem` pointers are not bound: they are not `QObject`s and
Qt deletes them behind your back. The model calls reach the same data safely.)

For data that lives in your program, write the model in Goose by subclassing
`QAbstractTableModel` or `QAbstractListModel`, and put a `QSortFilterProxyModel` in front for
sorting and filtering: see [Subclassing](subclassing.md) and the
[million sample](../samples/million/million.goose), which serves a million rows this way.
`QStandardItemModel`, `QStringListModel` and `QFileSystemModel` are bound too.

## Dialogs

The static helpers work and block until the user answers, as in C++:

```goose
let path = qt::QFileDialog_getOpenFileName(window, "Open", "", "Notes (*.json)");
let ok = qt::QMessageBox_question(window, "Quit", "Discard the changes?");
```

While a modal dialog is open, Qt keeps running (painting, input, timers), and the events
queued for you meanwhile are waiting for your loop when the call returns. For a dialog that
does not block your code, make it, connect its `finished` signal, and `open()` it.

## Screenshots

```goose
let pm = win.grab();                 // a QPixmap value
pm.save("window.png");
pm.free();
```

`grab()` also forces a widget to paint, which is how offscreen self-tests make painting
happen. For tests there is `qt::test_grab(w, "file.png")`; see [Testing](testing.md).

## Many widgets, fast

Creating, laying out and destroying widgets costs what it costs in C++ plus about half a
microsecond per call. Where a program needs thousands of rows or items, a model beats
thousands of widgets, in Goose as in C++: the million sample scrolls 385 pages a second
because the view asks only for the cells it shows.
