// million: a table of a million rows whose data lives in Goose. A QAbstractTableModel is
// subclassed from Goose (rowCount, columnCount, data and headerData are Goose functions) and a
// QTableView shows it. Typing in the box filters the rows: Goose scans its own million rows,
// keeps the list of rows that match and resets the model, so Qt only ever asks for the cells
// on screen. A keystroke costs a few milliseconds, whatever the number of rows.
//
//   goose build million.goose -o million && ./million      a window: type in the box to filter
//   ./million --selftest                                   scrolls, types, sorts; prints timings
//
// Override handlers run in the middle of Qt's own calls, so they go through one exported
// function (goose_qt_override) that a small C trampoline calls; see docs/subclassing.md.
//
// Why not QSortFilterProxyModel? It asks the model for every row on each filter change (a
// million calls into Goose), and when a change removes rows in many separate ranges (typing
// "4" keeps 468,559 rows in tens of thousands of runs) it removes them range by range, which
// grows with rows x ranges: 14 s for that one keystroke. A model that owns its data can do
// the filtering itself and tell views to start over.
import os;
import qt from "../..";

let ROWS = 1000000;
let COLS = 4;
let HEADERS: const u8[:][] = ["#", "name", "price", "category"];
let CATEGORIES: const u8[:][] = ["tools", "books", "garden", "music", "games", "food", "toys"];

let T_ROWS: u64 = 1;
let T_COLS: u64 = 2;
let T_DATA: u64 = 3;
let T_HEADER: u64 = 4;
let T_FILTER: u64 = 5;

let DISPLAY_ROLE = 0;
let ALIGNMENT_ROLE = 7;
let HORIZONTAL = 1;

var prices: f64[>..] = [];
var shown: i32[>..] = [];      // the rows the model shows, in order: indices into the data
var shown_for: u8[>..] = [];   // the filter shown was made for
var data_calls = 0;

// "item <row>", the name column, written into a fixed buffer: no allocation, so a handler
// that formats it holds nothing on Goose's data stacks while Qt is in the middle of a call.
fn name_of(row: i64, out: u8[..24]&) {
    out.clear();
    for c in "item " { out.push(c); }
    var digits: u8[..20] = [];
    var n = row;
    if n == 0 { digits.push('0'); }
    while n > 0 { digits.push(('0' + n % 10) as u8); n /= 10; }
    var i = digits.len - 1;
    while i >= 0 { out.push(digits[i]); i--; }
}

fn contains(hay: const u8[:], needle: const u8[:]) -> bool {
    if needle.len == 0 { return true; }
    var i = 0;
    while i + needle.len <= hay.len {
        var j = 0;
        while j < needle.len && hay[i + j] == needle[j] { j++; }
        if j == needle.len { return true; }
        i++;
    }
    return false;
}

fn matches(row: i64, needle: const u8[:]) -> bool {
    var name: u8[..24] = [];
    name_of(row, name);
    return contains(name, needle);
}

export "goose_qt_override" fn on_override(obj: u64, tag: u64, nargs: i64, depth: i64) -> i32 {
    if tag == T_ROWS || tag == T_COLS {
        // a table has rows only at the top: an index's children are none
        if qt::ov_arg_index(0).valid { qt::ov_ret(0); } else { qt::ov_ret(if tag == T_ROWS { shown.len } else { COLS }); }
        return qt::OV_DONE;
    }
    if tag == T_DATA {
        let ix = qt::ov_arg_index(0);
        let role = qt::ov_arg_int(1);
        if !ix.valid || ix.row < 0 || ix.row >= shown.len { return qt::OV_BASE; }
        data_calls++;
        let row = shown[ix.row] as i64;
        if role == DISPLAY_ROLE {
            if ix.column == 0 { qt::ov_ret(row); }
            else if ix.column == 1 {
                var name: u8[..24] = [];
                name_of(row, name);
                qt::ov_ret(name);
            }
            else if ix.column == 2 { qt::ov_ret(prices[row]); }
            else { qt::ov_ret(CATEGORIES[row % CATEGORIES.len]); }
            return qt::OV_DONE;
        }
        if role == ALIGNMENT_ROLE && (ix.column == 0 || ix.column == 2) {
            qt::ov_ret(0x82);   // Qt::AlignRight | Qt::AlignVCenter
            return qt::OV_DONE;
        }
        return qt::OV_BASE;
    }
    if tag == T_HEADER {
        let section = qt::ov_arg_int(0);
        if qt::ov_arg_int(2) == DISPLAY_ROLE && qt::ov_arg_int(1) == HORIZONTAL && section >= 0 && section < COLS {
            qt::ov_ret(HEADERS[section]);
            return qt::OV_DONE;
        }
        return qt::OV_BASE;
    }
    return qt::OV_BASE;
}

