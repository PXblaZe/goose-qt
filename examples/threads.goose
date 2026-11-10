// threads: worker threads reporting to the GUI through qt::post.
// Native builds only (the JIT runs no threads):
//
//   goose build threads.goose -o threads && ./threads              four workers fill a progress bar
//   goose build threads.goose -o threads && ./threads --selftest   checks every report arrived, then quits
//
// Qt objects belong to the GUI thread: every other qt call must come from it,
// and one from another thread fails with ERR_WRONG_THREAD instead of racing.
// qt::post is the exception: any thread may call it, and the event it queues
// wakes qt::wait in the GUI thread.
import os;
import qt from "..";

let WORKERS = 4;
let STEPS = 250;
let T_PROGRESS: u64 = 1;
let T_DONE: u64 = 2;

thread_fn work(id: i64, steps: i64) {
    var checksum = 0;
    for step in steps {
        for k in 2000 { checksum += ((step + 1) * k) % 7; }   // some work
        qt::post(T_PROGRESS, id, step + 1);
    }
    qt::post(T_DONE, id, checksum);
}

fn main() {
    let argv = args();
    let selftest = argv.len > 1 && argv[1] == "--selftest";
    if !qt::init() {
        print("qt::init: ", qt::last_error_message());
        exit(1);
    }

    let bar = qt::QProgressBar();
    bar.setWindowTitle("Workers");
    bar.setMaximum(WORKERS * STEPS);
    bar.resize(360, 60);
    bar.show();

    var ids: i64[>..] = [];
    for t in WORKERS { ids.push(thread_spawn(work, t, STEPS)); }

    var reports = 0;
    var done = 0;
    var ev = default<qt::Event>();
    while qt::wait(-1) == qt::WAIT_EVENTS {
        while qt::poll(ev) {
            if ev.tag == T_PROGRESS {
                reports++;
                bar.setValue(reports);
            } else if ev.tag == T_DONE {
                print("worker ", ev.i0, " done (checksum ", ev.i1, ")");
                done++;
                if done == WORKERS && selftest { qt::quit(); }
            }
        }
    }
    for id in ids { thread_wait(id); }

    var ok = true;
    if selftest {
        let value = bar.value_int();
        ok = reports == WORKERS * STEPS && value == WORKERS * STEPS;
        print("threads: ", reports, " reports, bar at ", value, ": ", if ok { "ok" } else { "FAIL" });
    }
    qt::shutdown();
    if !ok { exit(1); }
}
