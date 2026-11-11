#!/usr/bin/env python3
"""Generate goose-qt's api.goose from qtc's API manifest (manifest/qtc_api.json).

Instance methods become functions on qt::Obj / qt::Val, deduplicated across
classes: one Goose function per (name, receiver, Goose parameter types). When
every Qt overload behind it has the same signature the call names that
signature; otherwise it passes the name and qtc picks the overload for the
receiver's class at run time. Static methods become Class_method(...),
constructors are named after the class, and each enum scope becomes a value
whose fields are the keys: qt::Qt.AlignLeft, qt::QImage.Format_ARGB32.

Return types are stable: when a function's Qt methods come to return different types (a newly
bound class whose name() is an int, next to the many whose name() is a string), the type the
function returned before is kept, read from the api.goose being replaced (--baseline), and the
other classes' results are reached through the typed variants (name_int).
"""
import argparse
import collections
import json
import os
import re

KEYWORDS = set("""import namespace struct enum type fn thread_fn export simd recursive let var extern const pad reusable
if else while for in loop block guard defer match return break continue as true false null self bool varint i8 i16
i32 i64 u8 u16 u32 u64 f32 f64""".split())
BUILTINS = {"print", "str", "format", "assert", "abort", "exit", "copy", "default", "hardware_threads", "thread_spawn",
            "thread_spawn_contained", "thread_wait", "qput", "qget", "qpoll", "qlimit", "to_bytes", "bytes_of",
            "from_bytes", "embed_file", "embed_shader", "main"}

GTYPE = {"bool": "bool", "int": "i64", "uint": "i64", "double": "f64", "str": "const u8[:]", "bytes": "const u8[:]",
         "obj": "Obj", "variant": "Val", "value": "Val", "list": "Val", "map": "Val"}
PUSH = {"bool": "qtc_arg_bool(%s);", "int": "qtc_arg_int(%s);", "uint": "qtc_arg_int(%s);", "double": "qtc_arg_double(%s);",
        "str": "qtc_arg_str(%s);", "bytes": "qtc_arg_bytes(%s);", "obj": "qtc_arg_obj(%s.h);", "variant": "qtc_arg_val(%s.h);",
        "value": "qtc_arg_val(%s.h);", "list": "qtc_arg_val(%s.h);", "map": "qtc_arg_val(%s.h);"}
RTYPE = {"none": None, "bool": "bool", "int": "i64", "uint": "i64", "double": "f64", "str": "u8[>..]", "bytes": "u8[>..]",
         "obj": "Obj", "value": "Val", "list": "Val", "map": "Val", "variant": "Val", "null": None}
SUFFIX = {"bool": "_bool", "i64": "_int", "f64": "_f64", "u8[>..]": "_str", "Obj": "_obj", "Val": "_val"}
RET = {"bool": "return qtc_ret_bool();", "i64": "return qtc_ret_int();", "f64": "return qtc_ret_double();",
       "u8[>..]": "return view(qtc_ret_str());", "Obj": "return Obj { h: qtc_ret_obj() };",
       "Val": "return Val { h: qtc_ret_val() };"}


