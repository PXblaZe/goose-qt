// Futures filled by Goose worker threads, watched and waited for on the GUI thread; worker
// objects (native builds only: the JIT has no threads).
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

// Squares 0..n-1 into the future, with progress; stops early when canceled.
thread_fn squares(id: u64, n: i64) {
    let f = qt::Future { id: id };
    qt::progress_range(f, 0, n);
    for i in n {
        if qt::canceled(f) { return; }
        qt::add(f, i * i);
        qt::progress(f, i + 1);
    }
    qt::finish(f);
}

thread_fn failing(id: u64) {
    let f = qt::Future { id: id };
    qt::add(f, "partial");
    qt::fail(f, "the disk is full");
}

thread_fn endless(id: u64) {
    let f = qt::Future { id: id };
    var i = 0;
    while !qt::canceled(f) {
        qt::progress(f, i % 100);
        i++;
    }
}

fn main() {
    check(qt::init(), "init");
    qt::set_error_policy(qt::ERRORS_RETURN);
    let futures0 = qt::live_futures();

    // results and progress, watched as events
    let f = qt::promise();
    check(f.id != 0, "a promise");
    let w = qt::watch(f, 70);
    check(w != 0, "watched");
    let t = thread_spawn(squares, f.id, 1000);
    check(qt::wait(f, 10000) == qt::WAIT_FINISHED, "the worker finished it");
    thread_wait(t);
    check(qt::is_finished(f) && !qt::is_failed(f), "finished, not failed");
    check(qt::result_count(f) == 1000, "every result");
    check(qt::result_int(f, 999) == 999 * 999, "the last one");
    check(qt::result_int(f, 31) == 961, "one in the middle");
    let p = qt::progress(f);
    check(p.value == 1000 && p.max == 1000, "progress reached the end");
    var finished_events = 0;
    var progress_events = 0;
    qt::process_events();
    var ev = default<qt::Event>();
    while qt::poll(ev) {
        if ev.tag == 70 && ev.kind == qt::EV_FUTURE_FINISHED { finished_events++; }
        if ev.tag == 70 && ev.kind == qt::EV_FUTURE_PROGRESS { progress_events++; }
    }
    check(finished_events == 1, "one finished event");
    check(progress_events >= 1, "progress events");
    check(!qt::result(f, 1000), "past the results is an error");
    check(qt::release(f), "released");
    check(!qt::release(f), "once");

    // failure
    let g = qt::promise();
    let t2 = thread_spawn(failing, g.id);
    check(qt::wait(g, 10000) == qt::WAIT_FINISHED, "a failing worker finishes it too");
    thread_wait(t2);
    check(qt::is_failed(g), "failed");
    check(qt::error(g) == "the disk is full", "with its message");
    check(qt::result_str(g, 0) == "partial", "results before the failure stay");
    qt::release(g);

    // cancel
    let h = qt::promise();
    let t3 = thread_spawn(endless, h.id);
    check(qt::wait(h, 50) == qt::WAIT_TIMEOUT, "still running");
    check(qt::cancel(h), "canceled");
    thread_wait(t3);
    check((qt::state(h) & qt::FUT_CANCELED) != 0, "the worker saw it and stopped");
    qt::release(h);

    // whichever finishes first
    let a = qt::promise();
    let b = qt::promise();
    let first = qt::any(a, b);
    qt::add(b, 1);
    qt::finish(b);
    check(qt::wait(first, 5000) == qt::WAIT_FINISHED, "any() finished with b");
    check(qt::result_int(first, 0) as u64 == b.id, "its result names b");
    qt::finish(a);
    let both = qt::all(a, b);
    check(qt::wait(both, 5000) == qt::WAIT_FINISHED, "all() finished");
    qt::release(first);
    qt::release(both);
    qt::release(a);
    qt::release(b);

    // a call queued to an object, and one to a worker object on its own thread
    let timer = qt::QTimer();
    timer.setInterval(123);
    let fi = qt::invoke_future(timer, "interval");
    check(qt::wait(fi, 5000) == qt::WAIT_FINISHED, "a queued call's future");
    check(qt::result_int(fi, 0) == 123, "with the call's result");
    qt::release(fi);
    let thread = qt::QThread();
    thread.start();
    let worker = qt::QTimer();
    worker.setObjectName("worker");
    check(qt::move_to_thread(worker, thread), "moved to the thread");
    let fw = qt::invoke_future(worker, "objectName");
    check(qt::wait(fw, 5000) == qt::WAIT_FINISHED, "called on its thread");
    check(qt::result_str(fw, 0) == "worker", "there");
    qt::release(fw);
    qt::arg(55);
    check(qt::invoke_queued(worker, "setInterval"), "a call queued there");
    thread.quit();
    thread.wait();
    check(qt::live_futures() == futures0, "every future released");
    check(qt::shutdown(), "shutdown");
    print("t08_futures: ", checks - failures, " passed, ", failures, " failed");
    if failures > 0 { exit(1); }
}
