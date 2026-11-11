// million: a table of a million rows whose data lives in Goose. A QAbstractTableModel is
// subclassed from Goose (rowCount, columnCount, data and headerData are Goose functions), a
// QTableView shows it, and a QSortFilterProxyModel filters it as you type: Qt asks Goose for
// every cell it shows and every row it filters, a million times over for a filter.
//
//   goose build million.goose -o million && ./million      a window: type in the box to filter
//   ./million --selftest                                   scrolls, jumps, filters, sorts; prints timings
//
// Override handlers run in the middle of Qt's own calls, so they go through one exported
// function (goose_qt_override) that a small C trampoline calls; see docs/subclassing.md.
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
let T_SELFTEST: u64 = 6;

let DISPLAY_ROLE = 0;
let ALIGNMENT_ROLE = 7;
let HORIZONTAL = 1;

var prices: f64[>..] = [];
var data_calls = 0;

fn price(row: i64) -> f64 { return prices[row]; }

export "goose_qt_override" fn on_override(obj: u64, tag: u64, nargs: i64, depth: i64) -> i32 {
    if tag == T_ROWS || tag == T_COLS {
        // a table has rows only at the top: an index's children are none
        if qt::ov_arg_index(0).valid { qt::ov_ret(0); } else { qt::ov_ret(if tag == T_ROWS { ROWS } else { COLS }); }
        return qt::OV_DONE;
    }
    if tag == T_DATA {
        let ix = qt::ov_arg_index(0);
        let role = qt::ov_arg_int(1);
        if !ix.valid || ix.row < 0 || ix.row >= ROWS { return qt::OV_BASE; }
        data_calls++;
        if role == DISPLAY_ROLE {
            if ix.column == 0 { qt::ov_ret(ix.row); }
            else if ix.column == 1 { qt::ov_ret(str("item ", ix.row)); }
            else if ix.column == 2 { qt::ov_ret(price(ix.row)); }
            else { qt::ov_ret(CATEGORIES[ix.row % CATEGORIES.len]); }
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

fn ms(t0: i64) -> f64 { return (clock_ns() - t0) / 1e6; }

// how many of 0 .. ROWS-1 contain the digits of needle: what the filter must find
fn expected_matches(needle: const u8[:]) -> i64 {
    var n = 0;
    for row in ROWS {
        let s = str("item ", row);
        var found = false;
        var i = 0;
        while !found && i + needle.len <= s.len {
            var same = true;
            for j in needle.len { if s[i + j] != needle[j] { same = false; } }
            if same { found = true; }
            i++;
        }
        if found { n++; }
    }
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
    for row in ROWS { prices.push(((row * 7919) % 100000) / 100.0 + 0.99); }
    let t_data = ms(t);

    t = clock_ns();
    let model = qt::new_overridable("QAbstractTableModel");
    qt::override(model, "rowCount", T_ROWS);
    qt::override(model, "columnCount", T_COLS);
    qt::override(model, "data", T_DATA);
    qt::override(model, "headerData", T_HEADER);
    let proxy = qt::QSortFilterProxyModel();
    proxy.setSourceModel(model);
    proxy.setFilterKeyColumn(1);

    let window = qt::QWidget();
    window.setWindowTitle("A million rows from Goose");
    let layout = qt::QVBoxLayout(window);
    let search = qt::QLineEdit();
    search.setPlaceholderText("filter by name, e.g. 4242");
    let status = qt::QLabel(str(ROWS, " rows"));
    let view = qt::QTableView();
    view.setModel(proxy);
    view.setSortingEnabled(false);
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
                    proxy.setFilterFixedString(search.text());
                    status.setText(str(proxy.rowCount(), " of ", ROWS, " rows, filtered in ", ms(t0) as i64,
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
    let last_text = cell_str(proxy, ROWS - 1, 1);

    // filtering: every row's name goes through Goose
    let needle = "4242";
    let want = expected_matches(needle);
    let calls1 = data_calls;
    t = clock_ns();
    search.setText(needle);
    proxy.setFilterFixedString(needle);
    let matched = proxy.rowCount();
    let t_filter = ms(t);
    let filter_calls = data_calls - calls1;

    // sorting what the filter left, by price, highest first
    t = clock_ns();
    proxy.sort(2, qt::Qt.DescendingOrder);
    paint(view);
    let t_sort = ms(t);
    var sorted = true;
    var prev = 1e18;
    for i in matched {
        let p = cell_f64(proxy, i, 2);
        if p > prev { sorted = false; }
        prev = p;
    }

    print("million: ", ROWS, " rows x ", COLS, " columns served from Goose (qtc ", qt::version(), ", Qt ", qt::qt_version(), ")");
    print("  data made in Goose          ", t_data as i64, " ms");
    print("  model, view, first paint    ", t_first as i64, " ms");
    print("  200 pages scrolled, painted ", t_scroll as i64, " ms (", (pages * 1000.0 / t_scroll) as i64, " pages/s, ",
          scroll_calls, " cells asked for)");
    print("  filter over all rows        ", t_filter as i64, " ms (", filter_calls, " calls into Goose, ",
          (filter_calls / t_filter * 1000.0) as i64, " per second): ", matched, " match \"", needle, "\"");
    print("  sort of the matches         ", t_sort as i64, " ms");
    let ok = last_text == "item 999999" && matched == want && sorted && filter_calls >= ROWS;
    print("million: last row \"", last_text, "\", ", matched, " of ", want, " expected matches, sorted ", sorted, ": ",
          if ok { "ok" } else { "FAIL" });
    qt::shutdown();
    if !ok { exit(1); }
}
