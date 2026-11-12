# Networking

Qt Network is bound like the rest: TCP and UDP sockets, servers, local sockets, HTTP through
`QNetworkAccessManager`, TLS, DNS lookups. Sockets are objects whose signals arrive in your
event loop, so a program can serve many connections on the GUI thread without threads. The
[loopback sample](../samples/loopback/loopback.goose) runs an echo server and 16 clients
this way at over 600,000 round trips a second.

A program imports the module with `import qt.network;` after `import qt from "...";`, and
one that needs no windows starts with `qt::init(qt::APP_CORE)`.

## A TCP server

```goose
let server = qt::QTcpServer();
let any_local = qt::QHostAddress("127.0.0.1");
server.listen(any_local, 0);                      // port 0: any free port
any_local.free();
qt::connect(server, "newConnection", T_ACCEPT);
print("listening on ", server.serverPort());

// in the loop:
if ev.tag == T_ACCEPT {
    while true {
        let s = server.nextPendingConnection();   // owned by the server
        if s.h == 0 { break; }
        qt::connect(s, "readyRead", T_READ, qt::CONN_COALESCE);
        qt::connect(s, "disconnected", T_GONE);
    }
}
if ev.tag == T_READ {
    let s = qt::sender(ev);
    let data = s.readAll();                       // u8[>..]
    s.write(data);                                // echo it
}
if ev.tag == T_GONE { qt::destroy(qt::sender(ev)); }
```

## A client

```goose
let sock = qt::QTcpSocket();
qt::connect(sock, "connected", T_CONNECTED);
qt::connect(sock, "readyRead", T_READ, qt::CONN_COALESCE);
qt::connect(sock, "errorOccurred", T_ERROR);       // ev.i0: the QAbstractSocket::SocketError
sock.connectToHost("example.org", 80);
```

Writes are buffered by Qt and go out as the loop runs. To stream a lot of data without
buffering all of it, top the buffer up as it drains: connect `bytesWritten` (coalesced) and
write more while `sock.bytesToWrite()` is below a few megabytes, as the loopback sample's
64 MB stream does.

For small request–response messages, turn off Nagle's algorithm, which otherwise holds small
writes back for up to 40 ms:

```goose
let on = qt::val(1);
sock.setSocketOption(0, on);                       // QAbstractSocket::LowDelayOption
on.free();
```

## Things to know

- **Coalesce `readyRead`.** Several `readyRead` emissions before your loop gets to the first
  are one event with `qt::CONN_COALESCE`, and one `readAll()` takes everything. Without it,
  later events find nothing to read, which is harmless but wasted.
- **Messages are not packets.** TCP delivers a byte stream; one `readAll()` may hold part of a
  message or several. Keep a buffer per connection and take whole messages out of it.
- **Sockets accepted by a server are its children.** Destroying the server destroys them;
  destroy one early with `qt::destroy`, which is safe even with its events still queued.
- **Blocking calls block.** `waitForConnected`, `waitForReadyRead` and the like stop the
  whole GUI thread until they return; use signals instead, or a timeout short enough not to
  be noticed.
- **File descriptors.** Calls that take a socket descriptor (`setSocketDescriptor`) are
  refused for a descriptor that is not open, but qtc cannot tell whether an open one is
  yours to give; see [qtc's limits](../../qtc/docs/LIMITS.md).
- **The GPL-3.0-only add-ons** (MQTT, CoAP, HTTP Server, Network Authorization) are only in a
  libqtc built with `QTC_GPL_MODULES=ON`; see [Build and install](build-and-install.md#licensing).

## HTTP

```goose
let nam = qt::QNetworkAccessManager();
let url = qt::QUrl("https://example.org/");
let req = qt::QNetworkRequest(url);
let reply = nam.get(req);                          // a QNetworkReply object
url.free(); req.free();
qt::connect(reply, "finished", T_REPLY);
// in the loop:
if ev.tag == T_REPLY {
    let r = qt::sender(ev);
    let body = r.readAll();
    let status = r.attribute(0);                   // QNetworkRequest::HttpStatusCodeAttribute
    print(status.to_int(), ": ", body.len, " bytes");
    status.free();
    qt::destroy(r);
}
```
