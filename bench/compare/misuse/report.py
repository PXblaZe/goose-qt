#!/usr/bin/env python3
"""Turns results/misuse.txt (from misuse/run.py) into results/safety.png: what each binding
did with each misuse probe, as a grid.

    python3 misuse/report.py
"""
import os
import re

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Patch, Rectangle  # noqa: E402

import importlib.util  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("misuse_run", os.path.join(HERE, "run.py"))
_run = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_run)
CASES = _run.CASES

COLS = [("goose", "goose-qt"), ("pyqt6", "PyQt6"), ("pyside6", "PySide6"), ("rust", "Rust (cxx-qt)"),
        ("go", "Go (miqt)"), ("cpp", "C++")]
SURFACE, INK, MUTED = "#fcfcfb", "#0b0b0b", "#52514e"
# outcome -> (color, legend label); the status colors, each cell also says it in words
KINDS = {
    "good": ("#0ca30c", "reported as an error, or handled safely"),
    "compile": ("#2a78d6", "refused by the compiler (safe Rust)"),
    "silent": ("#fab219", "no error: silently wrong (truncated, a data race)"),
    "crash": ("#d03b3b", "crashed, aborted or hung"),
}
# what a run cannot show by itself: Rust's compile errors (checked with cargo, see
# docs/comparison.md) and how often a racy probe crashes over ten runs
NOTES = {
    ("rust", "deleted_self"): ("compile", "won't compile\n(unsafe: crash)"),
    ("rust", "double_delete"): ("compile", "won't compile\n(unsafe: crash)"),
    ("rust", "wrong_thread"): ("compile", "won't compile\n(unsafe: race)"),
    ("rust", "deleted"): ("crash", "crash\n(in unsafe)"),
    ("rust", "held_deleted"): ("crash", "crash\n(in unsafe)"),
    ("rust", "null"): ("crash", "crash\n(in unsafe)"),
    ("rust", "qtbug"): ("crash", "crash\n(in unsafe)"),
    ("rust", "stale_index"): ("crash", "crash\n(safe Rust)"),
    ("rust", "before_app"): ("crash", "abort\n(safe Rust)"),
    ("rust", "range"): ("silent", "truncated\n(an `as` cast)"),
    ("cpp", "range"): ("silent", "truncated"),
    ("go", "range"): ("silent", "truncated"),
    ("pyside6", "double_delete"): ("good", "ignored"),
    ("cpp", "wrong_thread"): ("silent", "data race\n(1/10 aborted)"),
    ("go", "wrong_thread"): ("silent", "data race\n(2/10 crashed)"),
    ("pyqt6", "wrong_thread"): ("silent", "data race"),
    ("pyside6", "wrong_thread"): ("silent", "data race"),
}


def classify(name, case, code, text):
    if (name, case) in NOTES:
        return NOTES[(name, case)]
    if code == "hung":
        return "crash", "hang"
    if text.startswith("error:"):
        return "good", "error"
    if text.startswith("refused:"):
        return "good", "refused"
    if text.startswith("handled:"):
        return "good", "handled"
    if text.startswith("panic"):
        return "crash", "panic"
    if code == "0":
        return "silent", "no error"
    if code == "134" or "Must construct" in text:
        return "crash", "abort"
    return "crash", "crash"


def main():
    src = os.path.join(os.path.dirname(HERE), "results", "misuse.txt")
    got = {}
    for line in open(src):
        m = re.match(r"(\S+)\s+(\S+)\s+exit=(\S+)\s*(.*)$", line.rstrip("\n"))
        if m:
            got[(m.group(2), m.group(1))] = (m.group(3), m.group(4).strip())
    cases = [c for c in CASES if any((k, c[0]) in got for k, _ in COLS)]
    fig, ax = plt.subplots(figsize=(2.0 + 1.55 * len(COLS), 0.62 * len(cases) + 2.0), facecolor=SURFACE)
    ax.set_facecolor(SURFACE)
    score = {k: 0 for k, _ in COLS}
    for r, (case, desc) in enumerate(cases):
        y = len(cases) - 1 - r
        for c, (key, _) in enumerate(COLS):
            code, text = got.get((key, case), ("", ""))
            kind, label = classify(key, case, code, text)
            score[key] += kind in ("good", "compile")
            ax.add_patch(Rectangle((c + 0.03, y + 0.05), 0.94, 0.9, color=KINDS[kind][0], linewidth=0))
            ax.text(c + 0.5, y + 0.5, label, ha="center", va="center", fontsize=7.2,
                    color="#0b0b0b" if kind == "silent" else "#ffffff")
        ax.text(-0.08, y + 0.5, desc, ha="right", va="center", fontsize=7.6, color=INK, wrap=True)
    for c, (key, label) in enumerate(COLS):
        ax.text(c + 0.5, len(cases) + 0.25, label, ha="center", va="bottom", fontsize=8.5, color=INK, weight="bold")
        ax.text(c + 0.5, -0.35, "%d of %d caught" % (score[key], len(cases)), ha="center", va="top", fontsize=8,
                color=MUTED)
    ax.set_xlim(-4.6, len(COLS))
    ax.set_ylim(-0.9, len(cases) + 0.9)
    ax.axis("off")
    fig.legend(handles=[Patch(color=v[0], label=v[1]) for v in KINDS.values()], loc="lower center", ncol=2,
               fontsize=7.6, frameon=False)
    fig.suptitle("Ten misuses, each run once per binding in its own process", x=0.02, ha="left", fontsize=11,
                 color=INK, y=0.985)
    fig.tight_layout(rect=(0, 0.07, 1, 0.96))
    out = os.path.join(os.path.dirname(HERE), "results", "safety.png")
    fig.savefig(out, dpi=144, facecolor=SURFACE)
    print("wrote %s" % out, {k: score[k] for k, _ in COLS})


if __name__ == "__main__":
    main()
