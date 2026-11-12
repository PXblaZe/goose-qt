#!/usr/bin/env python3
"""Builds the misuse probes in each implementation, runs every probe in its own process, and
writes what happened to results/misuse.txt: an error reported, or the exit status.

    python3 misuse/run.py

Uses the same environment settings as run.py (QT_PREFIX, QTC_LIB, GOOSE, PYTHON, GO).
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from run import sh  # noqa: E402

# the probes, in the order of the table in docs/comparison.md
CASES = [
    ("deleted", "a child used after its parent was deleted"),
    ("deleted_self", "an object used after it was deleted"),
    ("double_delete", "an object deleted twice"),
    ("stale_index", "a model index kept across the model's clear()"),
    ("held_deleted", "a widget deleted while a table still shows it (setCellWidget)"),
    ("null", "a method on a null object: an uneditable combo box's lineEdit()"),
    ("range", "an int argument of 10,000,000,000"),
    ("wrong_thread", "a label's text set from another thread"),
    ("before_app", "a widget made before the application object"),
    ("qtbug", "a call Qt itself crashes on: combo.setView(combo.view())"),
]


def main():
    qt = os.environ.get("QT_PREFIX", "/opt/qt612")
    qtc_lib = os.environ.get("QTC_LIB", "")
    goose = os.environ.get("GOOSE", "goose")
    python = os.environ.get("PYTHON", sys.executable)
    go = os.environ.get("GO", "go")
    build = os.path.join(os.path.dirname(HERE), "build")
    os.makedirs(build, exist_ok=True)
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", LC_ALL="C.UTF-8", QT_LOGGING_RULES="*.warning=false")
    progs = []

    pc = sh(["pkg-config", "--cflags", "--libs", "Qt6Widgets"],
            env=dict(os.environ, PKG_CONFIG_PATH=os.path.join(qt, "lib/pkgconfig"))).split()
    exe = os.path.join(build, "misuse_cpp")
    sh(["g++", "-O2", "-std=c++17", "-fPIC", os.path.join(HERE, "misuse.cpp"), "-o", exe] + pc +
       ["-Wl,-rpath," + os.path.join(qt, "lib")])
    progs.append(("cpp", [exe], {}))

    exe = os.path.join(build, "misuse_goose")
    sh([goose, "build", os.path.join(HERE, "misuse.goose"), "-o", exe], cwd=HERE)
    progs.append(("goose", [exe], {"LD_LIBRARY_PATH": qtc_lib}))

    py = os.path.join(HERE, "misuse.py")
    progs.append(("pyqt6", [python, py, "pyqt6"], {}))
    progs.append(("pyside6", [python, py, "pyside6"], {}))

    exe = os.path.join(build, "misuse_go")
    try:
        # the same flags as run.py, so Go reuses its build of miqt instead of compiling it again
        sh([go, "build", "-p", "1", "-gcflags=github.com/mappu/miqt/qt6=-c=1", "-o", exe, "."],
           cwd=os.path.join(HERE, "go"),
           env=dict(os.environ, PKG_CONFIG_PATH=os.path.join(qt, "lib/pkgconfig"), GOFLAGS="-mod=mod", GOGC="50",
                    GOPROXY=os.environ.get("GOPROXY", "direct"), GONOSUMDB="github.com/mappu"))
        progs.append(("go", [exe], {"LD_LIBRARY_PATH": os.path.join(qt, "lib")}))
    except (RuntimeError, FileNotFoundError) as e:
        print("Go (miqt) left out: %s" % str(e).splitlines()[0], file=sys.stderr)

    # Rust (cxx-qt): the benchmark program has the probes (qtbench --misuse CASE)
    rdir = os.path.join(os.path.dirname(HERE), "rust")
    try:
        sh([os.environ.get("CARGO", "cargo"), "build", "--release", "-j", os.environ.get("CARGO_JOBS", "2")], cwd=rdir,
           env=dict(os.environ, QMAKE=os.path.join(qt, "bin", "qmake6")))
        progs.append(("rust", [os.path.join(rdir, "target", "release", "qtbench"), "--misuse"],
                      {"LD_LIBRARY_PATH": os.path.join(qt, "lib")}))
    except (RuntimeError, FileNotFoundError) as e:
        print("Rust (cxx-qt) left out: %s" % str(e).splitlines()[0], file=sys.stderr)

    lines = []
    for case, _ in CASES:
        for name, cmd, extra in progs:
            try:
                r = subprocess.run(cmd + [case], capture_output=True, text=True, timeout=60,
                                   env=dict(env, **extra))
                code = r.returncode if r.returncode >= 0 else 128 - r.returncode
                out = [l.strip() for l in (r.stdout + r.stderr).splitlines() if l.strip()]
                said = [l for l in out if l.startswith(("error:", "no error reported", "refused:", "handled:"))]
                if said:
                    what = said[-1]
                elif name in ("go", "rust") and out:
                    what = next((l for l in out if "SIGSEGV" in l or l.startswith("panic") or "panicked" in l
                                 or "Must construct" in l or "malloc" in l), "")
                else:
                    what = next((l for l in out if "Must construct" in l or "malloc" in l), "")
            except subprocess.TimeoutExpired:
                code, what = "hung", "no exit within 60 s"
            line = "%-8s %-8s exit=%-4s %s" % (case, name, code, what[:140])
            print(line)
            lines.append(line)
    out = os.path.join(os.path.dirname(HERE), "results", "misuse.txt")
    with open(out, "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
