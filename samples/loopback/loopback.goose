// loopback: Qt's networking driven from Goose. An echo server and 16 clients talk over TCP on
// 127.0.0.1, each client keeping 8 records of 32 bytes in flight; every record that comes back
// is checked byte by byte and in order. Then one client streams 64 MB to a second server that
// checksums what arrives. It all runs on the GUI thread's event loop: Qt does the I/O, Goose
// handles each readyRead. Works under the JIT and in a native build:
//
//   goose loopback.goose               a window with live round trips a second; close it to quit
//   goose loopback.goose -- --selftest echo for 2 seconds, then the 64 MB stream; checks both
import os;
import qt from "../..";
import qt.network;

let CLIENTS = 16;
let DEPTH = 8;                   // records each client keeps in flight
let REC = 32;                    // bytes a record
let BULK = 64 * 1024 * 1024;     // bytes streamed in the second part of the self-test
let CHUNK = 1024 * 1024;         // bytes a write while streaming
let LOW_DELAY = 0;               // QAbstractSocket::LowDelayOption: no Nagle delay for small records

let T_ACCEPT: u64 = 1;           // the echo server has connections waiting
let T_SERVER_READ: u64 = 2;      // a server-side socket has bytes: echo them
let T_CONNECTED: u64 = 3;        // a client is connected: start its records
let T_CLIENT_READ: u64 = 4;      // a client has echoes to check
let T_SINK_ACCEPT: u64 = 5;
let T_SINK_READ: u64 = 6;        // the stream arriving
let T_WRITTEN: u64 = 7;          // the streaming client wrote some: top it up
let T_ERROR: u64 = 8;

var clients: qt::Obj[>..] = [];
var sent: i64[>..] = [];         // records sent, per client
var checked: i64[>..] = [];      // records come back and checked, per client
var fill: i64[>..] = [];         // bytes of a partly arrived record, per client
var partial: u8[>..] = [];       // CLIENTS * REC bytes: those partial records
var connected = 0;
var bad_records = 0;
var socket_errors = 0;
var running = true;              // false: clients stop sending new records

// a record: the client's index, its sequence number, and filler that depends on both
fn record_byte(c: i64, seq: i64, k: i64) -> u8 {
    if k == 0 { return c as u8; }
    if k <= 8 { return ((seq as u64) >> ((8 * (k - 1)) as u64)) as u8; }
    return (seq * 31 + c * 7 + k) as u8;
}

fn send_records(c: i64, n: i64) {
    if n <= 0 { return; }
    var out: u8[>..] = [];
    for _ in n {
        for k in REC { out.push(record_byte(c, sent[c], k)); }
        sent[c] = sent[c] + 1;
    }
    clients[c].write(out);
}

fn client_index(h: u64) -> i64 {
    for c in CLIENTS { if clients[c].h == h { return c; } }
    return -1;
}

fn on_client_read(c: i64) {
    let data = clients[c].readAll();
    var done = 0;
    for b in data {
        partial[c * REC + fill[c]] = b;
        fill[c] = fill[c] + 1;
        if fill[c] == REC {
            for k in REC {
                if partial[c * REC + k] != record_byte(c, checked[c], k) { bad_records++; break; }
            }
            checked[c] = checked[c] + 1;
            fill[c] = 0;
            done++;
        }
    }
    if running { send_records(c, done); }   // one record out for each one back
}

fn total_checked() -> i64 {
    var n = 0;
    for c in CLIENTS { n += checked[c]; }
    return n;
}

fn in_flight() -> i64 {
    var n = 0;
    for c in CLIENTS { n += sent[c] - checked[c]; }
    return n;
}

// the stream's state
var sink = qt::NONE;
var streamer = qt::NONE;
var streamed = 0;                // bytes handed to the streaming socket
var arrived = 0;                 // bytes the sink has read
var sum_sent: u64 = 0;
var sum_arrived: u64 = 0;
var chunk: u8[>..] = [];

