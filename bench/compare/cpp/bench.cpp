// The comparison benchmark, in C++ calling Qt directly: the baseline the bindings are measured
// against. Same operations and counts as every other implementation (see ../README.md).
//   bench            the operations, one "RESULT <name> <value> <unit>" line each
//   bench --startup  start Qt, show a label, paint it once, exit (the runner times it)
#include <QtCore/QAbstractTableModel>
#include <QtCore/QElapsedTimer>
#include <QtCore/QSortFilterProxyModel>
#include <QtGui/QColor>
#include <QtGui/QImage>
#include <QtGui/QPainter>
#include <QtWidgets/QApplication>
#include <QtWidgets/QGridLayout>
#include <QtWidgets/QLabel>
#include <QtWidgets/QPushButton>
#include <QtWidgets/QSlider>

#include <cstdio>
#include <cstring>

static const int N = 200000;          // micro operations
static const int N_SIGNAL = 100000;
static const int N_OBJECTS = 50000;
static const int ROWS = 1000000;      // model rows
static const int LINES = 100000;      // painted lines
static const int BUTTONS = 2000;      // widgets in a grid

static QElapsedTimer timer;
static void result(const char *name, double v, const char *unit) { std::printf("RESULT %s %.3f %s\n", name, v, unit); }
static double ns_per(qint64 t0, int n) { return double(timer.nsecsElapsed() - t0) / n; }
static double ms_since(qint64 t0) { return double(timer.nsecsElapsed() - t0) / 1e6; }

class Model : public QAbstractTableModel {
public:
    int rowCount(const QModelIndex &parent) const override { return parent.isValid() ? 0 : ROWS; }
    int columnCount(const QModelIndex &parent) const override { return parent.isValid() ? 0 : 1; }
    QVariant data(const QModelIndex &index, int role) const override {
        if (role == Qt::DisplayRole) return QStringLiteral("item %1").arg(index.row());
        return QVariant();
    }
};

int main(int argc, char **argv) {
    QApplication app(argc, argv);
    if (argc > 1 && std::strcmp(argv[1], "--startup") == 0) {
        QLabel hello(QStringLiteral("hello"));
        hello.show();
        hello.grab();
        return 0;
    }
    timer.start();
    QLabel label;
    QSlider slider;
    slider.setMaximum(1 << 30);
    QPushButton button(QStringLiteral("b"));
    qint64 t;

    for (int i = 0; i < N / 10; i++) label.setText(QStringLiteral("hello"));
    t = timer.nsecsElapsed();
    for (int i = 0; i < N; i++) label.setText(QStringLiteral("hello"));
    result("set_text", ns_per(t, N), "ns");

    qsizetype total = 0;
    t = timer.nsecsElapsed();
    for (int i = 0; i < N; i++) total += label.text().size();
    result("get_text", ns_per(t, N), "ns");

    t = timer.nsecsElapsed();
    for (int i = 0; i < N; i++) slider.setValue(i);
    result("set_value", ns_per(t, N), "ns");

    qint64 sum = 0;
    t = timer.nsecsElapsed();
    for (int i = 0; i < N; i++) sum += slider.value();
    result("get_value", ns_per(t, N), "ns");

    t = timer.nsecsElapsed();
    for (int i = 0; i < N; i++) label.setProperty("text", QStringLiteral("hello"));
    result("set_property", ns_per(t, N), "ns");

    int clicks = 0;
    QObject::connect(&button, &QPushButton::clicked, [&] { clicks++; });
    t = timer.nsecsElapsed();
    for (int i = 0; i < N_SIGNAL; i++) button.click();
    result("signal", ns_per(t, N_SIGNAL), "ns");

    t = timer.nsecsElapsed();
    for (int i = 0; i < N; i++) {
        QColor c(255, 0, 0);
        sum += c.red();
    }
    result("value_type", ns_per(t, N), "ns");

    t = timer.nsecsElapsed();
    for (int i = 0; i < N_OBJECTS; i++) delete new QObject;
    result("object_churn", ns_per(t, N_OBJECTS), "ns");

    // a model written in the language, filtered through QSortFilterProxyModel
    Model model;
    QSortFilterProxyModel proxy;
    proxy.setSourceModel(&model);
    t = timer.nsecsElapsed();
    proxy.setFilterFixedString(QStringLiteral("4242"));
    int matches = proxy.rowCount();
    result("model_filter", ms_since(t), "ms");
    result("model_matches", matches, "rows");

    QImage img(1024, 1024, QImage::Format_ARGB32);
    img.fill(Qt::white);
    t = timer.nsecsElapsed();
    {
        QPainter p(&img);
        for (int i = 0; i < LINES; i++) {
            int x = (i * 7) % 1000, y = (i * 13) % 1000;
            p.drawLine(x, y, x + 8, y + 5);
        }
    }
    result("paint_lines", ms_since(t), "ms");

    t = timer.nsecsElapsed();
    {
        auto *win = new QWidget;
        auto *grid = new QGridLayout(win);
        for (int i = 0; i < BUTTONS; i++)
            grid->addWidget(new QPushButton(QStringLiteral("b %1").arg(i)), i / 40, i % 40);
        win->show();
        win->grab();
        delete win;
        QCoreApplication::processEvents();
    }
    result("widgets", ms_since(t), "ms");

    if (clicks != N_SIGNAL || total == 0 || sum == 0) return 1;
    return 0;
}
