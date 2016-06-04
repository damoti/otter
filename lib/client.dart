library otter.client;

import 'dart:html';
import 'dart:convert';
import 'package:otter_json/ottypes.dart';

OtJson0 type = new OtJson0();
Map state;
int version = 0;
List inflight = [];
List pending = [];

onMessage(WebSocket ws, String msg) {
    Map data = JSON.decode(msg);
    switch (data['a']) {

        case 'i':
            state = data['initial'];
            break;

        case 'ack':
            version++;
            inflight = [];
            flush(ws);
            break;

        case 'op':
            if (data['v'] > version) {
                print("Future operation !?");
                return;
            }
            List op = data['op'];

            if (inflight.isNotEmpty) {
                var result = type.transformX(inflight, op);
                inflight = result[0];
                op = result[1];
            }

            if (pending.isNotEmpty) {
                var result = type.transformX(pending, op);
                pending = result[0];
                op = result[1];
            }

            version++;

            state = type.apply(state, op);
            ws.add(JSON.encode({'a': 'ack', 'v': data['v']}));
    }
}

flush(WebSocket ws) {
    if (inflight.isNotEmpty || pending.isEmpty) {
        return;
    }
    inflight = pending;
    pending = [];
    ws.add(JSON.encode({'a': 'op', 'op': inflight, 'v':version}));
}

main() {
    new WebSocket("ws://localhost:1984").onOpen.first.then((event) {
        ws.listen((msg)=>onMessage(ws,msg));
    });
}