fn mix(sum: u64, data: const u8[:]) -> u64 {   // order-sensitive: a lost or swapped byte shows
    var s = sum;
    for b in data { s = (s ^ b) * 1099511628211; }
    return s;
}

fn top_up() {
    while streamed < BULK && streamer.bytesToWrite() < 4 * CHUNK {
        let n = if BULK - streamed < CHUNK { BULK - streamed } else { CHUNK };
        if n == CHUNK {
            streamer.write(chunk);
            sum_sent = mix(sum_sent, chunk);
        } else {
            var tail: u8[>..] = [];
            for i in n { tail.push(chunk[i]); }
            streamer.write(tail);
            sum_sent = mix(sum_sent, tail);
        }
        streamed += n;
    }
}

fn low_delay(s: qt::Obj) {
    let on = qt::val(1);
    s.setSocketOption(LOW_DELAY, on);
    on.free();
}

fn accept_all(server: qt::Obj, read_tag: u64) {
    while true {
        let s = server.nextPendingConnection();
        if s.h == 0 { break; }
        low_delay(s);
        qt::connect(s, "readyRead", read_tag, qt::CONN_COALESCE);
        if read_tag == T_SINK_READ { sink = s; }
    }
}

// one pass over the events that are waiting; false once the last window closes
fn pump(timeout_ms: i64) -> bool {
    let w = qt::wait(timeout_ms);
    if w == qt::WAIT_QUIT { return false; }
    var ev = default<qt::Event>();
    while qt::poll(ev) {
        let src = qt::Obj { h: ev.source };
        if ev.tag == T_ACCEPT { accept_all(src, T_SERVER_READ); }
        else if ev.tag == T_SERVER_READ { src.write(src.readAll()); }   // the echo
        else if ev.tag == T_CONNECTED {
            connected++;
            let c = client_index(ev.source);
            if c >= 0 { send_records(c, DEPTH); }
        }
        else if ev.tag == T_CLIENT_READ {
            let c = client_index(ev.source);
            if c >= 0 { on_client_read(c); }
        }
        else if ev.tag == T_SINK_ACCEPT { accept_all(src, T_SINK_READ); }
        else if ev.tag == T_SINK_READ {
            let data = src.readAll();
            arrived += data.len;
            sum_arrived = mix(sum_arrived, data);
        }
        else if ev.tag == T_WRITTEN { top_up(); }
        else if ev.tag == T_ERROR { socket_errors++; }
    }
    return true;
}

fn ms(t0: i64) -> f64 { return (clock_ns() - t0) / 1e6; }

fn listen_local(server: qt::Obj) -> bool {
    let addr = qt::QHostAddress("127.0.0.1");
    let ok = server.listen(addr, 0);   // port 0: any free port
    addr.free();
    return ok;
}

