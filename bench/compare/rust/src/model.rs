// The model written in Rust: a cxx-qt QObject whose base class is QAbstractTableModel, with
// rowCount, columnCount and data overridden in Rust.

#[cxx_qt::bridge]
pub mod ffi {
    unsafe extern "C++" {
        include!(<QtCore/QAbstractTableModel>);
        type QAbstractTableModel;
        include!("cxx-qt-lib/qvariant.h");
        type QVariant = cxx_qt_lib::QVariant;
        include!("cxx-qt-lib/qmodelindex.h");
        type QModelIndex = cxx_qt_lib::QModelIndex;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[base = QAbstractTableModel]
        type BenchModel = super::BenchModelRust;

        #[cxx_override]
        #[cxx_name = "rowCount"]
        fn row_count(self: &BenchModel, parent: &QModelIndex) -> i32;
        #[cxx_override]
        #[cxx_name = "columnCount"]
        fn column_count(self: &BenchModel, parent: &QModelIndex) -> i32;
        #[cxx_override]
        fn data(self: &BenchModel, index: &QModelIndex, role: i32) -> QVariant;
    }

    unsafe extern "C++" {
        include!("qtbench/cpp/model_glue.h");
        type QSortFilterProxyModel = crate::qt::QSortFilterProxyModel;
        #[namespace = "qtbench"]
        fn new_model() -> UniquePtr<BenchModel>;
        #[namespace = "qtbench"]
        fn set_source(proxy: Pin<&mut QSortFilterProxyModel>, model: Pin<&mut BenchModel>);
    }
}

use cxx_qt_lib::{QModelIndex, QString, QVariant};

pub const ROWS: i32 = 1_000_000;

#[derive(Default)]
pub struct BenchModelRust;

impl ffi::BenchModel {
    fn row_count(&self, parent: &QModelIndex) -> i32 {
        if parent.is_valid() { 0 } else { ROWS }
    }
    fn column_count(&self, parent: &QModelIndex) -> i32 {
        if parent.is_valid() { 0 } else { 1 }
    }
    fn data(&self, index: &QModelIndex, role: i32) -> QVariant {
        if role == 0 {
            // Qt::DisplayRole
            QVariant::from(&QString::from(&format!("item {}", index.row())))
        } else {
            QVariant::default()
        }
    }
}