// Shows the rows whose name contains needle. A needle that contains the last one (typing one
// more character) can only narrow what is shown, so only the shown rows are looked at again.
fn set_filter(model: qt::Obj, needle: const u8[:]) {
    qt::call(model, "beginResetModel");
    if shown_for.len > 0 && contains(needle, shown_for) {
        var kept = 0;
        for i in shown.len {
            let row = shown[i];
            if matches(row, needle) { shown[kept] = row; kept++; }
        }
        shown.resize(kept);
    } else {
        shown.clear();
        for row in ROWS { if matches(row, needle) { shown.push(row as i32); } }
    }
    shown_for.clear();
    for c in needle { shown_for.push(c); }
    qt::call(model, "endResetModel");
}

fn ms(t0: i64) -> f64 { return (clock_ns() - t0) / 1e6; }

// how many of 0 .. ROWS-1 have needle in their name, counted the slow, obvious way
fn expected_matches(needle: const u8[:]) -> i64 {
    var n = 0;
    for row in ROWS { if contains(str("item ", row), needle) { n++; } }
    return n;
}

fn cell_str(m: qt::Obj, row: i64, column: i64) -> u8[>..] {
    let ix = m.index(row, column);
    let v = m.data(ix);
    let s = qt::to_str(v);
    v.free();
    ix.free();
    return s;
}

fn cell_f64(m: qt::Obj, row: i64, column: i64) -> f64 {
    let ix = m.index(row, column);
    let v = m.data(ix);
    let x = qt::to_f64(v);
    v.free();
    ix.free();
    return x;
}

fn paint(w: qt::Obj) {   // offscreen, grab() is what makes a widget paint
    let pm = w.grab();
    pm.free();
}

