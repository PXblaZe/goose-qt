// notes: a small but complete desktop app. A main window with menus, shortcuts, a toolbar and a
// status bar; a searchable list of notes; an editor with a live Markdown preview; and the notes
// kept as JSON, saved atomically. The notes live in a qtc list of maps, so saving is qt::json and
// loading qt::from_json. Works under the JIT and in a native build:
//
//   goose notes.goose                      the app, keeping its notes in notes.json here
//   goose notes.goose -- --file my.json    another file
//   goose notes.goose -- --selftest        offscreen: 2,000 notes made, edited, searched, saved,
//                                          loaded back and compared, through the app's own actions
import os;
import qt from "../..";

let T_NEW: u64 = 1;
let T_DELETE: u64 = 2;
let T_SAVE: u64 = 3;
let T_RELOAD: u64 = 4;
let T_QUIT: u64 = 5;
let T_PREVIEW: u64 = 6;
let T_SELECT: u64 = 7;          // the list's current row changed
let T_EDITED: u64 = 8;          // the editor's text changed (coalesced)
let T_SEARCH: u64 = 9;          // the search text changed (coalesced)

var notes = qt::Val { h: 0 };   // a list of maps: {"body": text, "modified": ISO date}
var current = -1;
var dirty = false;
var path = str("notes.json");

var window = qt::NONE;
var list = qt::NONE;
var list_model = qt::NONE;
var editor = qt::NONE;
var preview = qt::NONE;
var search = qt::NONE;
var status = qt::NONE;
var act_new = qt::NONE;
var act_save = qt::NONE;
var act_reload = qt::NONE;
var act_delete = qt::NONE;
var act_preview = qt::NONE;

// --- the notes

fn field(i: i64, key: const u8[:]) -> u8[>..] {
    let m = qt::list_get(notes, i);
    let v = qt::map_get(m, key);
    let s = qt::to_str(v);
    v.free();
    m.free();
    return s;
}

fn now() -> u8[>..] {
    let t = qt::QDateTime_currentDateTime();
    let s = t.toString(qt::Qt.ISODate);
    t.free();
    return s;
}

fn put(m: qt::Val, key: const u8[:], text: const u8[:]) {
    let v = qt::val(text);
    qt::map_set(m, key, v);
    v.free();
}

// a note's title: its first line without the Markdown heading marks, or "Untitled"
fn title(body: const u8[:]) -> u8[>..] {
    var t: u8[>..] = [];
    var i = 0;
    while i < body.len && (body[i] == '#' || body[i] == ' ') { i++; }
    while i < body.len && body[i] != '\n' && t.len < 60 { t.push(body[i]); i++; }
    if t.len == 0 { return str("Untitled"); }
    return t;
}

fn lower(c: u8) -> u8 { return if c >= 'A' && c <= 'Z' { c + 32 } else { c }; }

fn contains(hay: const u8[:], needle: const u8[:]) -> bool {   // ASCII case-insensitive
    if needle.len == 0 { return true; }
    var i = 0;
    while i + needle.len <= hay.len {
        var k = 0;
        while k < needle.len && lower(hay[i + k]) == lower(needle[k]) { k++; }
        if k == needle.len { return true; }
        i++;
    }
    return false;
}

fn set_row_text(row: i64, text: const u8[:]) {
    let ix = qt::index(list_model, row, 0);
    let v = qt::val(text);
    list_model.setData(ix, v);
    v.free();
    ix.free();
}

fn row_text(row: i64) -> u8[>..] {
    let ix = qt::index(list_model, row, 0);
    let v = list_model.data(ix);
    let s = qt::to_str(v);
    v.free();
    ix.free();
    return s;
}

fn add_note(body: const u8[:]) -> i64 {
    let m = qt::new_map();
    put(m, "body", body);
    put(m, "modified", now());
    qt::list_append(notes, m);
    m.free();
    list.addItem(title(body));
    return qt::list_len(notes) - 1;
}

fn show_status() {
    let n = qt::list_len(notes);
    var words = 0;
    if current >= 0 {
        var in_word = false;
        for c in editor.toPlainText() {
            let space = c == ' ' || c == '\n' || c == '\t';
            if !space && !in_word { words++; }
            in_word = !space;
        }
    }
    let this_one: u8[>..] = if current >= 0 { str(", this one ", words, " words") } else { str("") };
    status.showMessage(str(n, if n == 1 { " note" } else { " notes" }, this_one, if dirty { "  (not saved)" } else { "" }));
}

fn select(i: i64) {
    current = i;
    let body = if i >= 0 { field(i, "body") } else { str("") };
    editor.blockSignals(true);          // showing a note is not editing it
    editor.setPlainText(body);
    editor.blockSignals(false);
    editor.setEnabled(i >= 0);
    preview.setMarkdown(body);
    show_status();
}

fn edited() {
    if current < 0 { return; }
    let body = editor.toPlainText();
    let m = qt::list_get(notes, current);
    put(m, "body", body);
    put(m, "modified", now());
    qt::list_set(notes, current, m);
    m.free();
    set_row_text(current, title(body));
    if act_preview.isChecked() { preview.setMarkdown(body); }
    dirty = true;
    show_status();
}

