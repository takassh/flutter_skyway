import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_skyway/flutter_skyway.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  State<StatefulWidget> createState() => new _HomeState();
}

class _HomeState extends State<HomePage> {
  final viewId = <int>[];
  final String apiKey = 'apiKey';
  final String domain = 'domain';
  String status = '';
  bool isConnecting = false;
  SkywayPeer peer;
  List<String> otherPeers = [];
  List<String> showingPeers = [];
  Map<String, bool> areVisible = {};
  bool isSpeaker = false;

  bool get isConnected {
    return peer != null;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('SkyWay Plugin Example App'),
        ),
        body: Center(
          child: ListView(
            padding: EdgeInsets.all(12.0),
            children: <Widget>[
                  Padding(padding: EdgeInsets.all(8.0)),
                  Text(
                    '$status',
                    style: TextStyle(fontSize: 16.0),
                    textAlign: TextAlign.center,
                  ),
                  isConnected
                      ? Text(
                          'Your peer ID: ${peer.peerId}',
                          style: TextStyle(fontSize: 16.0),
                          textAlign: TextAlign.center,
                        )
                      : null,
                  Padding(padding: EdgeInsets.all(8.0)),
                  isConnecting
                      ? Center(
                          child: SizedBox(
                            child: CircularProgressIndicator(),
                            width: 30.0,
                            height: 30.0,
                          ),
                        )
                      : !isConnected
                          ? FlatButton(
                              child: Text(
                                'Connect',
                                style: TextStyle(
                                    color: Colors.blue, fontSize: 16.0),
                                textAlign: TextAlign.center,
                              ),
                              onPressed: _connect)
                          : FlatButton(
                              child: Text(
                                'Disconnect',
                                style: TextStyle(
                                    color: Colors.blue, fontSize: 16.0),
                                textAlign: TextAlign.center,
                              ),
                              onPressed: () {}), //_disconnect),
                  Padding(padding: EdgeInsets.all(8.0)),
                  isConnected
                      ? RaisedButton(
                          onPressed: _joinRoomAction,
                          child: Text('join room'),
                        )
                      : null,
                  Padding(padding: EdgeInsets.all(8.0)),
                  isConnected
                      ? RaisedButton(
                          onPressed: _switchCameraAction,
                          child: Text('switchCameraAction'),
                        )
                      : null,
                  Padding(padding: EdgeInsets.all(8.0)),
                  isConnected
                      ? RaisedButton(
                          onPressed: () {
                            isSpeaker = !isSpeaker;
                            peer.changeSpeakerAction(isSpeaker);
                          },
                          child: Text('changeSpeakerAction'),
                        )
                      : null,
                  isConnected
                      ? RaisedButton(
                          onPressed: () async {
                            print(await peer.enableAudioAction(true));
                          },
                          child: Text('enableAudioAction'),
                        )
                      : null,
                  isConnected
                      ? RaisedButton(
                          onPressed: () async {
                            print(await peer.enableVideoAction(true));
                          },
                          child: Text('enableVideoAction'),
                        )
                      : null,
                  isConnected
                      ? RaisedButton(
                          onPressed: () {
                            peer.enableAudioAction(false);
                          },
                          child: Text('muteAudioAction'),
                        )
                      : null,
                  isConnected
                      ? RaisedButton(
                          onPressed: () {
                            peer.enableVideoAction(false);
                          },
                          child: Text('muteVideoAction'),
                        )
                      : null,
                  isConnected
                      ? RaisedButton(
                          onPressed: () async {
                            await peer.showOtherVideoAction(
                                otherPeers[0], false);
                          },
                          child: Text('muteVideoAction'),
                        )
                      : null,
                  isConnected
                      ? Column(
                          children: <Widget>[
                            SizedBox(
                              child: SkyWayLocalView(
                                ownPeerId: peer.peerId,
                              ),
                              width: 320.0,
                              height: 240.0,
                            ),
                          ],
                        )
                      : null,
                ].where((c) => c != null).toList() +
                otherPeers
                    .map(
                      (e) => isConnected
                          ? Column(
                              children: <Widget>[
                                SizedBox(
                                  child: Hero(
                                    tag: 'view',
                                    child: SkyWayRemoteView(
                                      peer: peer,
                                      peerId: e,
                                    ),
                                  ),
                                  width: 320.0,
                                  height: 240.0,
                                ),
                              ],
                            )
                          : null,
                    )
                    .toList() +
                otherPeers.map((e) => Text(e)).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    if (isConnecting) {
      return;
    }

    setState(() {
      this.isConnecting = true;
      this.status = 'Connecting...';
    });

    String status;
    SkywayPeer peer;

    try {
      status = 'Connected!';
      peer = await Skyway.connect(apiKey, domain);
      peer.onReceiveRoomOpenCallback = _onReceiveRoomOpenCallback;
      peer.onReceiveRoomCloseCallback = _onReceiveRoomCloseCallback;
      peer.onReceiveRoomErrorCallback = _onReceiveRoomErrorCallback;
      peer.onReceiveRoomJoinCallback = _onReceiveRoomJoinCallback;
      peer.onReceiveRoomLeaveCallback = _onReceiveRoomLeaveCallback;
      peer.onReceiveRoomStreamCallback = _onReceiveRoomStreamCallback;
      peer.onReceiveRoomRemoveStreamCallback =
          _onReceiveRoomRemoveStreamCallback;
    } on PlatformException catch (e) {
      print(e);
      status = 'Failed to connect.';
    }

    setState(() {
      this.isConnecting = false;
      this.status = status;
      this.peer = peer;
    });
  }

  void _onReceiveRoomOpenCallback(String roomName) {
    print('join: $roomName');
  }

  void _onReceiveRoomCloseCallback(String roomName) {
    print('close: $roomName');
  }

  void _onReceiveRoomErrorCallback(String error) {
    print('error: $error');
  }

  void _onReceiveRoomJoinCallback(String peerId) {
    print('newPeerId: $peerId');
  }

  void _onReceiveRoomLeaveCallback(String peerId) {
    print('LeavePeerId: $peerId');
  }

  void _onReceiveRoomStreamCallback(String peerId) {
    print('stream: $peerId');

    setState(() {
      otherPeers.add(peerId);
    });

    showDialog(
      context: context,
      builder: (BuildContext context) => new AlertDialog(
        title: new Text('join $peerId'),
        actions: <Widget>[
          new FlatButton(
              child: const Text('OK'),
              onPressed: () async {
                //await peer.showOtherVideoAction(peerId);

                Navigator.pop(context, 1);
              })
        ],
      ),
    );
  }

  void _onReceiveRoomRemoveStreamCallback(String peerId) {
    print('remove stream: $peerId');
    showDialog(
      context: context,
      builder: (BuildContext context) => new AlertDialog(
        title: new Text('leave $peerId'),
        actions: <Widget>[
          new FlatButton(
              child: const Text('OK'),
              onPressed: () async {
                //await peer.hideOtherVideoAction(peerId); もう消えている
                setState(() {
                  otherPeers.remove(peerId);
                });

                Navigator.pop(context, 1);
              })
        ],
      ),
    );
  }

  Future<void> _joinRoomAction() async {
    //join room
    if (!isConnected) {
      return;
    }

    try {
      peer.joinRoomAction("example");
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future<void> _switchCameraAction() async {
    if (!isConnected) {
      return;
    }

    try {
      peer.switchCameraAction();
    } on PlatformException catch (e) {
      print(e);
    }
  }
}
