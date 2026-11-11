"""Three misuses, one per run: python misuse.py pyside6|pyqt6 deleted|range|qtbug"""
import sys
binding, case = sys.argv[1], sys.argv[2]
if binding == "pyside6":
    from PySide6.QtGui import QImage
    from PySide6.QtWidgets import QApplication, QComboBox, QLabel, QSpinBox, QWidget
    from shiboken6 import delete
else:
    from PyQt6.QtGui import QImage
    from PyQt6.QtWidgets import QApplication, QComboBox, QLabel, QSpinBox, QWidget
    from PyQt6.sip import delete
app = QApplication([])
try:
    if case == "deleted":            # a child used after its parent was deleted
        w = QWidget(); l = QLabel("x", w); delete(w); l.setText("y")
    elif case == "range":            # an int argument past the C++ type's range
        QSpinBox().setValue(10000000000)
    elif case == "qtbug":            # a call Qt itself crashes on: the combo box's own view, set again
        c = QComboBox(); c.addItem("a"); c.setView(c.view()); c.showPopup(); app.processEvents()
    print("no error reported")
except Exception as e:
    msg = str(e).splitlines()
    print("error: %s: %s" % (type(e).__name__, msg[0][:90] if msg else ""))
