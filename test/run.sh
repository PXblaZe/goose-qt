#!/usr/bin/env bash
# Runs the goose-qt test programs, each with the JIT and as a native build.
#
#   test/run.sh                      every test, both ways
#   test/run.sh t03_widgets          one test (with or without .goose)
#   GOOSE=/path/to/goose QTC_LIB=/path/to/qtc/build test/run.sh
#
# QTC_LIB is the directory with libqtc.so.1 and libqtc_test.so.1 (the qtc build
# directory, or the install prefix's lib directory); it goes first on the library path.
# Tests run on Qt's offscreen platform, so no display is needed. t06_threads uses
# threads, which only native builds have: it runs native only (as does t08_futures).
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOOSE="${GOOSE:-goose}"
if ! command -v "$GOOSE" > /dev/null 2>&1; then
    echo "goose not found (set GOOSE=/path/to/goose)" >&2
    exit 2
fi
if [ -n "${QTC_LIB:-}" ]; then
    export LD_LIBRARY_PATH="$QTC_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export DYLD_LIBRARY_PATH="$QTC_LIB${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
fi
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_LOGGING_RULES="*=false"
export LC_ALL="${LC_ALL:-C.UTF-8}"

tests=()
if [ $# -gt 0 ]; then
    for t in "$@"; do tests+=("${t%.goose}"); done
else
    for f in "$here"/t[0-9]*.goose; do tests+=("$(basename "$f" .goose)"); done
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"   # what the tests write (screenshots, a QML file) stays out of the tree
pass=0
fail=0
failed=()
run() {   # name mode command...
    local name=$1 mode=$2
    shift 2
    local out="$work/$name.$mode.out"
    local t0=$(date +%s.%N)
    if "$@" > "$out" 2>&1; then
        pass=$((pass + 1))
        printf '%-16s %-6s ok    %6.1fs  %s\n' "$name" "$mode" "$(echo "$(date +%s.%N) - $t0" | bc)" "$(tail -n 1 "$out")"
    else
        fail=$((fail + 1))
        failed+=("$name ($mode)")
        printf '%-16s %-6s FAIL\n' "$name" "$mode"
        sed 's/^/    /' "$out" | tail -n 25
    fi
}
for t in "${tests[@]}"; do
    if [ "$t" != "t06_threads" ] && [ "$t" != "t08_futures" ]; then
        run "$t" jit "$GOOSE" "$here/$t.goose"
    fi
    if "$GOOSE" build "$here/$t.goose" -o "$work/$t" > "$work/$t.build.out" 2>&1; then
        run "$t" native "$work/$t"
    else
        fail=$((fail + 1))
        failed+=("$t (build)")
        printf '%-16s %-6s FAIL (build)\n' "$t" native
        sed 's/^/    /' "$work/$t.build.out" | tail -n 25
    fi
done
echo "goose-qt tests: $pass passed, $fail failed"
for f in "${failed[@]+"${failed[@]}"}"; do echo "  failed: $f"; done
[ "$fail" -eq 0 ]
