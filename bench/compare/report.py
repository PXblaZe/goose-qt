#!/usr/bin/env python3
"""Turns results/results.json (from run.py) into results/results.md and two charts.

    python3 report.py [results/results.json]
"""
import json
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ORDER = ["cpp", "cpp_wheel", "qtc", "goose", "goose_jit", "pyqt6", "pyside6", "miqt"]
OURS = {"qtc", "goose", "goose_jit"}
SURFACE, INK, MUTED, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
HIGHLIGHT, OTHER = "#2a78d6", "#a9a8a2"   # qtc and goose-qt; everyone else


def fmt(v, unit):
    if unit == "ns":
        return "%.0f" % v if v >= 10 else "%.1f" % v
    return "%.0f" % v if v >= 100 else "%.1f" % v


def panel(ax, title, unit, rows):
    names = [r[0] for r in rows][::-1]
    vals = [r[1] for r in rows][::-1]
    keys = [r[2] for r in rows][::-1]
    colors = [HIGHLIGHT if k in OURS else OTHER for k in keys]
    bars = ax.barh(range(len(vals)), vals, color=colors, height=0.62, edgecolor=SURFACE, linewidth=2)
    top = max(vals)
    for b, v in zip(bars, vals):
        ax.text(b.get_width() + top * 0.015, b.get_y() + b.get_height() / 2, fmt(v, unit) + " " + unit,
                va="center", ha="left", fontsize=8, color=MUTED)
    ax.set_yticks(range(len(names)))
    ax.set_yticklabels(names, fontsize=8, color=INK)
    ax.set_xlim(0, top * 1.32)
    ax.set_title(title, fontsize=9.5, color=INK, loc="left", pad=6)
    ax.tick_params(axis="x", labelsize=7, colors=MUTED, length=0)
    ax.tick_params(axis="y", length=0)
    ax.grid(axis="x", color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    for s in ax.spines.values():
        s.set_visible(False)
    ax.set_facecolor(SURFACE)


def chart(path, panels, cols, title):
    rows = (len(panels) + cols - 1) // cols
    n = max(len(p[2]) for p in panels)
    fig, axes = plt.subplots(rows, cols, figsize=(5.2 * cols, (0.32 * n + 0.9) * rows), facecolor=SURFACE)
    axes = [a for row in (axes if rows > 1 else [axes]) for a in (row if cols > 1 else [row])]
    for ax, (t, unit, rs) in zip(axes, panels):
        panel(ax, t, unit, rs)
    for ax in axes[len(panels):]:
        ax.set_visible(False)
    fig.suptitle(title, x=0.01, ha="left", fontsize=11, color=INK, y=0.995)
    fig.text(0.99, 0.995, "blue: qtc and goose-qt   grey: the others   shorter is faster",
             ha="right", va="top", fontsize=8, color=MUTED)
    fig.tight_layout(rect=(0, 0, 1, 0.975))
    fig.savefig(path, dpi=144, facecolor=SURFACE)
    plt.close(fig)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "results", "results.json")
    data = json.load(open(src))
    res = data["results"]
    keys = [k for k in ORDER if k in res]
    out = os.path.dirname(src)

    def rows(op):
        return [(res[k]["label"], res[k]["median"][op], k) for k in keys if op in res[k]["median"]]

    chart(os.path.join(out, "calls.png"), [(d, "ns", rows(op)) for op, d in data["ops"]], 2,
          "What one call costs (nanoseconds, median of %d runs)" % data["env"]["rounds"])
    work = [(d, "ms", rows(op)) for op, d in data["work"]]
    work.append(("start Qt, show a label, paint it, exit", "ms", rows("startup_ms")))
    work.append(("peak memory of that program (MiB)", "MiB", rows("startup_rss_mib")))
    chart(os.path.join(out, "workloads.png"), work, 2, "Whole tasks (milliseconds, median)")

    e = data["env"]
    md = ["# Results", "",
          "%s, %d cores, %s; %s. Median of %d runs each (startup: %d runs)." %
          (e["cpu"], e["cores"], e["system"], e["date"], e["rounds"], e["startup_runs"]), ""]
    head = "| | " + " | ".join(res[k]["label"] for k in keys) + " |"
    sep = "|---|" + "---:|" * len(keys)

    def table(title, items, unit):
        md.extend(["## " + title, "", head, sep])
        for op, d in items:
            cells = []
            for k in keys:
                m = res[k]["median"].get(op)
                cells.append("" if m is None else fmt(m, unit))
            md.append("| %s | %s |" % (d, " | ".join(cells)))
        md.append("")

    table("Calls (ns per call)", data["ops"], "ns")
    table("Whole tasks (ms)", data["work"] + [("startup_ms", "startup to exit")], "ms")
    table("Memory (MiB)", [("startup_rss_mib", "peak RSS of the startup program")], "ms")
    md.extend(["## Spread (fastest and slowest run)", "", head, sep])
    for op, d in data["ops"] + data["work"]:
        cells = []
        for k in keys:
            r = res[k]["range"].get(op)
            cells.append("" if r is None else "%s–%s" % (fmt(r[0], "ns"), fmt(r[1], "ns")))
        md.append("| %s | %s |" % (d, " | ".join(cells)))
    md.append("")
    with open(os.path.join(out, "results.md"), "w") as f:
        f.write("\n".join(md))
    print("wrote results.md, calls.png and workloads.png in %s" % out)


if __name__ == "__main__":
    main()
