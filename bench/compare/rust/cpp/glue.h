// The C++ a cxx-qt program writes for what cxx cannot bind by declaration: constructors (cxx
// calls no constructors), QApplication's argc/argv, and casts between Qt classes. Everything
// the benchmark measures is a Rust call through a cxx bridge into Qt.
#pragma once
#include <QtCore/QAbstractTableModel>
#include <QtCore/QObject>
#include <QtCore/QSortFilterProxyModel>
#include <QtGui/QImage>
#include <QtGui/QPainter>
#include <QtWidgets/QApplication>
#include <QtGui/QStandardItemModel>
#include <QtWidgets/QComboBox>
#include <QtWidgets/QLineEdit>
#include <QtWidgets/QTableWidget>
#include <QtWidgets/QGridLayout>
#include <QtWidgets/QLabel>
#include <QtWidgets/QPushButton>
#include <QtWidgets/QSlider>
#include <QtWidgets/QWidget>
#include <memory>

namespace qtbench {
inline std::unique_ptr<QApplication> new_app() {
    static int argc = 1;
    static char arg0[] = "bench";
    static char *argv[] = {arg0, nullptr};
    return std::make_unique<QApplication>(argc, argv);
}
inline void process_events() { QCoreApplication::processEvents(); }
inline std::unique_ptr<QLabel> new_label() { return std::make_unique<QLabel>(); }
inline std::unique_ptr<QLabel> new_label_text(const QString &s) { return std::make_unique<QLabel>(s); }
inline std::unique_ptr<QSlider> new_slider() { return std::make_unique<QSlider>(); }
inline std::unique_ptr<QPushButton> new_button(const QString &s) { return std::make_unique<QPushButton>(s); }
inline std::unique_ptr<QObject> new_object() { return std::make_unique<QObject>(); }
inline std::unique_ptr<QWidget> new_widget() { return std::make_unique<QWidget>(); }
inline std::unique_ptr<QComboBox> new_combo() { return std::make_unique<QComboBox>(); }
inline std::unique_ptr<QSortFilterProxyModel> new_proxy() { return std::make_unique<QSortFilterProxyModel>(); }
inline std::unique_ptr<QPainter> new_painter(QImage &img) { return std::make_unique<QPainter>(&img); }
// a layout made inside its widget: Qt owns it
inline QGridLayout *new_grid(QWidget &parent) { return new QGridLayout(&parent); }
inline void grid_add(QGridLayout &g, QPushButton *b, int row, int col) { g.addWidget(b, row, col); }
inline void label_set_parent(QLabel &l, QWidget &parent) { l.setParent(&parent); }
inline int proxy_rows(const QSortFilterProxyModel &p) { return p.rowCount(); }
inline void show(QWidget &w) { w.show(); }
inline void grab(QWidget &w) { (void)w.grab(); }
inline void show_label(QLabel &w) { w.show(); }
inline void grab_label(QLabel &w) { (void)w.grab(); }
// for the misuse probes
inline std::unique_ptr<QStandardItemModel> new_item_model(int rows, int cols) { return std::make_unique<QStandardItemModel>(rows, cols); }
inline std::unique_ptr<QTableWidget> new_table(int rows, int cols) { return std::make_unique<QTableWidget>(rows, cols); }
inline void show_table(QTableWidget &t) { t.show(); }
inline void resize_table(QTableWidget &t, int w, int h) { t.resize(w, h); }
inline QWidget *button_as_widget(QPushButton *b) { return b; }
}  // namespace qtbench
