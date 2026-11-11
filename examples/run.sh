#!/usr/bin/env bash
# Runs every example in its --selftest mode, with the JIT and as a native build
# (threads.goose native only: the JIT runs no threads), and builds shared/ into a
# shared library that a C program calls.
#
#   examples/run.sh
#   GOOSE=/path/to/goose QTC_LIB=/path/to/qtc/build examples/run.sh
#
# QTC_LIB is the directory with libqtc.so.1; it goes first on the library path.
# The examples run on Qt's offscreen platform, so no display is needed.
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

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"   # canvas writes canvas.png into the current directory
pass=0
fail=0
run() {   # name mode command...
    local name=$1 mode=$2
    shift 2
    if timeout 120 "$@" > "$work/$name.$mode.out" 2>&1; then
        pass=$((pass + 1))
        printf '%-8s %-6s ok    %s\n' "$name" "$mode" "$(tail -n 1 "$work/$name.$mode.out")"
    else
        fail=$((fail + 1))
        printf '%-8s %-6s FAIL\n' "$name" "$mode"
        sed 's/^/    /' "$work/$name.$mode.out" | tail -n 25
    fi
}
for f in "$here"/*.goose; do
    name="$(basename "$f" .goose)"
    if [ "$name" != "threads" ]; then
        run "$name" jit "$GOOSE" "$f" -- --selftest
    fi
    if "$GOOSE" build "$f" -o "$work/$name" > "$work/$name.build.out" 2>&1; then
        run "$name" native "$work/$name" --selftest
    else
        fail=$((fail + 1))
        printf '%-8s %-6s FAIL (build)\n' "$name" native
        sed 's/^/    /' "$work/$name.build.out" | tail -n 25
    fi
done
# shared/: a Goose library built with --shared, called from a C program (needs a C compiler)
if command -v "${CC:-cc}" > /dev/null 2>&1; then
    mkdir -p "$work/shared"
    if (cd "$work/shared" && "$GOOSE" build --shared --header "$work/shared/counter.h" -o "$work/shared/libcounter.so" "$here/shared/counter.goose" &&
        "${CC:-cc}" "$here/shared/host.c" -I. -L. -lcounter -Wl,-rpath,'$ORIGIN' -o host) > "$work/shared.build.out" 2>&1; then
        run shared native "$work/shared/host" --selftest
    else
        fail=$((fail + 1))
        printf '%-8s %-6s FAIL (build)\n' shared native
        sed 's/^/    /' "$work/shared.build.out" | tail -n 25
    fi
fi
echo "examples: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
