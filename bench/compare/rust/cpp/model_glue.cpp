#include "qtbench/src/model.cxxqt.h"

namespace qtbench {
std::unique_ptr<BenchModel> new_model() { return std::make_unique<BenchModel>(); }
void set_source(QSortFilterProxyModel &p, BenchModel &m) { p.setSourceModel(&m); }
}  // namespace qtbench
