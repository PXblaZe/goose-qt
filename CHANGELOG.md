# Changelog

## 1.0.0 — 2026-11-10

The first release, for qtc 1.0.0 on Qt 6.12 LTS.

- `api.goose`, generated from qtc's manifest: 9,081 method functions (UFCS on
  `qt::Obj` and `qt::Val`), 1,399 constructors, 8,855 enum values in 388 scopes
  (`qt::Qt.AlignLeft`).
- `qt.goose`: init and shutdown, the event loop, signals, watches, timers,
  posts, values, lists and maps, the generic call, drawing, test input.
- Tests run with the JIT and natively; examples that test themselves.
