use cxx_qt_build::CxxQtBuilder;

fn main() {
    CxxQtBuilder::new()
        .qt_module("Widgets")
        .files(["src/main.rs", "src/model.rs"])
        .cpp_file("cpp/model_glue.cpp")
        .build();
}
