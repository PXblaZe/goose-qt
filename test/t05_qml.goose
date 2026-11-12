// QML: components, properties, functions and signals of QML objects, the QtcBridge
// between Goose and QML, Qt Quick rendering, and errors.
import qt from "..";
import qt.qml;
import qt.quick;

var failures = 0;
var checks = 0;
fn check(ok: bool, what: const u8[:]) {
    checks++;
    if !ok {
        failures++;
        print("FAIL ", what, "  [", qt::last_error_message(), "]");
    }
}

let OBJECT_QML = """
    import QtQml
    QtObject {
        property int count: 1
        property string label: "start"
        property var items: []
        signal pinged(int n, string what)
        function twice(x) { return x * 2 }
        function ping() {
            pinged(count, label)
            bridge.send("hello", { a: count, b: [1, 2, 3] })
        }
        property Connections conn: Connections {
            target: bridge
            function onMessage(name, payload) { label = name + ":" + payload }
        }
    }
    """;

let VIEW_QML = """
    import QtQuick
    Rectangle {
        width: 120; height: 80
        color: "#ff0000"
        Rectangle { x: 0; y: 0; width: 20; height: 20; color: "#0000ff" }
        Text { anchors.centerIn: parent; text: "goose" }
    }
    """;

fn write_file(path: const u8[:], text: const u8[:]) -> bool {
    let f = qt::QFile(path);
    if !f.open(qt::QIODeviceBase.WriteOnly) { return false; }
    f.write(text);
    f.close();
    qt::destroy(f);
    return true;
}

fn main() {
    check(qt::init(qt::APP_WIDGETS, "t05\0-platform\0offscreen"), "init");
    qt::set_error_policy(qt::ERRORS_RETURN);
    qt::set_quit_on_last_window_closed(false);

    let engine = qt::QQmlEngine();
    let bridge = qt::new_object("QtcBridge");
    engine.rootContext().setContextProperty("bridge", bridge);

    // ------------------------------------------------ a component from text
    let comp = qt::QQmlComponent(engine);
    let url = qt::QUrl("qrc:/t05/object.qml");
    comp.setData(OBJECT_QML, url);
    check(!comp.isError(), "component compiles");
    let obj = comp.create_obj();
    check(qt::alive(obj), "object created");
    check(qt::get_int(obj, "count") == 1, "QML property read");
    check(qt::set(obj, "count", 5) && qt::get_int(obj, "count") == 5, "QML property write");
    check(qt::get_str(obj, "label") == "start", "QML string property");
    qt::arg(21);
    check(qt::call(obj, "twice") && qt::ret_int() == 42, "QML function call");
    let items = qt::from_json("[1, \"two\", {\"three\": 3}]");
    check(qt::set(obj, "items", items), "a list into a var property");
    let back = qt::get_val(obj, "items");
    check(qt::json(back) == "[1,\"two\",{\"three\":3}]", "and back out");
    items.free();
    back.free();

    // QML signals and the bridge
    qt::connect(obj, "pinged", 1);
    qt::connect(bridge, "sent", 2);
    check(qt::call(obj, "ping"), "call a function that emits");
    qt::wait(0);
    var ev = default<qt::Event>();
    var got1 = false;
    var got2 = false;
    while qt::poll(ev) {
        if ev.tag == 1 {
            got1 = ev.argc == 2 && qt::arg_int(ev, 0) == 5 && qt::arg_str(ev, 1) == "start";
        } else if ev.tag == 2 {
            let payload = qt::arg_val(ev, 1);
            got2 = qt::arg_str(ev, 0) == "hello" && qt::json(payload) == "{\"a\":5,\"b\":[1,2,3]}";
            payload.free();
        }
    }
    check(got1, "QML signal with arguments");
    check(got2, "bridge.send reaches Goose with a structured payload");
    qt::arg("note");
    qt::arg(7);
    check(qt::call(bridge, "post"), "bridge post");
    check(qt::get_str(obj, "label") == "note:7", "bridge.post reaches QML");

    // errors
    let bad = qt::QQmlComponent(engine);
    bad.setData("import QtQml\nQtObject {", qt::QUrl("qrc:/t05/bad.qml"));
    check(bad.isError() && bad.errorString().len > 0, "a syntax error is reported");
    check(qt::is_null(bad.create_obj()), "create on an error component gives null");
    qt::arg(1);
    check(!qt::call(obj, "noSuchFunction") && qt::last_error() == qt::ERR_NOT_FOUND, "unknown QML function");
    check(!qt::set(obj, "noSuchProperty", 1) && qt::last_error() == qt::ERR_NOT_FOUND, "unknown QML property");

    // a component loading asynchronously can be destroyed at any time
    let path = "t05_view.qml";
    check(write_file(path, VIEW_QML), "write a QML file");
    let file_url = qt::QUrl_fromLocalFile(path);
    let pending = qt::QQmlComponent(engine);
    pending.loadUrl(file_url, qt::QQmlComponent.Asynchronous);
    check(qt::destroy(pending), "destroy while loading");
    qt::test_wait(50);
    check(!qt::alive(pending), "gone");

    // ------------------------------------------------ Qt Quick, rendered
    let view = qt::QQuickView();
    view.setResizeMode(qt::QQuickView.SizeRootObjectToView);
    view.setSource(file_url);
    check(view.status() == qt::QQuickView.Ready, "view loaded");
    let root = view.rootObject();
    check(qt::alive(root) && qt::get_f64(root, "width") == 120.0, "root item");
    view.show();
    qt::test_wait(100);
    let shot = view.grabWindow();
    check(shot.width_int() > 0, "grab the window");
    let c1 = shot.pixelColor(100, 70);
    let c2 = shot.pixelColor(5, 5);
    check(c1.name() == "#ff0000", "rectangle rendered red");
    check(c2.name() == "#0000ff", "inner rectangle rendered blue");
    for v in [c1, c2, shot, url, file_url] { v.free(); }
    qt::set(root, "color", "#00ff00");
    qt::test_wait(50);
    let shot2 = view.grabWindow();
    let c3 = shot2.pixelColor(100, 70);
    check(c3.name() == "#00ff00", "property change re-rendered");
    c3.free();
    shot2.free();
    qt::destroy(view);
    qt::destroy(obj);
    qt::destroy(engine);
    qt::process_events();
    check(!qt::alive(comp), "components go with their engine");
    check(qt::shutdown(), "shutdown");
    print("t05_qml: ", checks - failures, " passed, ", failures, " failed");
    if failures > 0 { exit(1); }
}
