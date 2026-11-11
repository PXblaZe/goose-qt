#pragma once
// Making the Rust model and handing it to a proxy (defined in model_glue.cpp: the model's header
// includes this one).
#include <QtCore/QSortFilterProxyModel>
#include <memory>

class BenchModel;
namespace qtbench {
std::unique_ptr<BenchModel> new_model();
void set_source(QSortFilterProxyModel &p, BenchModel &m);
}  // namespace qtbench
