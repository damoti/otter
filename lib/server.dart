library otter.server;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:otter_json/ottypes.dart';

OtJson0 type = new OtJson0();

class WebSockets {

  HttpServer _http;
  List<WebSocket> _sockets = [];
  Map state = {
      'counter': 0,
  };
  int version = 0;
  Map<int,List> inflight = {};

  Future start() {
    Future<HttpServer> future = HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, 1984);
    future.then((HttpServer http) {
      http
        .transform(new WebSocketTransformer())
        .listen(add);
      _http = http;
    });
    return future;
  }

  void add(WebSocket ws) {
    print("client connected");
    ws.listen((data)=>onMessage(ws,data));
    ws.add(JSON.encode({'a': 'i', 'initial': state}));
    _sockets.add(ws);
    ws.done.then((_) => _sockets.remove(ws));
  }

  void submit(WebSocket ws, List op) {
      type.checkValidOp(op);
      state = type.apply(state, op);
      inflight[version] = op;
      ws.add(JSON.encode({'a':'op', 'v':version, 'op':op}));
      version++;
  }
  void onMessage(WebSocket ws, String data) {
    Map msg = JSON.decode(data);
    switch (msg['a']) {

        case 'op':
            print(msg);

            List op = msg['op'];
            type.checkValidOp(op);

            int v = msg['v'];

            while (v < version) {
                if (!inflight.containsKey(v)) {
                    print("Could not find server op ${v}");
                    break;
                }
                List other = inflight[v];
                op = type.transform(op, other, 'right');

                v++;
            }

            state = type.apply(state, op);
            ws.add(JSON.encode({'a': 'ack', 'v': version}));
            version++;

        case 'ack':
            inflight.remove(msg['v']);

    }
  }

  void broadcast(Map message) {
    final m = JSON.encode(message);
    _sockets.forEach((s) => s.add(m));
  }

  Future stop() {
    return _http.close(force: true);
  }
}

main() {
  var serv = new WebSockets();
  serv.start();
}