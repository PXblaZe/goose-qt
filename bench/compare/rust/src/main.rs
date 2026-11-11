// The comparison benchmark in Rust, through cxx-qt (KDAB's Rust/Qt bridge, cxx-qt and cxx-qt-lib
// 0.10): the same operations and counts as every other implementation (see ../README.md).
//   qtbench                 the operations, one "RESULT <name> <value> <unit>" line each
//   qtbench --startup       start Qt, show a label, paint it once, exit (the runner times it)
//   qtbench --misuse CASE   one of the misuse probes (../misuse)
//
// cxx-qt-lib has Qt's value types (QString, QColor, QImage, QPainter...) but no widgets: a cxx-qt
// program declares the widget methods it calls in a bridge, as below, and writes the few C++
// helpers cxx cannot declare (constructors, casts) itself (cpp/glue.h).

mod model;

use core::pin::Pin;
use cxx_qt_lib::{QColor, QImage, QImageFormat, QLine, QModelIndex, QPoint, QString, QVariant};
use std::ffi::CString;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Instant;

#[cxx_qt::bridge]
pub mod qt {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        include!("cxx-qt-lib/qvariant.h");
        type QVariant = cxx_qt_lib::QVariant;
        include!("cxx-qt-lib/qimage.h");
        type QImage = cxx_qt_lib::QImage;
        include!("cxx-qt-lib/qpainter.h");
        type QPainter = cxx_qt_lib::QPainter;

        include!("qtbench/cpp/glue.h");
        type QApplication;
        type QObject;
        type QWidget;
        type QLabel;
        type QSlider;
        type QPushButton;
        type QComboBox;
        type QAbstractItemView;
        type QGridLayout;
        type QSortFilterProxyModel;

        #[rust_name = "set_text"]
        fn setText(self: Pin<&mut QLabel>, text: &QString);
        fn text(self: &QLabel) -> QString;
        #[rust_name = "set_property"]
        unsafe fn setProperty(self: Pin<&mut QLabel>, name: *const c_char, value: &QVariant) -> bool;
        #[rust_name = "set_value"]
        fn setValue(self: Pin<&mut QSlider>, value: i32);
        fn value(self: &QSlider) -> i32;
        #[rust_name = "set_maximum"]
        fn setMaximum(self: Pin<&mut QSlider>, value: i32);
        fn click(self: Pin<&mut QPushButton>);
        fn view(self: &QComboBox) -> *mut QAbstractItemView;
        #[rust_name = "set_view"]
        unsafe fn setView(self: Pin<&mut QComboBox>, view: *mut QAbstractItemView);
        #[rust_name = "show_popup"]
        fn showPopup(self: Pin<&mut QComboBox>);
        #[rust_name = "set_filter_fixed_string"]
        fn setFilterFixedString(self: Pin<&mut QSortFilterProxyModel>, pattern: &QString);
    }

    #[namespace = "qtbench"]
    unsafe extern "C++" {
        fn new_app() -> UniquePtr<QApplication>;
        fn process_events();
        fn new_label() -> UniquePtr<QLabel>;
        fn new_label_text(text: &QString) -> UniquePtr<QLabel>;
        fn new_slider() -> UniquePtr<QSlider>;
        fn new_button(text: &QString) -> UniquePtr<QPushButton>;
        fn new_object() -> UniquePtr<QObject>;
        fn new_widget() -> UniquePtr<QWidget>;
        fn new_combo() -> UniquePtr<QComboBox>;
        fn new_proxy() -> UniquePtr<QSortFilterProxyModel>;
        fn new_painter(img: Pin<&mut QImage>) -> UniquePtr<QPainter>;
        fn new_grid(parent: Pin<&mut QWidget>) -> *mut QGridLayout;
        unsafe fn grid_add(grid: Pin<&mut QGridLayout>, button: *mut QPushButton, row: i32, col: i32);
        fn label_set_parent(label: Pin<&mut QLabel>, parent: Pin<&mut QWidget>);
        fn proxy_rows(proxy: &QSortFilterProxyModel) -> i32;
        fn show(w: Pin<&mut QWidget>);
        fn grab(w: Pin<&mut QWidget>);
        fn show_label(w: Pin<&mut QLabel>);
        fn grab_label(w: Pin<&mut QLabel>);
    }

    unsafe extern "C++Qt" {
        #[qsignal]
        fn clicked(self: Pin<&mut QPushButton>, checked: bool);
    }
}

const N: u32 = 200_000;
const N_SIGNAL: u32 = 100_000;
const N_OBJECTS: u32 = 50_000;
const LINES: i32 = 100_000;
const BUTTONS: i32 = 2000;

fn result(name: &str, v: f64, unit: &str) {
    println!("RESULT {} {:.3} {}", name, v, unit);
}
fn ns_per(t: Instant, n: u32) -> f64 {
    t.elapsed().as_nanos() as f64 / n as f64
}
fn ms_since(t: Instant) -> f64 {
    t.elapsed().as_nanos() as f64 / 1e6
}

static CLICKS: AtomicU64 = AtomicU64::new(0);