fn filter(needle: const u8[:]) -> i64 {
    var shown = 0;
    for i in qt::list_len(notes) {
        let hit = contains(field(i, "body"), needle);
        list.setRowHidden(i, !hit);
        if hit { shown++; }
    }
    return shown;
}

fn delete_current() {
    if current < 0 { return; }
    let gone = current;
    qt::list_remove(notes, gone);
    list.blockSignals(true);
    list_model.removeRow(gone);
    list.blockSignals(false);
    dirty = true;
    let n = qt::list_len(notes);
    let next = if gone < n { gone } else { n - 1 };
    list.setCurrentRow(next);
    select(next);
}

fn save() -> bool {
    let ok = write_file_atomic(path, qt::json(notes));   // a crash mid-save leaves the old file
    if ok { dirty = false; }
    let msg: u8[>..] = if ok { str("saved ", qt::list_len(notes), " notes to ", path) } else { str("could not save ", path) };
    status.showMessage(msg);
    return ok;
}

fn load() -> bool {
    var text: u8[>..] = [];
    if !read_file(path, text) { return false; }
    let v = qt::from_json(text);
    if v.h == 0 || qt::type_name(v) != "QVariantList" {
        v.free();
        status.showMessage(str(path, " is not a notes file"));
        return false;
    }
    notes.free();
    notes = v;
    list.blockSignals(true);
    list.clear();
    for i in qt::list_len(notes) { list.addItem(title(field(i, "body"))); }
    list.blockSignals(false);
    dirty = false;
    let first = if qt::list_len(notes) > 0 { 0 } else { -1 };
    list.setCurrentRow(first);
    select(first);
    return true;
}

// --- the window

fn action(menu: qt::Obj, text: const u8[:], keys: const u8[:], tag: u64) -> qt::Obj {
    let ks = qt::QKeySequence(keys);
    let a = menu.addAction(text, ks);
    ks.free();
    qt::connect(a, "triggered", tag);
    return a;
}

fn build() {
    window = qt::QMainWindow();
    window.setWindowTitle(str("Notes: ", path));
    let file = window.menuBar().addMenu("&File");
    act_new = action(file, "&New note", "Ctrl+N", T_NEW);
    act_save = action(file, "&Save", "Ctrl+S", T_SAVE);
    act_reload = action(file, "&Reload from disk", "Ctrl+R", T_RELOAD);
    file.addSeparator();
    action(file, "&Quit", "Ctrl+Q", T_QUIT);
    let edit = window.menuBar().addMenu("&Edit");
    act_delete = action(edit, "&Delete note", "Ctrl+D", T_DELETE);
    let view = window.menuBar().addMenu("&View");
    act_preview = action(view, "Markdown &preview", "Ctrl+P", T_PREVIEW);
    act_preview.setCheckable(true);
    act_preview.setChecked(true);

    let tools = window.addToolBar("Notes");
    tools.addAction(act_new);
    tools.addAction(act_save);
    tools.addAction(act_delete);
    tools.addAction(act_preview);

    let split = qt::QSplitter();
    let left = qt::QWidget();
    let col = qt::QVBoxLayout(left);
    col.setContentsMargins(0, 0, 0, 0);
    search = qt::QLineEdit();
    search.setPlaceholderText("search notes");
    search.setClearButtonEnabled(true);
    list = qt::QListWidget();
    col.addWidget(search);
    col.addWidget(list);
    editor = qt::QPlainTextEdit();
    editor.setPlaceholderText("Write Markdown here");
    preview = qt::QTextBrowser();
    preview.setOpenExternalLinks(true);
    split.addWidget(left);
    split.addWidget(editor);
    split.addWidget(preview);
    split.setStretchFactor(0, 1);
    split.setStretchFactor(1, 2);
    split.setStretchFactor(2, 2);
    window.setCentralWidget(split);
    status = window.statusBar();
    window.resize(1000, 640);

    list_model = list.model_obj();      // model() of an item view: a QObject, so the _obj variant
    qt::connect(list, "currentRowChanged", T_SELECT);
    qt::connect(editor, "textChanged", T_EDITED, qt::CONN_COALESCE);
    qt::connect(search, "textChanged", T_SEARCH, qt::CONN_COALESCE);
}

// handles what is waiting; false once the app should end
fn pump(timeout_ms: i64) -> bool {
    if qt::wait(timeout_ms) == qt::WAIT_QUIT { return false; }
    var ev = default<qt::Event>();
    var going = true;
    while qt::poll(ev) {
        if ev.tag == T_NEW {
            search.clear();
            let i = add_note("# New note\n\n");
            list.setCurrentRow(i);      // selects it through T_SELECT
            editor.setFocus();
            dirty = true;
        }
        else if ev.tag == T_SELECT { select(ev.i0); }
        else if ev.tag == T_EDITED { edited(); }
        else if ev.tag == T_SEARCH { filter(search.text()); }
        else if ev.tag == T_DELETE { delete_current(); }
        else if ev.tag == T_SAVE { save(); }
        else if ev.tag == T_RELOAD { load(); }
        else if ev.tag == T_PREVIEW {
            preview.setVisible(act_preview.isChecked());
            if act_preview.isChecked() && current >= 0 { preview.setMarkdown(editor.toPlainText()); }
        }
        else if ev.tag == T_QUIT { going = false; }
    }
    return going;
}

