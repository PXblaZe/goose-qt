// Three misuses, one per run: misuse deleted|range|qtbug
#include <QtWidgets/QApplication>
#include <QtWidgets/QComboBox>
#include <QtWidgets/QLabel>
#include <QtWidgets/QSpinBox>
#include <cstdio>
#include <cstring>
int main(int argc, char **argv) {
    QApplication app(argc, argv);
    const char *c = argv[1];
    if (!std::strcmp(c, "deleted")) { auto *w = new QWidget; auto *l = new QLabel("x", w); delete w; l->setText("y"); }
    if (!std::strcmp(c, "range")) { QSpinBox s; long long big = 10000000000LL; s.setValue(int(big)); }   // narrowed silently
    if (!std::strcmp(c, "qtbug")) { QComboBox cb; cb.addItem("a"); cb.setView(cb.view()); cb.showPopup(); app.processEvents(); }
    std::puts("no error reported");
}
