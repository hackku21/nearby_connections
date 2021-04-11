import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_udid/flutter_udid.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nearby_connections/nearby_connections.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Nearby Connections example app'),
        ),
        body: Body(),
      ),
    );
  }
}

class Body extends StatefulWidget {
  @override
  _MyBodyState createState() => _MyBodyState();
}

class _MyBodyState extends State<Body> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      startAdvertising();
      startDiscovery();
    });
  }

  static late String userName;
  //     "00000 11111 22222 33333 44444 55555 66666 77777 88888 99999 aaaaa bbbbb ccccc ddddd eeeee"; // Random().nextInt(10000).toString();
  final Strategy strategy = Strategy.P2P_STAR;
  Map<String, ConnectionInfo> endpointMap = Map();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: <Widget>[
            Text("User Name: " + userName),
            Divider(),
            Text("Number of connected devices: ${endpointMap.length}"),
            ElevatedButton(
              child: Text("Stop All Endpoints"),
              onPressed: () async {
                await Nearby().stopAllEndpoints();
                setState(() {
                  endpointMap.clear();
                });
              },
            ),
            Divider(),
            Text(
              "Sending Data",
            ),
            ElevatedButton(
              child: Text("Send Random Bytes Payload"),
              onPressed: () async {
                endpointMap.forEach((key, value) {
                  String a =
                      "00000 11111 22222 33333 44444 55555 66666 77777 88888 99999 aaaaa bbbbb ccccc ddddd eeeee"; //Random().nextInt(100).toString();

                  showSnackbar("Sending $a to ${value.endpointName}, id: $key");
                  Nearby()
                      .sendBytesPayload(key, Uint8List.fromList(a.codeUnits));
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void showSnackbar(dynamic a) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(a.toString()),
    ));
  }

  void getUUID() async {
    await FlutterUdid.consistentUdid;
  }

  void stopAll() async {
    await Nearby().stopAllEndpoints();
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    setState(() {});
  }

  void startDiscovery() async {
    try {
      bool a = await Nearby().startDiscovery(
        "dis" + userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          print("userName = $userName");
          print("id = $id");

          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: (id, info) {
              discoverOnConnectionInit(id, info);
            },
            onConnectionResult: (id, status) {
              showSnackbar(status);
            },
            onDisconnected: (id) {
              setState(() {
                endpointMap.remove(id);
              });
              showSnackbar(
                  "Disconnected from: ${endpointMap[id]!.endpointName}, id $id");
            },
          );
        },
        onEndpointLost: (id) {
          showSnackbar(
              "Lost discovered Endpoint: ${endpointMap[id]!.endpointName}, id $id");
        },
      );
      showSnackbar("DISCOVERING: " + a.toString());
    } catch (e) {
      showSnackbar(e);
    }
    setState(() {});
  }

  void startAdvertising() async {
    try {
      bool a = await Nearby().startAdvertising(
        "adv" + userName,
        strategy,
        onConnectionInitiated: discoverOnConnectionInit,
        onConnectionResult: (id, status) {
          print("userName = $userName");
          print("id = $id");
          showSnackbar(status);
        },
        onDisconnected: (id) {
          showSnackbar(
              "Disconnected: ${endpointMap[id]!.endpointName}, id $id");
          setState(() {
            endpointMap.remove(id);
          });
        },
      );
      showSnackbar("ADVERTISING: " + a.toString());
    } catch (exception) {
      showSnackbar(exception);
    }
    setState(() {});
  }

  /// Called upon Connection request (on both devices)
  /// Both need to accept connection to start sending/receiving
  void discoverOnConnectionInit(String id, ConnectionInfo info) {
    setState(() {
      endpointMap[id] = info;
    });
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endid, payload) async {
        print(payload);
        if (payload.type == PayloadType.BYTES) {
          String str = String.fromCharCodes(payload.bytes!);
          showSnackbar(endid + ": " + str);
        }
      },
      onPayloadTransferUpdate: (endid, payloadTransferUpdate) {
        if (payloadTransferUpdate.status == PayloadStatus.IN_PROGRESS) {
          print(payloadTransferUpdate.bytesTransferred);
        } else if (payloadTransferUpdate.status == PayloadStatus.FAILURE) {
          print("failed");
          showSnackbar(endid + ": FAILED to transfer file");
        } else if (payloadTransferUpdate.status == PayloadStatus.SUCCESS) {
          showSnackbar(
              "$endid success, total bytes = ${payloadTransferUpdate.totalBytes}");
        }
      },
    );
  }

  ///
  ///
  ///
}