fn ms(t0: i64) -> f64 { return (clock_ns() - t0) / 1e6; }

fn settle() { for _ in 3 { pump(0); } }   // let the posted signals of what was just done arrive

fn main() {
    var selftest = false;
    var prev = str("");
    for a in args() {
        if a == "--selftest" { selftest = true; }
        if prev == "--file" { path = str(a); }
        prev = str(a);
    }
    let started = if selftest { qt::init(qt::APP_WIDGETS, "notes\0-platform\0offscreen") } else { qt::init() };
    if !started { print("notes: ", qt::last_error_message()); exit(1); }
    let values0 = qt::live_values();
    notes = qt::new_list();
    build();

    if !selftest {
        if !load() {
            add_note(str("# Welcome\n\nNotes are **Markdown**; the preview follows as you type.\n\n",
                         "- Ctrl+N a new note, Ctrl+D delete it\n- Ctrl+S save, Ctrl+R reload\n- Ctrl+P the preview\n"));
            list.setCurrentRow(0);
            select(0);
        }
        window.show();
        while pump(-1) {}
        if dirty { save(); }            // closing the window saves, as quitting does
        notes.free();
        qt::shutdown();
        return;
    }

    // the self-test, through the app's own actions and signals
    path = str(qt::QDir_tempPath(), "/goose-notes-selftest-", clock_ns(), ".json");
    window.show();
    var t = clock_ns();
    for i in 2000 {
        add_note(str("# Note ", i, "\n\nTagged #t", i % 37, ". Some *emphasis*, a [link](https://example.org) and\n\n",
                     "| a | b |\n|---|---|\n| ", i, " | ", i * i, " |\n"));
    }
    let t_make = ms(t);
    list.setCurrentRow(1999);
    settle();
    var ok = current == 1999 && editor.toPlainText() == field(1999, "body");

    // a new note through its action, then typing into it
    let n0 = qt::list_len(notes);
    act_new.trigger();                  // as Ctrl+N, the menu or the toolbar button would
    settle();
    ok = ok && qt::list_len(notes) == n0 + 1 && current == n0;
    editor.setPlainText("# Shopping\n\n- eggs\n- *goose* feed\n");
    settle();
    let typed_ok = row_text(current) == "Shopping" && field(current, "body") == "# Shopping\n\n- eggs\n- *goose* feed\n"
                   && contains(preview.toPlainText(), "goose feed") && !contains(preview.toPlainText(), "*");
    ok = ok && typed_ok;

    // searching every note
    t = clock_ns();
    search.setText("#t7.");
    settle();
    let t_search = ms(t);
    var shown = 0;
    for i in qt::list_len(notes) { if !list.isRowHidden(i) { shown++; } }
    var want = 0;
    for i in 2000 { if i % 37 == 7 { want++; } }
    ok = ok && shown == want;
    search.clear();
    settle();

    // save, load back, compare
    let before = qt::json(notes);
    t = clock_ns();
    act_save.trigger();
    settle();
    let t_save = ms(t);
    var size: u8[>..] = [];
    read_file(path, size);
    notes.free();
    notes = qt::new_list();
    list.clear();
    t = clock_ns();
    act_reload.trigger();
    settle();
    let t_load = ms(t);
    let after = qt::json(notes);
    let round_trip = before == after && list.count() == 2001 && !dirty;
    ok = ok && round_trip;

    // deleting the one typed in
    list.setCurrentRow(2000);
    settle();
    act_delete.trigger();
    settle();
    ok = ok && qt::list_len(notes) == 2000 && list.count() == 2000 && current == 1999;
    delete_file(path);

    print("notes: 2,000 notes of Markdown, through the app's own actions (Qt ", qt::qt_version(), ")");
    print("  made                ", t_make as i64, " ms");
    print("  typed into a note   list title, stored text and rendered preview ", if typed_ok { "agree" } else { "DISAGREE" });
    print("  search \"#t7.\"       ", shown, " of ", want, " expected shown, in ", t_search as i64, " ms");
    print("  saved               ", size.len / 1024, " KB of JSON in ", t_save as i64, " ms; loaded in ", t_load as i64,
          " ms; round trip ", if round_trip { "identical" } else { "DIFFERENT" });
    notes.free();
    window.close();
    let left = qt::live_values() - values0;
    print("  values left over    ", left);
    ok = ok && left == 0;
    print("notes: ", if ok { "ok" } else { "FAIL" });
    qt::shutdown();
    if !ok { exit(1); }
}