fn main() {
    var selftest = false;
    for a in args() { if a == "--selftest" { selftest = true; } }
    let started = if selftest { qt::init(qt::APP_CORE, "loopback") } else { qt::init() };
    if !started { print("loopback: ", qt::last_error_message()); exit(1); }
    let objects0 = qt::live_objects();
    let values0 = qt::live_values();

    let server = qt::QTcpServer();
    if !listen_local(server) { print("loopback: listen: ", qt::last_error_message()); exit(1); }
    qt::connect(server, "newConnection", T_ACCEPT);
    let port = server.serverPort();

    for c in CLIENTS {
        let s = qt::QTcpSocket();
        low_delay(s);
        qt::connect(s, "connected", T_CONNECTED);
        qt::connect(s, "readyRead", T_CLIENT_READ, qt::CONN_COALESCE);
        qt::connect(s, "errorOccurred", T_ERROR);
        clients.push(s);
        sent.push(0);
        checked.push(0);
        fill.push(0);
        for _ in REC { partial.push(0); }
        s.connectToHost("127.0.0.1", port);
    }

    var label = qt::NONE;
    if !selftest {
        let window = qt::QWidget();
        window.setWindowTitle(str("Loopback: ", CLIENTS, " clients on 127.0.0.1:", port));
        let layout = qt::QVBoxLayout(window);
        label = qt::QLabel("connecting");
        let mono = qt::QFont("monospace", 12);
        label.setFont(mono);
        mono.free();
        layout.addWidget(label);
        window.resize(520, 140);
        window.show();
        var t_last = clock_ns();
        var n_last = 0;
        while pump(50) {
            if ms(t_last) >= 500.0 {
                let n = total_checked();
                let rate = (n - n_last) * 1000.0 / ms(t_last);
                label.setText(str(connected, " of ", CLIENTS, " clients connected\n",
                                  (rate as! i64), " round trips a second (", (rate * REC * 2 / 1e6) as! i64, " MB/s both ways)\n",
                                  n, " records checked, ", bad_records, " wrong, ", in_flight(), " in flight"));
                t_last = clock_ns();
                n_last = n;
            }
        }
        qt::shutdown();
        return;
    }

    // part one: echo for two seconds
    var t = clock_ns();
    while connected < CLIENTS && ms(t) < 5000.0 { pump(10); }
    let t_connect = ms(t);
    t = clock_ns();
    while ms(t) < 2000.0 { pump(10); }
    running = false;
    while in_flight() > 0 && ms(t) < 7000.0 { pump(10); }   // let the last records come home
    let t_echo = ms(t);
    let records = total_checked();

    // part two: one client streams 64 MB to a second server
    let sink_server = qt::QTcpServer();
    listen_local(sink_server);
    qt::connect(sink_server, "newConnection", T_SINK_ACCEPT);
    for i in CHUNK { chunk.push((i * 2654435761 >> 13) as u8); }
    streamer = qt::QTcpSocket();
    qt::connect(streamer, "bytesWritten", T_WRITTEN, qt::CONN_COALESCE);
    qt::connect(streamer, "errorOccurred", T_ERROR);
    streamer.connectToHost("127.0.0.1", sink_server.serverPort());
    t = clock_ns();
    if streamer.waitForConnected(5000) { top_up(); }
    while arrived < BULK && ms(t) < 60000.0 { pump(10); }
    let t_bulk = ms(t);

    print("loopback: ", CLIENTS, " clients, ", DEPTH, " records of ", REC, " bytes in flight each (Qt ",
          qt::qt_version(), ")");
    print("  connected in      ", ((t_connect * 10.0) as! i64) / 10.0, " ms");
    print("  echo, 2 seconds   ", records, " records round trip, ", (records * 1000.0 / t_echo) as! i64,
          " a second; ", bad_records, " wrong, ", in_flight(), " lost");
    print("  stream            ", arrived / (1024 * 1024), " MB in ", t_bulk as i64, " ms (",
          (arrived / 1048576.0 / t_bulk * 1000.0) as! i64, " MB/s), checksum ",
          if sum_arrived == sum_sent && arrived == BULK { "equal" } else { "DIFFERENT" });

    // tidy up, then check nothing is left behind
    for s in clients { s.disconnectFromHost(); qt::destroy(s); }
    qt::destroy(streamer);
    qt::destroy(server);        // the server-side sockets are its children
    qt::destroy(sink_server);
    qt::process_events();
    let left_objects = qt::live_objects() - objects0;
    let left_values = qt::live_values() - values0;
    print("  socket errors     ", socket_errors, "; left over: ", left_objects, " objects, ", left_values, " values");

    let ok = connected == CLIENTS && records > 1000 && bad_records == 0 && in_flight() == 0
             && arrived == BULK && sum_arrived == sum_sent && socket_errors == 0
             && left_objects == 0 && left_values == 0;
    print("loopback: ", if ok { "ok" } else { "FAIL" });
    qt::shutdown();
    if !ok { exit(1); }
}