def gstr(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def safe(name):
    return name.replace("::", "_")


def merge_ret(types):
    ts = {t for t in types if t}
    if not ts:
        return None
    if len(ts) == 1:
        return ts.pop()
    if ts <= {"i64", "f64", "bool"}:
        return "f64" if "f64" in ts else "i64"
    return "Val"


def baseline_returns(path):
    """(fn name, receiver, parameter types) -> return type of every function in an earlier api.goose."""
    rets = {}
    if not path or not os.path.exists(path):
        return rets
    rx = re.compile(r"^fn (\w+)\((.*?)\)(?: -> (.+?))? \{")
    for line in open(path):
        m = rx.match(line)
        if not m:
            continue
        parts = [x.split(": ", 1)[1] for x in re.split(r", (?=(?:o|a\d+): )", m.group(2)) if ": " in x]
        if m.group(2).startswith("o: "):
            key = (m.group(1), parts[0], tuple(parts[1:]))
        else:
            key = (m.group(1), "static", tuple(parts))
        rets[key] = m.group(3)
    return rets


def core_signatures(core_path):
    """(name, parameter types) of every hand-written function in qt.goose."""
    sigs = set()
    for line in open(core_path):
        m = re.match(r"\s*fn (\w+)\((.*?)\)\s*(->|\{|;)", line)
        if not m:
            continue
        types = []
        for part in [x for x in m.group(2).split(",") if x.strip()]:
            if ":" in part:
                types.append(part.split(":", 1)[1].strip())
        sigs.add((m.group(1), tuple(types)))
    return sigs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--out", required=True, help="the goose-qt directory")
    ap.add_argument("--baseline", help="the api.goose whose return types stay (default: the one in --out)")
    ap.add_argument("--entries", help="qtc's direct entry points (default: qtc_entries.json next to --manifest)")
    args = ap.parse_args()
    # qtc_direct.h: one C function per signature, called directly instead of pushing the
    # arguments and naming the method (qtc_call); same checks, no lookup
    ep = args.entries or os.path.join(os.path.dirname(args.manifest), "qtc_entries.json")
    direct = json.load(open(ep)) if os.path.exists(ep) else {"methods": {}, "ctors": {}}
    externs = {}   # entry name -> extern declaration
    before = baseline_returns(args.baseline or os.path.join(args.out, "api.goose"))
    kept = 0
    man = json.load(open(args.manifest))
    reserved = KEYWORDS | BUILTINS
    core = core_signatures(os.path.join(args.out, "qt.goose"))
    core_names = {n for n, _ in core}

    def gname(n):
        return n + "_" if n in reserved else n

    groups = collections.OrderedDict()   # (fn name, receiver, goose params) -> list of (cls, sig, ret, pushes)
    stats = collections.Counter()
    for c in man["classes"]:
        cls = c["name"]
        recv = "Obj" if c["kind"] == "object" else "Val"
        for m in c["methods"]:
            ps = m["params"]
            for k in range(m["min"], len(ps) + 1):
                gparams, pushes, ok = [], [], True
                for i, p in enumerate(ps[:k]):
                    if p["pk"] in ("null", "out"):
                        # pointer parameters are left out; qtc passes null or out storage (qt::out_*)
                        pushes.append("qtc_arg_null();")
                        continue
                    t = GTYPE.get(p["pk"])
                    if t is None:
                        ok = False
                        break
                    an = "a%d" % len(gparams)
                    gparams.append(t)
                    pushes.append(PUSH[p["pk"]] % an)
                if not ok:
                    stats["unmappable"] += 1
                    continue
                sig = "%s(%s)" % (m["name"], ",".join(p["type"] for p in ps[:k]))
                if m["static"]:
                    fname = "%s_%s" % (safe(cls), m["name"])
                    key = (fname, "static:" + cls, tuple(gparams))
                else:
                    fname = gname(m["name"])
                    # a hand-written qt function with the same parameter list wins; the Qt method gets a trailing _
                    if (fname, (recv,) + tuple(gparams)) in core or (fname in core_names and fname in ("free", "call", "set", "arg")):
                        fname += "_"
                    key = (fname, recv, tuple(gparams))
                groups.setdefault(key, []).append((cls, sig, RTYPE.get(m["ret"]), pushes, m["name"], ps[:k]))
                stats["entries"] += 1

    out = ["// Generated by gen/generate_goose.py from qtc's API manifest (Qt %s). Do not edit." % man["qt_version"],
           "// Instance methods take qt::Obj or qt::Val and work through UFCS: label.setText(\"hi\").",
           "namespace qt;", ""]
    nfun = 0
    nvar = 0
    for (fname, recv, gparams), entries in groups.items():
        sigs = sorted({e[1] for e in entries})
        rt = merge_ret([e[2] for e in entries])
        prev = before.get((fname, "static" if recv.startswith("static:") else recv, tuple(gparams)))
        if prev and prev != rt and prev in {e[2] for e in entries}:
            rt = prev   # keep the published return type; the other classes' results have typed variants
            kept += 1
        pushes = entries[0][3]
        if any("qtc_arg_null();" in e[3] for e in entries):
            # optional T* out-parameters are left out; qtc fills them with null for the overload it picks
            pushes = [p for p in pushes if p != "qtc_arg_null();"]
            sigs = sigs + ["<by name>"]
        params = ", ".join("a%d: %s" % (i, t) for i, t in enumerate(gparams))
        body = list(pushes)
        if recv.startswith("static:"):
            cls = recv[7:]
            target = sigs[0] if len(sigs) == 1 else entries[0][4]
            body.append("qtc_call_static(%s, %s);" % (gstr(cls), gstr(target)))
            head = "fn %s(%s)" % (fname, params)
        else:
            target = sigs[0] if len(sigs) == 1 else entries[0][4]
            ename = direct["methods"].get(target) if len(sigs) == 1 else None
            if ename:
                # the direct entry point: the receiver and the arguments, no pushes
                cargs = ["o.h"] + ["a%d.h" % i if t in ("Obj", "Val") else "a%d" % i for i, t in enumerate(gparams)]
                body = ["%s(%s);" % (ename, ", ".join(cargs))]
                externs[ename] = "    fn %s(%s) -> i32;" % (ename, ", ".join(
                    ["receiver: u64"] + ["a%d: %s" % (i, "u64" if t in ("Obj", "Val") else t) for i, t in enumerate(gparams)]))
                stats["direct"] += 1
            else:
                body.append("qtc_call(o.h, %s);" % gstr(target))
            head = "fn %s(o: %s%s)" % (fname, recv, (", " + params) if params else "")
        if rt:
            head += " -> " + rt
            body.append(RET[rt])
        out.append(head + " { " + " ".join(body) + " }")
        nfun += 1
        # Return types differ across classes and one of them is an object: the function returns a
        # qt::Val (use .to_obj()), and name_obj returns the object directly.
        # The Qt methods behind one Goose function return different types on different classes
        # (QImage::width is an int, QPen::width too, QTextLength's is a value): the function
        # returns the common type (f64 for int and double, otherwise qt::Val), and a typed variant
        # per return type gives it directly: img.width_int(), comp.create_obj().
        rts = {e[2] for e in entries if e[2]}
        if rt:
            for t in sorted(rts - {rt}):
                vname = fname + SUFFIX[t]
                if (vname, recv, gparams) in groups:
                    continue
                if recv.startswith("static:"):
                    vhead = "fn %s(%s) -> %s" % (vname, params, t)
                else:
                    vhead = "fn %s(o: %s%s) -> %s" % (vname, recv, (", " + params) if params else "", t)
                out.append(vhead + " { " + " ".join(body[:-1] + [RET[t]]) + " }")
                nfun += 1
                nvar += 1

    # constructors
    ctor_groups = collections.OrderedDict()
    for c in man["classes"]:
        cls = c["name"]
        is_obj = c["kind"] == "object"
        for k in c["ctors"]:
            ps = k["params"]
            for n in range(k["min"], len(ps) + 1):
                gparams, pushes, ok = [], [], True
                for p in ps[:n]:
                    if p["pk"] in ("null", "out"):
                        pushes.append("qtc_arg_null();")
                        continue
                    t = GTYPE.get(p["pk"])
                    if t is None:
                        ok = False
                        break
                    gparams.append(t)
                    pushes.append(PUSH[p["pk"]] % ("a%d" % (len(gparams) - 1)))
                if not ok:
                    continue
                key = (safe(cls), tuple(gparams))
                sig = "%s(%s)" % (cls, ",".join(p["type"] for p in ps[:n]))
                g = ctor_groups.setdefault(key, (cls, is_obj, pushes, []))
                g[3].append(sig)
    out.append("")
    out.append("// ------------------------------------------------------------ constructors")
    ncto = 0
    for (fname, gparams), (cls, is_obj, pushes, csigs) in ctor_groups.items():
        params = ", ".join("a%d: %s" % (i, t) for i, t in enumerate(gparams))
        # one constructor behind it: its direct entry point (several: qtc picks among them)
        ename = direct["ctors"].get("%s|%s" % (cls, csigs[0])) if len(set(csigs)) == 1 else None
        if ename:
            cargs = ["a%d.h" % i if t in ("Obj", "Val") else "a%d" % i for i, t in enumerate(gparams)]
            externs[ename] = "    fn %s(%s) -> u64;" % (ename, ", ".join(
                "a%d: %s" % (i, "u64" if t in ("Obj", "Val") else t) for i, t in enumerate(gparams)))
            out.append("fn %s(%s) -> %s { return %s { h: %s(%s) }; }" % (
                fname, params, "Obj" if is_obj else "Val", "Obj" if is_obj else "Val", ename, ", ".join(cargs)))
            ncto += 1
            stats["direct_ctors"] += 1
            continue
        if is_obj:
            body = pushes + ["return Obj { h: qtc_new(%s) };" % gstr(cls)]
            out.append("fn %s(%s) -> Obj { %s }" % (fname, params, " ".join(body)))
        else:
            body = pushes + ["return Val { h: qtc_val_new(%s) };" % gstr(cls)]
            out.append("fn %s(%s) -> Val { %s }" % (fname, params, " ".join(body)))
        ncto += 1

    # enums, one value per scope
    scopes = collections.OrderedDict()
    for e in man["enums"]:
        name = e["name"]
        scope, _, ename = name.rpartition("::")
        if not scope:
            continue
        fields = scopes.setdefault(scope, collections.OrderedDict())
        for key, v in e["values"]:
            f = ("%s_%s" % (ename, key)) if e.get("scoped") else key
            if f in KEYWORDS:
                f += "_"
            if f in fields:
                f = "%s_%s" % (ename, key)
                if f in fields:
                    continue
            if v >= 2**63:
                v -= 2**64
            fields[f] = v
    out.append("")
    out.append("// ------------------------------------------------------------ enum values")
    nenum = 0
    for scope, fields in scopes.items():
        if not fields:
            continue
        sname = safe(scope)
        out.append("struct %s_enums { %s }" % (sname, ", ".join("%s: i64 = %d" % (f, v) for f, v in fields.items())))
        out.append("let %s = default<%s_enums>();" % (sname, sname))
        nenum += len(fields)
    if externs:
        out[3:3] = ["// qtc's direct entry points (qtc_direct.h) the functions below call", 'extern "qtc" {'] + \
            [externs[k] for k in sorted(externs)] + ["}", ""]
    with open(os.path.join(args.out, "api.goose"), "w") as f:
        f.write("\n".join(out) + "\n")
    write_wrapper_test(args.out, out)
    print("api.goose: %d return types kept from the baseline" % kept)
    print("api.goose: %d functions and %d constructors call direct entry points" % (stats["direct"], stats["direct_ctors"]))
    print("api.goose: %d method functions (%d typed variants, from %d overload entries), %d constructors, "
          "%d enum values in %d scopes" % (nfun, nvar, stats["entries"], ncto, nenum, len(scopes)))


DEFAULT_ARG = {"i64": "0", "f64": "0.0", "bool": "false", "const u8[:]": "\"\"", "Obj": "qt::NONE",
               "Val": "qt::Val { h: 0 }"}


def write_wrapper_test(out_dir, api_lines):
    """test/t90_wrappers.goose: every instance-method wrapper called on a null receiver.

    Each must reach qtc and come back with QTC_ERR_NULL_HANDLE: this checks that every
    wrapper compiles, pushes its arguments and consumes them, without running any Qt code."""
    calls = []
    for line in api_lines:
        m = re.match(r"fn (\w+)\(o: (Obj|Val)((?:, a\d+: [^,)]+)*)\)", line)
        if not m:
            continue
        name, recv, rest = m.group(1), m.group(2), m.group(3)
        types = [t.split(": ", 1)[1] for t in rest.split(", ")[1:]] if rest else []
        recv_arg = "qt::NONE" if recv == "Obj" else "qt::Val { h: 0 }"
        args = ", ".join([recv_arg] + [DEFAULT_ARG[t] for t in types])
        calls.append("    qt::%s(%s); n++; if qt::last_error() != qt::ERR_NULL_HANDLE { bad++; if bad < 20 { print(\"wrapper %s: \", qt::last_error_message()); } }" % (name, args, name))
    chunks = [calls[i:i + 500] for i in range(0, len(calls), 500)]
    src = ["// Generated by gen/generate_goose.py. Every instance-method wrapper on a null receiver.",
           "import qt from \"..\";", ""]
    for k, chunk in enumerate(chunks):
        src.append("fn part%d(n: i64&, bad: i64&) {" % k)
        src.extend(chunk)
        src.append("}")
    src.append("fn main() {")
    src.append("    qt::init(qt::APP_WIDGETS, \"t90\\0-platform\\0offscreen\");")
    src.append("    qt::set_error_policy(qt::ERRORS_RETURN);")
    src.append("    var n = 0;")
    src.append("    var bad = 0;")
    for k in range(len(chunks)):
        src.append("    part%d(n, bad);" % k)
    src.append("    let stray = qt::live_values();")
    src.append("    qt::shutdown();")
    src.append("    print(\"t90_wrappers: \", n, \" wrappers called, \", bad, \" did not report a null receiver, \", stray, \" stray values\");")
    src.append("    if bad > 0 || stray > 0 { exit(1); }")
    src.append("}")
    with open(os.path.join(out_dir, "test", "t90_wrappers.goose"), "w") as f:
        f.write("\n".join(src) + "\n")
    print("test/t90_wrappers.goose: %d wrapper calls" % len(calls))


if __name__ == "__main__":
    main()
