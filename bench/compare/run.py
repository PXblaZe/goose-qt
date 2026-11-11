#!/usr/bin/env python3
"""Builds and runs the comparison benchmark in every implementation, then writes the results.

    python3 run.py [--rounds 5] [--startup-runs 15] [--out results] [--only cpp,goose,...]

Settings come from the environment:
    QT_PREFIX    Qt 6.12 for the compiled implementations (default /opt/qt612)
    QTC_INCLUDE  qtc's include directory, QTC_LIB the directory with libqtc.so.1
    GOOSE        the goose compiler
    PYTHON       a Python with PySide6 and PyQt6 installed (both 6.12)
    GO           the go tool; miqt must be in its module cache (see README.md)
    CARGO        cargo, for the Rust implementation (cxx-qt from crates.io)

Every implementation runs as its own process, `rounds` times, in a different order each
round; the result for an operation is the median of its rounds. Startup is timed from the
outside: process start to exit, with the peak resident memory the kernel reports.
"""
import argparse
import json
import os
import platform
import random
import statistics
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
OPS = [("set_text", "label.setText(\"hello\")"), ("get_text", "label.text()"),
       ("set_value", "slider.setValue(i)"), ("get_value", "slider.value()"),
       ("set_property", "setProperty(\"text\", ...)"), ("signal", "button.click() reaching a handler"),
       ("value_type", "QColor(255, 0, 0).red()"), ("object_churn", "new QObject, then delete it")]
WORK = [("model_filter", "filter 1,000,000 rows of a model written in the language"),
        ("paint_lines", "paint 100,000 short lines into a 1024x1024 QImage"),
        ("widgets", "2,000 buttons in a grid: create, show, paint, destroy")]