fn misuse(case: &str) -> i32 {
    let _app = qt::new_app();
    match case {
        "deleted" => {
            // a label owned by its parent (Qt deletes it with the parent), reached afterwards
            let mut parent = qt::new_widget();
            let label = qt::new_label().into_raw();
            unsafe {
                qt::label_set_parent(Pin::new_unchecked(&mut *label), parent.pin_mut());
            }
            drop(parent);
            unsafe { Pin::new_unchecked(&mut *label).set_text(&QString::from("x")) };
            println!("no error reported");
        }
        "range" => {
            let mut slider = qt::new_slider();
            let v: i64 = 10_000_000_000;
            slider.pin_mut().set_value(v as i32); // i32 parameter: the value has to be cast
            println!("no error reported (value is now {})", slider.value());
        }
        "qtbug" => {
            let mut combo = qt::new_combo();
            let view = combo.view();
            unsafe { combo.pin_mut().set_view(view) };
            combo.pin_mut().show_popup();
            qt::process_events();
            println!("no error reported");
        }
        _ => return 2,
    }
    0
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() > 2 && args[1] == "--misuse" {
        std::process::exit(misuse(&args[2]));
    }
    let _app = qt::new_app();
    if args.len() > 1 && args[1] == "--startup" {
        let mut hello = qt::new_label_text(&QString::from("hello"));
        qt::show_label(hello.pin_mut());
        qt::grab_label(hello.pin_mut());
        return;
    }
    let mut label = qt::new_label();
    let mut slider = qt::new_slider();
    slider.pin_mut().set_maximum(1 << 30);
    let mut button = qt::new_button(&QString::from("b"));

    let hello = QString::from("hello");
    for _ in 0..N / 10 {
        label.pin_mut().set_text(&QString::from("hello"));
    }
    let t = Instant::now();
    for _ in 0..N {
        label.pin_mut().set_text(&QString::from("hello"));
    }
    result("set_text", ns_per(t, N), "ns");

    let mut total: i64 = 0;
    let t = Instant::now();
    for _ in 0..N {
        total += label.text().len() as i64;
    }
    result("get_text", ns_per(t, N), "ns");

    let t = Instant::now();
    for i in 0..N {
        slider.pin_mut().set_value(i as i32);
    }
    result("set_value", ns_per(t, N), "ns");

    let mut sum: i64 = 0;
    let t = Instant::now();
    for _ in 0..N {
        sum += slider.value() as i64;
    }
    result("get_value", ns_per(t, N), "ns");

    let prop = CString::new("text").unwrap();
    let t = Instant::now();
    for _ in 0..N {
        unsafe { label.pin_mut().set_property(prop.as_ptr(), &QVariant::from(&hello)) };
    }
    result("set_property", ns_per(t, N), "ns");

    let _guard = button.pin_mut().on_clicked(|_, _| {
        CLICKS.fetch_add(1, Ordering::Relaxed);
    });
    let t = Instant::now();
    for _ in 0..N_SIGNAL {
        button.pin_mut().click();
    }
    result("signal", ns_per(t, N_SIGNAL), "ns");

    let t = Instant::now();
    for _ in 0..N {
        let c = QColor::from_rgb(255, 0, 0);
        sum += c.red() as i64;
    }
    result("value_type", ns_per(t, N), "ns");

    let t = Instant::now();
    for _ in 0..N_OBJECTS {
        drop(qt::new_object());
    }
    result("object_churn", ns_per(t, N_OBJECTS), "ns");

    // a model written in the language, filtered through QSortFilterProxyModel
    let mut m = model::ffi::new_model();
    let mut proxy = qt::new_proxy();
    model::ffi::set_source(proxy.pin_mut(), m.pin_mut());
    let t = Instant::now();
    proxy.pin_mut().set_filter_fixed_string(&QString::from("4242"));
    let matches = qt::proxy_rows(&proxy);
    result("model_filter", ms_since(t), "ms");
    result("model_matches", matches as f64, "rows");
    let _ = QModelIndex::default();

    let mut img = QImage::from_width_height_and_format(1024, 1024, QImageFormat::Format_ARGB32);
    img.fill(&QColor::from_rgb(255, 255, 255));
    let t = Instant::now();
    {
        let mut p = qt::new_painter(Pin::new(&mut img));
        for i in 0..LINES {
            let x = (i * 7) % 1000;
            let y = (i * 13) % 1000;
            p.pin_mut().draw_line(&QLine::new(QPoint::new(x, y), QPoint::new(x + 8, y + 5)));
        }
    }
    result("paint_lines", ms_since(t), "ms");

    let t = Instant::now();
    {
        let mut win = qt::new_widget();
        let grid = qt::new_grid(win.pin_mut());
        for i in 0..BUTTONS {
            let b = qt::new_button(&QString::from(&format!("b {}", i))).into_raw();
            unsafe { qt::grid_add(Pin::new_unchecked(&mut *grid), b, i / 40, i % 40) };
        }
        qt::show(win.pin_mut());
        qt::grab(win.pin_mut());
        drop(win);
        qt::process_events();
    }
    result("widgets", ms_since(t), "ms");

    if CLICKS.load(Ordering::Relaxed) != N_SIGNAL as u64 || total == 0 || sum == 0 {
        std::process::exit(1);
    }
}
