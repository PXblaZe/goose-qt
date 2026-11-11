"""The comparison benchmark, in Python with PySide6 or PyQt6. Same operations and counts as every
other implementation (see ../README.md).

    python bench.py pyside6|pyqt6             the operations, one "RESULT <name> <value> <unit>" line each
    python bench.py pyside6|pyqt6 --startup   start Qt, show a label, paint it once, exit
"""
import sys
import time

binding = sys.argv[1]
if binding == "pyside6":
    from PySide6.QtCore import QAbstractTableModel, QModelIndex, QObject, QSortFilterProxyModel, Qt
    from PySide6.QtGui import QColor, QImage, QPainter
    from PySide6.QtWidgets import QApplication, QGridLayout, QLabel, QPushButton, QSlider, QWidget
    from shiboken6 import delete
else:
    from PyQt6.QtCore import QAbstractTableModel, QModelIndex, QObject, QSortFilterProxyModel, Qt
    from PyQt6.QtGui import QColor, QImage, QPainter
    from PyQt6.QtWidgets import QApplication, QGridLayout, QLabel, QPushButton, QSlider, QWidget
    from PyQt6.sip import delete

N, N_SIGNAL, N_OBJECTS, ROWS, LINES, BUTTONS = 200000, 100000, 50000, 1000000, 100000, 2000
DISPLAY = Qt.ItemDataRole.DisplayRole


def result(name, v, unit):
    print("RESULT %s %.3f %s" % (name, v, unit), flush=True)


class Model(QAbstractTableModel):
    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else ROWS

    def columnCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else 1

    def data(self, index, role=DISPLAY):
        if role == DISPLAY:
            return "item %d" % index.row()
        return None


def main():
    app = QApplication(sys.argv[:1])
    if "--startup" in sys.argv:
        hello = QLabel("hello")
        hello.show()
        hello.grab()
        return 0
    clock = time.perf_counter_ns
    label = QLabel()
    slider = QSlider()
    slider.setMaximum(1 << 30)
    button = QPushButton("b")
    total = 0
    acc = 0

    for i in range(N // 10):
        label.setText("hello")
    t = clock()
    for i in range(N):
        label.setText("hello")
    result("set_text", (clock() - t) / N, "ns")

    t = clock()
    for i in range(N):
        total += len(label.text())
    result("get_text", (clock() - t) / N, "ns")

    t = clock()
    for i in range(N):
        slider.setValue(i)
    result("set_value", (clock() - t) / N, "ns")

    t = clock()
    for i in range(N):
        acc += slider.value()
    result("get_value", (clock() - t) / N, "ns")

    t = clock()
    for i in range(N):
        label.setProperty("text", "hello")
    result("set_property", (clock() - t) / N, "ns")

    clicks = [0]

    def on_click():
        clicks[0] += 1

    button.clicked.connect(on_click)
    t = clock()
    for i in range(N_SIGNAL):
        button.click()
    result("signal", (clock() - t) / N_SIGNAL, "ns")

    t = clock()
    for i in range(N):
        acc += QColor(255, 0, 0).red()
    result("value_type", (clock() - t) / N, "ns")

    t = clock()
    for i in range(N_OBJECTS):
        o = QObject()      # no parent: the C++ object goes with the Python one
        del o
    result("object_churn", (clock() - t) / N_OBJECTS, "ns")

    model = Model()
    proxy = QSortFilterProxyModel()
    proxy.setSourceModel(model)
    t = clock()
    proxy.setFilterFixedString("4242")
    matches = proxy.rowCount()
    result("model_filter", (clock() - t) / 1e6, "ms")
    result("model_matches", matches, "rows")

    img = QImage(1024, 1024, QImage.Format.Format_ARGB32)
    img.fill(0xffffffff)
    t = clock()
    p = QPainter(img)
    for i in range(LINES):
        x, y = (i * 7) % 1000, (i * 13) % 1000
        p.drawLine(x, y, x + 8, y + 5)
    p.end()
    result("paint_lines", (clock() - t) / 1e6, "ms")

    t = clock()
    win = QWidget()
    grid = QGridLayout(win)
    for i in range(BUTTONS):
        grid.addWidget(QPushButton("b %d" % i), i // 40, i % 40)
    win.show()
    win.grab()
    delete(win)            # at once, as C++'s delete
    del win, grid
    app.processEvents()
    result("widgets", (clock() - t) / 1e6, "ms")

    return 0 if clicks[0] == N_SIGNAL and total > 0 and acc > 0 else 1


sys.exit(main())
