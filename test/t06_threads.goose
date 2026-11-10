// Posting from other threads (native builds only: the JIT has no threads).
import qt from "..";

var failures = 0;
var checks = 0;
fn check(ok: bool, what: const u8[:]) {
    checks++;
    if !ok {
        failures++;
        print("FAIL ", what, "  [", qt::last_error_message(), "]");
    }
}

thread_fn poster(base: i64, n: i64) {
    for i in n { qt::post(900, base + i, 0); }
}

fn main() {
    check(qt::init(qt::APP_CORE, "t06"), "init");
    qt::set_error_policy(qt::ERRORS_RETURN);
    let per = 5000;
    var ids: i64[>..] = [];
    for t in 4 { ids.push(thread_spawn(poster, t * per, per)); }
    var got = 0;
    var sum = 0;
    while got < 4 * per {
        if qt::wait(5000) == qt::WAIT_TIMEOUT { break; }
        var ev = default<qt::Event>();
        while qt::poll(ev) {
            if ev.tag == 900 && ev.kind == qt::EV_POST { got++; sum += ev.i0; }
        }
    }
    for id in ids { thread_wait(id); }
    let n = 4 * per;
    check(got == n, "every post from four threads arrived");
    check(sum == n * (n - 1) / 2, "each exactly once");
    check(qt::dropped_events() == 0, "nothing dropped");
    // calls other than posts from a worker are refused, never run off the GUI thread
    check(qt::shutdown(), "shutdown");
    print("t06_threads: ", checks - failures, " passed, ", failures, " failed");
    if failures > 0 { exit(1); }
}