fn main() {
    var selftest = false;
    for a in args() { if a == "--selftest" { selftest = true; } }
    let ok_init = if selftest { qt::init(qt::APP_WIDGETS, "million\0-platform\0offscreen") } else { qt::init() };
    if !ok_init || !qt::use_overrides() {
        print("million: ", qt::last_error_message());
        exit(1);
    }

    var t = clock_ns();
    for row in ROWS {
        prices.push(((row * 7919) % 100000) / 100.0 + 0.99);
        shown.push(row as i32);
    }
    let t_data = ms(t);

    t = clock_ns();
    let model = qt::new_overridable("QAbstractTableModel");
    qt::override(model, "rowCount", T_ROWS);
    qt::override(model, "columnCount", T_COLS);
    qt::override(model, "data", T_DATA);
    qt::override(model, "headerData", T_HEADER);

    let window = qt::QWidget();
    window.setWindowTitle("A million rows from Goose");
    let layout = qt::QVBoxLayout(window);
    let search = qt::QLineEdit();
    search.setPlaceholderText("filter by name, e.g. 4242");
    let status = qt::QLabel(str(ROWS, " rows"));
    let view = qt::QTableView();
    view.setModel(model);
    view.verticalHeader().setVisible(false);
    view.horizontalHeader().setStretchLastSection(true);
    view.setColumnWidth(1, 160);
    layout.addWidget(search);
    layout.addWidget(view);
    layout.addWidget(status);
    window.resize(720, 560);
    window.show();
    paint(view);
    let t_first = ms(t);
    qt::connect(search, "textChanged", T_FILTER, qt::CONN_COALESCE);

    if !selftest {
        var ev = default<qt::Event>();
        while qt::wait(-1) == qt::WAIT_EVENTS {
            while qt::poll(ev) {
                if ev.tag == T_FILTER {
                    let calls0 = data_calls;
                    let t0 = clock_ns();
                    set_filter(model, search.text());
                    status.setText(str(shown.len, " of ", ROWS, " rows, filtered in ", ms(t0) as i64,
                                       " ms (", data_calls - calls0, " calls into Goose)"));
                }
            }
        }
        qt::shutdown();
        return;
    }

    // scrolling: 200 pages, each painted
    let bar = view.verticalScrollBar();
    let calls0 = data_calls;
    t = clock_ns();
    let pages = 200;
    for p in pages {
        bar.setValue(p * ((bar.maximum() as i64) / pages));
        paint(view);
    }
    let t_scroll = ms(t);
    let scroll_calls = data_calls - calls0;

    // the last row
    view.scrollToBottom();
    paint(view);
    let last_text = cell_str(model, ROWS - 1, 1);

    // typing "4242" one key at a time, then deleting it again: each keystroke filters and
    // repaints, the way the window does it
    let keys: const u8[:][] = ["4", "42", "424", "4242", "424", "42", "4", ""];
    var key_ms: f64[>..] = [];
    var key_rows: i64[>..] = [];
    var counts_ok = true;
    let calls1 = data_calls;
    for k in keys {
        t = clock_ns();
        set_filter(model, k);
        paint(view);
        key_ms.push(ms(t));
        key_rows.push(shown.len);
        if k.len > 0 && shown.len != expected_matches(k) { counts_ok = false; }
    }
    let typing_calls = data_calls - calls1;
    var t_typing = 0.0;
    for x in key_ms { t_typing += x; }
    if shown.len != ROWS { counts_ok = false; }

    // what "4242" leaves, sorted by price, highest first
    set_filter(model, "4242");
    let matched = shown.len;
    t = clock_ns();
    qt::call(model, "beginResetModel");
    sort(shown) { a, b => prices[a] > prices[b] };
    qt::call(model, "endResetModel");
    paint(view);
    let t_sort = ms(t);
    var sorted = true;
    var prev = 1e18;
    for i in matched {
        let p = cell_f64(model, i, 2);
        if p > prev { sorted = false; }
        prev = p;
    }

    print("million: ", ROWS, " rows x ", COLS, " columns served from Goose (qtc ", qt::version(), ", Qt ", qt::qt_version(), ")");
    print("  data made in Goose          ", t_data as i64, " ms");
    print("  model, view, first paint    ", t_first as i64, " ms");
    print("  200 pages scrolled, painted ", t_scroll as i64, " ms (", (pages * 1000.0 / t_scroll) as i64, " pages/s, ",
          scroll_calls, " cells asked for)");
    var line: u8[>..] = [];
    for c in "  typed and deleted \"4242\"    " { line.push(c); }
    for i in keys.len {
        for c in str(if i > 0 { ", " } else { "" }, "\"", keys[i], "\" ", key_ms[i] as i64, " ms") { line.push(c); }
    }
    print(line);
    print("                               ", t_typing as i64, " ms for ", keys.len, " keystrokes, each filtering ", ROWS,
          " rows or fewer (", typing_calls, " cells asked for)");
    print("  sort of the ", matched, " matches   ", t_sort as i64, " ms");
    let ok = last_text == "item 999999" && counts_ok && sorted && matched == expected_matches("4242");
    print("million: last row \"", last_text, "\", filter counts ", if counts_ok { "right" } else { "WRONG" },
          ", sorted ", sorted, ": ", if ok { "ok" } else { "FAIL" });
    qt::shutdown();
    if !ok { exit(1); }
}
