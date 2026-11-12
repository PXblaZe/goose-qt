# Build and install

goose-qt is Goose source: programs import it, and nothing of it is compiled ahead of time.
What has to be built is qtc, the C library it loads at run time. The CMake project does both
jobs: it finds or builds qtc, and installs the package so programs find qtc without a library
path.

## Requirements

| | Version |
|---|---|
| Goose | 8 November 2026 or later (`const if`, type arguments in method calls); commit `f4637bfb` is tested |
| Qt | 6.12 LTS, for qtc |
| qtc | 1.0.0 or later (the version whose manifest `api.goose` was generated from) |
| CMake | 3.21 or later, for the CMake route |
| a C compiler | for native builds (Goose uses it), and to build qtc |

## With CMake (recommended)

```sh
# an installed qtc: its prefix and Qt's in CMAKE_PREFIX_PATH
cmake -S goose-qt -B build -DCMAKE_PREFIX_PATH="/opt/qtc;/opt/Qt/6.12.0/gcc_64"
# or build qtc as part of this build, from its source (../qtc is used when it is there)
cmake -S goose-qt -B build -DQTC_SOURCE_DIR=path/to/qtc -DCMAKE_PREFIX_PATH=/opt/Qt/6.12.0/gcc_64

cmake --build build
ctest --test-dir build                  # the tests, examples, samples, and a program run from the install
cmake --install build --prefix /usr/local
```

Programs then import the installed package:

```goose
import qt from "/usr/local/share/goose-qt";
```

| Option | Default | What it does |
|---|---|---|
| `QTC_SOURCE_DIR` | (empty) | qtc's source: build qtc here when no installed one is found (or always, with `GOOSE_QT_BUILD_QTC`); `../qtc` is used when it is there |
| `GOOSE_QT_BUILD_QTC` | `OFF` | build qtc from `QTC_SOURCE_DIR` even when an installed one is found |
| `GOOSE_QT_INSTALL_DIR` | `share/goose-qt` | where under the prefix the package goes |
| `GOOSE_QT_PIN_QTC` | `ON` | write qtc's installed path into the installed `qt.build`; off, programs find qtc on the library path |
| `GOOSE_QT_TESTS` | `ON` | register the tests with ctest (left out when no `goose` is found) |
| `GOOSE_EXECUTABLE` | from `PATH` or `$GOOSE` | the Goose compiler the tests use; configuring checks that it is new enough |

When qtc is built here, its own options apply (`QTC_GPL_MODULES`, `QTC_MODULES`,
`QTC_SHADER_TOOLS` …); its tests and examples are off unless turned on.

| Target | Does |
|---|---|
| `cmake --build build --target uninstall` | removes what the last install put in place |
| `cmake --build build --target goose_qt_api` | regenerates `api.goose` and the module files from qtc's manifest |

| ctest test | Runs |
|---|---|
| `goose_qt_tests` | `test/run.sh`: the suite, JIT and native |
| `goose_qt_examples` | `examples/run.sh`: every example's self-test, and the shared-library example |
| `goose_qt_samples` | `samples/run.sh --quick`: every sample's self-test |
| `goose_qt_installed` | installs into a scratch prefix and runs a program from there with no library path set |

What is installed under `share/goose-qt`: the package (`qt.goose`, `extra.goose`,
`api.goose`, the module files, `qt.build`, `include/`), the docs, examples, samples, tests and generator. The
samples import the package as `"../.."`, which holds in the install too, so they run from
there.

## By hand

1. Build and install qtc (see its README). goose-qt loads `libqtc.so.1` (`libqtc.1.dylib`,
   `qtc.dll`) at run time.
2. Put this directory anywhere and import it by path: `import qt from "path/to/goose-qt";`
3. If qtc is not where the loader looks, point it there:
   `LD_LIBRARY_PATH=/path/to/qtc/lib goose app.goose`, or name it in your program's sidecar
   (`app.build`): `dylibs_linux = ["qtc=/path/to/libqtc.so.1"];`

## From git

Goose can fetch the package itself:

```goose
import qt from "github.com/<owner>/goose-qt@v1.0.0";
```

in the program's root file. qtc still has to be installed where the loader finds it, since
Goose fetches the Goose source only.

## qt.build

`qt.build` tells Goose which shared libraries the package loads and which C header it needs:

```
dylibs_linux = ["qtc=libqtc.so.1", "qtc_test=libqtc_test.so.1"];
dylibs_macos = ["qtc=libqtc.1.dylib", "qtc_test=libqtc_test.1.dylib"];
dylibs_windows = ["qtc=qtc.dll", "qtc_test=qtc_test.dll"];
c_headers = ["include/goose_qt.h"];
```

A library is opened only when a program calls into it, so programs that never use the
`test_*` helpers never load `libqtc_test`. The CMake install rewrites this platform's line
with absolute paths (`GOOSE_QT_PIN_QTC`); a program's own sidecar can override it.

An installed qtc also carries the run path of the Qt it was built against
(`QTC_INSTALL_RPATH`, on by default), so Qt outside the system's directories needs no
library path either.

## Licensing

goose-qt is MIT. What a program is bound by depends on the libqtc it runs with: a default
qtc build binds only Qt modules available under the LGPL-3.0, which closed-source programs
may use; a build with `-DQTC_GPL_MODULES=ON` adds the GPL-3.0-only modules (Charts, Network
Authorization, HTTP Server, MQTT, CoAP). Their functions are in their module files either way; with
a default libqtc they fail with `qt::ERR_NOT_FOUND`. `qt::stats()` lists the GPL-3.0-only
modules a libqtc links. qtc's [licensing notes](../../qtc/docs/LICENSING.md) have the
details.
