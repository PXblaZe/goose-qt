# Changelog

## 1.1.0 — unreleased

For qtc 1.1.0.

- `extra.goose`: overridable objects through one exported handler
  (`goose_qt_override`, called through the C trampoline in
  `include/goose_qt.h`), runtime-defined classes, futures and promises for Goose
  worker threads, queued calls and worker objects, and the graphics API (Qt's
  RHI as `qt::Gpu` handles, Qt Quick's graphics API, native interop).
- `api.goose` regenerated: 9,512 method functions, 1,481 constructors, 9,148
  enum values in 405 scopes (QRhiWidget among the new classes).
- Return types of generated functions no longer change when newly bound classes
  disagree: the generator keeps the type the published `api.goose` had and reaches
  the other classes' results through the typed variants. Without this, six
  functions would have changed to `qt::Val` (`name`, `host`, `query`, `message`,
  `filter`, `scope`); `QCoapOption`'s `name()` is `name_int()`.
- Tests `t07_overrides`, `t08_futures` (native) and `t09_graphics`.

## 1.0.0 — 2026-11-10

The first release, for qtc 1.0.0 on Qt 6.12 LTS.

- `api.goose`, generated from qtc's manifest: 9,081 method functions (UFCS on
  `qt::Obj` and `qt::Val`), 1,399 constructors, 8,855 enum values in 388 scopes
  (`qt::Qt.AlignLeft`).
- `qt.goose`: init and shutdown, the event loop, signals, watches, timers,
  posts, values, lists and maps, the generic call, drawing, test input.
- Tests run with the JIT and natively; examples that test themselves.
