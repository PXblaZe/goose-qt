// qml: a Qt Quick window talking to Goose through a QtcBridge.
//
//   goose qml.goose                      click the square; close the window to quit
//   goose qml.goose -- --selftest        drives it itself and checks both directions
//
// QML calls bridge.send(name, payload): Goose gets a "sent" signal event with
// a structured payload (any JSON-like value). Goose calls bridge.post(name,
// payload): QML gets the bridge's message(name, payload) signal. QML properties
// and functions are reached like C++ ones: qt::get_int, qt::set, qt::call.
import os;
import qt from "..";
import qt.qml;

let QML = """
    import QtQuick
    Window {
        id: win
        width: 320; height: 220; visible: true
        title: "QML from Goose"
        property int clicks: 0
        property string status: "waiting"
        function press() { clicks++; bridge.send("clicked", { clicks: clicks }) }
        Rectangle {
            anchors.centerIn: parent; width: 120; height: 120; radius: 12
            color: win.clicks % 2 ? "#ffcc33" : "#3388ff"
            Text { anchors.centerIn: parent; text: win.clicks; font.pixelSize: 40 }
            MouseArea { anchors.fill: parent; onClicked: win.press() }
        }
        Text { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; text: win.status }
        Connections {
            target: bridge
            function onMessage(name, payload) { win.status = name + ": " + payload.text }
        }
    }
    """;

let T_SENT: u64 = 1;
let T_SELFTEST_DONE: u64 = 2;

fn main() {
    let argv = args();
    let selftest = argv.len > 1 && argv[1] == "--selftest";
    if !qt::init(qt::APP_GUI) {
        print("qt::init: ", qt::last_error_message());
        exit(1);
    }

    let engine = qt::QQmlApplicationEngine();
    let bridge = qt::new_object("QtcBridge");
    engine.rootContext().setContextProperty("bridge", bridge);
    qt::connect(bridge, "sent", T_SENT);
    engine.loadData(QML);
    let roots = engine.rootObjects();
    var window = qt::NONE;
    if roots.list_len() > 0 {
        let first = roots.list_get(0);
        window = first.to_obj();
        first.free();
    }
    roots.free();
    if !qt::alive(window) {
        print("the QML did not load");
        qt::shutdown();
        exit(1);
    }

    if selftest {
        qt::call(window, "press");   // what a click on the square does
        qt::call(window, "press");
        qt::post(T_SELFTEST_DONE, 0, 0);
    }

    var last_clicks = 0;
    var ev = default<qt::Event>();
    while qt::wait(-1) == qt::WAIT_EVENTS {
        while qt::poll(ev) {
            if ev.tag == T_SENT {
                // sent(QString name, QVariant payload)
                let name = ev.arg_str(0);
                let payload = ev.arg_val(1);
                print("QML sent ", name, " ", payload.json());
                let clicks = payload.map_get("clicks");
                last_clicks = clicks.to_int();
                clicks.free();
                payload.free();
                // answer: bridge.post(name, payload) reaches QML's onMessage
                let answer = qt::new_map();
                let text = qt::val(str("Goose saw ", last_clicks));
                answer.map_set("text", text);
                text.free();
                qt::arg("reply");
                qt::arg(answer);
                qt::call(bridge, "post");
                answer.free();
            } else if ev.tag == T_SELFTEST_DONE {
                qt::quit();
            }
        }
    }

    var ok = true;
    if selftest {
        let status = qt::get_str(window, "status");
        let clicks = qt::get_int(window, "clicks");
        ok = clicks == 2 && last_clicks == 2 && status == "reply: Goose saw 2";
        print("qml: clicks ", clicks, ", Goose saw ", last_clicks, ", status \"", status, "\": ", if ok { "ok" } else { "FAIL" });
    }
    qt::shutdown();
    if !ok { exit(1); }
}
