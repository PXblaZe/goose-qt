// The misuse probes, one per run: misuse CASE (see run.py for the list)
#include <QtWidgets/QApplication>
#include <QtWidgets/QComboBox>
#include <QtWidgets/QLabel>
#include <QtWidgets/QLineEdit>
#include <QtWidgets/QPushButton>
#include <QtWidgets/QSpinBox>
#include <QtWidgets/QTableWidget>
#include <QtGui/QStandardItemModel>
#include <cstdio>
#include <cstring>
#include <thread>
int main(int argc, char **argv) {
    const char *c = argv[1];
    if (!std::strcmp(c, "before_app")) { QLabel l("x"); l.show(); std::puts("no error reported"); return 0; }
    QApplication app(argc, argv);
    if (!std::strcmp(c, "deleted")) { auto *w = new QWidget; auto *l = new QLabel("x", w); delete w; l->setText("y"); }
    if (!std::strcmp(c, "deleted_self")) { auto *l = new QLabel("x"); delete l; l->setText("y"); }
    if (!std::strcmp(c, "double_delete")) { auto *l = new QLabel("x"); delete l; delete l; }
    if (!std::strcmp(c, "stale_index")) { QStandardItemModel m(2, 1); QModelIndex i = m.index(1, 0); m.clear(); m.setData(i, "b"); }
    if (!std::strcmp(c, "held_deleted")) {
        QTableWidget t(2, 2); auto *b = new QPushButton("x"); t.setCellWidget(0, 0, b); t.show(); app.processEvents();
        delete b; t.resize(400, 300); app.processEvents();
    }
    if (!std::strcmp(c, "null")) { QComboBox cb; cb.lineEdit()->setText("x"); }   // not editable: no line edit
    if (!std::strcmp(c, "range")) { QSpinBox s; long long big = 10000000000LL; s.setValue(int(big)); }   // narrowed silently
    if (!std::strcmp(c, "wrong_thread")) {
        QLabel l("x"); l.show();
        std::thread th([&] { for (int i = 0; i < 1000; i++) l.setText(QString::number(i)); });
        for (int i = 0; i < 1000; i++) app.processEvents();
        th.join();
    }
    if (!std::strcmp(c, "qtbug")) { QComboBox cb; cb.addItem("a"); cb.setView(cb.view()); cb.showPopup(); app.processEvents(); }
    std::puts("no error reported");
}
