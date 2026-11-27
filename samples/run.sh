#!/usr/bin/env bash
# Runs every sample in its --selftest mode and prints what each measured.
#
#   samples/run.sh                   all samples: with the JIT and as native builds
#   samples/run.sh million notes     some of them
#   samples/run.sh --quick           a shorter chaos run (what ctest uses)
#   GOOSE=/path/to/goose QTC_LIB=/path/to/qtc/build samples/run.sh
#
# QTC_LIB is the directory with libqtc.so.1; it goes first on the library path. scope and
# mandelbrot use threads, which only native builds have, so they run native only. The samples
# pick the offscreen platform themselves, except mandelbrot, which wants a display for its GPU
# half: with none it runs under xvfb-run when that is installed, and on the CPU alone when not.
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
    case "$(uname -s)" in   # Windows finds DLLs on PATH
        MINGW* | MSYS* | CYGWIN*) export PATH="$(cygpath -u "$QTC_LIB"):$PATH" ;;
    esac
fi
# macOS has no timeout command: Perl's alarm does the same. macOS clears DYLD_LIBRARY_PATH for
# its own programs, /usr/bin/perl among them, so the path goes to Perl as an argument
if ! command -v timeout > /dev/null 2>&1; then
    timeout() {
        local secs=$1; shift
        perl -e 'my ($s, $d) = splice @ARGV, 0, 2; $ENV{DYLD_LIBRARY_PATH} = $d if $d ne "";
                 alarm $s; exec @ARGV or exit 127' "$secs" "${DYLD_LIBRARY_PATH:-}" "$@"
    }
fi
# Qt's own warnings off: chaos makes thousands on purpose (Qt refusing hostile values), and the
# offscreen platform and the GPU probe add a few harmless ones. Errors still show.
export QT_LOGGING_RULES="*.warning=false"
export LC_ALL="${LC_ALL:-C.UTF-8}"

quick=0
samples=()
for a in "$@"; do
    if [ "$a" = "--quick" ]; then quick=1; else samples+=("$a"); fi
done
[ ${#samples[@]} -gt 0 ] || samples=(chaos million loopback notes scope mandelbrot)
chaos_ops=300000
[ "$quick" -eq 1 ] && chaos_ops=50000

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"
pass=0
fail=0
failed=()
run() {   # name mode command...
    local name=$1 mode=$2
    shift 2
    local out="$work/$name.$mode.out"
    printf '== %s (%s)\n' "$name" "$mode"
    if timeout 300 "$@" > "$out" 2>&1; then
        pass=$((pass + 1))
        sed 's/^/   /' "$out"
    else
        fail=$((fail + 1))
        failed+=("$name ($mode)")
        sed 's/^/   /' "$out" | tail -n 30
        echo "   FAILED"
    fi
}
build() {   # name: builds samples/<name>/<name>.goose into $work/<name>
    if "$GOOSE" build "$here/$1/$1.goose" -o "$work/$1" > "$work/$1.build.out" 2>&1; then
        return 0
    fi
    fail=$((fail + 1))
    failed+=("$1 (build)")
    printf '== %s (native)\n' "$1"
    sed 's/^/   /' "$work/$1.build.out" | tail -n 30
    echo "   FAILED to build"
    return 1
}
for s in "${samples[@]}"; do
    if [ ! -f "$here/$s/$s.goose" ]; then
        echo "no sample named $s" >&2
        fail=$((fail + 1))
        continue
    fi
    case "$s" in
        chaos)
            run chaos jit "$GOOSE" "$here/chaos/chaos.goose" -- --selftest
            build chaos && run chaos native "$work/chaos" --ops "$chaos_ops" --seed 1 ;;
        scope)
            build scope && run scope native "$work/scope" --selftest ;;
        mandelbrot)
            if build mandelbrot; then
                if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v xvfb-run > /dev/null 2>&1; then
                    run mandelbrot native xvfb-run -a "$work/mandelbrot" --selftest
                else
                    run mandelbrot native "$work/mandelbrot" --selftest
                fi
            fi ;;
        *)
            run "$s" jit "$GOOSE" "$here/$s/$s.goose" -- --selftest
            build "$s" && run "$s" native "$work/$s" --selftest ;;
    esac
done
echo "samples: $pass passed, $fail failed${failed[*]:+ (${failed[*]})}"
[ "$fail" -eq 0 ]