def sh(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode != 0:
        raise RuntimeError("%s failed:\n%s%s" % (cmd[0], r.stdout[-3000:], r.stderr[-3000:]))
    return r.stdout


def impls(build, want_go=True, want_rust=True):
    qt = os.environ.get("QT_PREFIX", "/opt/qt612")
    qtc_inc = os.environ.get("QTC_INCLUDE", os.path.join(HERE, "../../../qtc/include"))
    qtc_lib = os.environ.get("QTC_LIB", "")
    goose = os.environ.get("GOOSE", "goose")
    python = os.environ.get("PYTHON", sys.executable)
    go = os.environ.get("GO", "go")
    os.makedirs(build, exist_ok=True)
    base = {"QT_QPA_PLATFORM": "offscreen", "LC_ALL": "C.UTF-8", "QT_LOGGING_RULES": "*.warning=false"}
    wheel_qt = sh([python, "-c", "import os, PySide6; print(os.path.join(os.path.dirname(PySide6.__file__), 'Qt'))"]).strip()
    out = []

    def add(key, label, cmd, env=None, note=""):
        e = dict(os.environ)
        e.update(base)
        e.update(env or {})
        out.append({"key": key, "label": label, "cmd": cmd, "env": e, "note": note})

    pc = sh(["pkg-config", "--cflags", "--libs", "Qt6Widgets"],
            env=dict(os.environ, PKG_CONFIG_PATH=os.path.join(qt, "lib/pkgconfig"))).split()
    exe = os.path.join(build, "cpp_bench")
    sh(["g++", "-O2", "-std=c++17", "-fPIC", os.path.join(HERE, "cpp/bench.cpp"), "-o", exe] + pc +
       ["-Wl,-rpath," + os.path.join(qt, "lib")])
    add("cpp", "C++ (direct)", [exe], note="Qt from QT_PREFIX")
    add("cpp_wheel", "C++ (direct), wheel Qt", [exe],
        {"LD_LIBRARY_PATH": os.path.join(wheel_qt, "lib"), "QT_PLUGIN_PATH": os.path.join(wheel_qt, "plugins")},
        note="the same program on the Qt build the Python wheels ship")

    exe = os.path.join(build, "c_bench")
    sh(["gcc", "-O2", "-std=c11", os.path.join(HERE, "c/bench.c"), "-I" + qtc_inc, "-L" + qtc_lib, "-lqtc",
        "-Wl,-rpath," + qtc_lib, "-o", exe])
    add("qtc", "C (qtc)", [exe])

    exe = os.path.join(build, "goose_bench")
    sh([goose, "build", os.path.join(HERE, "goose/bench.goose"), "-o", exe], cwd=os.path.join(HERE, "goose"))
    lib = {"LD_LIBRARY_PATH": qtc_lib}
    add("goose", "Goose (goose-qt), native", [exe], lib)
    add("goose_jit", "Goose (goose-qt), JIT", [goose, os.path.join(HERE, "goose/bench.goose"), "--"], lib)

    py = os.path.join(HERE, "python/bench.py")
    add("pyside6", "Python (PySide6)", [python, py, "pyside6"])
    add("pyqt6", "Python (PyQt6)", [python, py, "pyqt6"])

    # Rust: cxx-qt (KDAB), the most used Qt 6 crate; cargo builds it against QT_PREFIX's qmake
    rdir = os.path.join(HERE, "rust")
    try:
        if not want_rust:
            raise RuntimeError("not asked for")
        sh([os.environ.get("CARGO", "cargo"), "build", "--release", "-j", os.environ.get("CARGO_JOBS", "2")], cwd=rdir,
           env=dict(os.environ, QMAKE=os.path.join(qt, "bin", "qmake6")))
        add("cxxqt", "Rust (cxx-qt)", [os.path.join(rdir, "target", "release", "qtbench")],
            {"LD_LIBRARY_PATH": os.path.join(qt, "lib")})
    except (RuntimeError, FileNotFoundError) as e:
        print("Rust (cxx-qt) left out: %s" % str(e).splitlines()[0], file=sys.stderr)

    gomod = os.path.join(HERE, "go")
    exe = os.path.join(build, "go_bench")
    try:
        if not want_go:
            raise RuntimeError("not asked for")
        # -c=1: the Go compiler's own parallelism off, or miqt's large package needs more than 7 GB
        sh([go, "build", "-p", "1", "-gcflags=github.com/mappu/miqt/qt6=-c=1", "-o", exe, "."], cwd=gomod,
           env=dict(os.environ, PKG_CONFIG_PATH=os.path.join(qt, "lib/pkgconfig"), GOFLAGS="-mod=mod", GOGC="50",
                    GOPROXY=os.environ.get("GOPROXY", "direct"), GONOSUMDB="github.com/mappu"))
        add("miqt", "Go (miqt)", [exe], {"LD_LIBRARY_PATH": os.path.join(qt, "lib")})
    except (RuntimeError, FileNotFoundError) as e:
        print("Go (miqt) left out: %s" % str(e).splitlines()[0], file=sys.stderr)
    return out


def run_once(im, extra=()):
    r = subprocess.run(im["cmd"] + list(extra), env=im["env"], capture_output=True, text=True, timeout=900)
    if r.returncode != 0:
        raise RuntimeError("%s exited %d:\n%s%s" % (im["key"], r.returncode, r.stdout[-2000:], r.stderr[-2000:]))
    res = {}
    for line in r.stdout.splitlines():
        if line.startswith("RESULT "):
            _, name, v, unit = line.split()
            res[name] = float(v)
    return res


def startup(im):
    t = time.perf_counter()
    p = subprocess.Popen(im["cmd"] + ["--startup"], env=im["env"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    _, status, ru = os.wait4(p.pid, 0)
    ms = (time.perf_counter() - t) * 1000
    if status != 0:
        raise RuntimeError("%s --startup failed" % im["key"])
    return ms, ru.ru_maxrss / 1024.0   # MiB


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rounds", type=int, default=5)
    ap.add_argument("--startup-runs", type=int, default=15)
    ap.add_argument("--out", default=os.path.join(HERE, "results"))
    ap.add_argument("--build", default=os.path.join(HERE, "build"))
    ap.add_argument("--only", default="", help="comma-separated keys: cpp,cpp_wheel,qtc,goose,goose_jit,pyside6,pyqt6,miqt,cxxqt")
    ap.add_argument("--merge", default="", help="an earlier results.json whose implementations are kept")
    a = ap.parse_args()
    keep = set(a.only.split(",")) if a.only else set()
    ims = impls(a.build, want_go=not keep or "miqt" in keep, want_rust=not keep or "cxxqt" in keep)
    if keep:
        ims = [i for i in ims if i["key"] in keep]
    raw = {i["key"]: [] for i in ims}
    for rnd in range(a.rounds):
        order = ims[:]
        random.Random(rnd).shuffle(order)
        for im in order:
            print("round %d: %s" % (rnd + 1, im["key"]), file=sys.stderr, flush=True)
            raw[im["key"]].append(run_once(im))
    starts = {}
    for k in range(a.startup_runs):
        for im in ims:
            starts.setdefault(im["key"], []).append(startup(im))
    results = {}
    for im in ims:
        rs = raw[im["key"]]
        med = {name: statistics.median(r[name] for r in rs) for name in rs[0]}
        spread = {name: (min(r[name] for r in rs), max(r[name] for r in rs)) for name in rs[0]}
        st = starts[im["key"]]
        med["startup_ms"] = statistics.median(s[0] for s in st)
        med["startup_rss_mib"] = statistics.median(s[1] for s in st)
        results[im["key"]] = {"label": im["label"], "note": im["note"], "median": med, "range": spread, "runs": rs}
    env = {
        "machine": platform.machine(), "system": platform.platform(),
        "cpu": next((l.split(":", 1)[1].strip() for l in open("/proc/cpuinfo") if l.startswith("model name")), "?"),
        "cores": os.cpu_count(), "rounds": a.rounds, "startup_runs": a.startup_runs,
        "date": time.strftime("%Y-%m-%d"),
    }
    if a.merge:
        old = json.load(open(a.merge))["results"]
        for k, v in old.items():
            results.setdefault(k, v)
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, "results.json"), "w") as f:
        json.dump({"env": env, "ops": OPS, "work": WORK, "results": results}, f, indent=1)
    print("wrote %s" % os.path.join(a.out, "results.json"))


if __name__ == "__main__":
    main()
