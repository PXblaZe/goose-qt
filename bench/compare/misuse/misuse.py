"""The misuse probes, one per run: python misuse.py pyside6|pyqt6 CASE (see run.py)"""
import sys
import threading
binding, case = sys.argv[1], sys.argv[2]
if binding == "pyside6":
    from PySide6.QtGui import QStandardItemModel
    from PySide6.QtWidgets import (QApplication, QComboBox, QLabel, QPushButton, QSpinBox,
                                   QTableWidget, QWidget)
    from shiboken6 import delete
else:
    from PyQt6.QtGui import QStandardItemModel
    from PyQt6.QtWidgets import (QApplication, QComboBox, QLabel, QPushButton, QSpinBox,
                                 QTableWidget, QWidget)
    from PyQt6.sip import delete
try:
    if case == "before_app":         # a widget made before the application
        QLabel("x").show()
    else:
        app = QApplication([])
    if case == "deleted":            # a child used after its parent was deleted
        w = QWidget(); l = QLabel("x", w); delete(w); l.setText("y")
    elif case == "deleted_self":     # an object used after it was deleted
        l = QLabel("x"); delete(l); l.setText("y")
    elif case == "double_delete":    # an object deleted twice
        l = QLabel("x"); delete(l); delete(l)
    elif case == "stale_index":      # a model index kept across the model's clear()
        m = QStandardItemModel(2, 1); i = m.index(1, 0); m.clear(); m.setData(i, "b")
    elif case == "held_deleted":     # a widget deleted while a table shows it
        t = QTableWidget(2, 2); b = QPushButton("x"); t.setCellWidget(0, 0, b); t.show(); app.processEvents()
        delete(b); t.resize(400, 300); app.processEvents()
    elif case == "null":             # a method on the line edit a non-editable combo box does not have
        QComboBox().lineEdit().setText("x")
    elif case == "range":            # an int argument past the C++ type's range
        QSpinBox().setValue(10000000000)
    elif case == "wrong_thread":     # a widget changed from another thread
        l = QLabel("x"); l.show()
        th = threading.Thread(target=lambda: [l.setText(str(i)) for i in range(1000)])
        th.start()
        for _ in range(1000): app.processEvents()
        th.join()
    elif case == "qtbug":            # a call Qt itself crashes on: the combo box's own view, set again
        c = QComboBox(); c.addItem("a"); c.setView(c.view()); c.showPopup(); app.processEvents()
    print("no error reported")
except Exception as e:
    msg = str(e).splitlines()
    print("error: %s: %s" % (type(e).__name__, msg[0][:90] if msg else ""))
