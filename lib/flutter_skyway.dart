import 'dart:async';

import 'package:flutter/services.dart';

final MethodChannel _channel = const MethodChannel('flutter_skyway');

class Skyway {
  static Future<SkywayPeer> connect(String apiKey, String domain) async {
    final String peerId = await _channel.invokeMethod('connectAction', {
      'apiKey': apiKey,
      'domain': domain,
    });
    print('peerId: $peerId');
    return SkywayPeer(peerId: peerId)..initialize();
  }
}

typedef ReceiveRoomOpenCallback = void Function(String roomName);
typedef ReceiveRoomCloseCallback = void Function(String roomName);
typedef ReceiveRoomErrorCallback = void Function(String error);
typedef ReceiveRoomJoinCallback = void Function(String peerId);
typedef ReceiveRoomLeaveCallback = void Function(String peerId);
typedef ReceiveRoomStreamCallback = void Function(String peerId);
typedef ReceiveRoomRemoveStreamCallback = void Function(String peerId);

class SkywayPeer {
  final String peerId;

  SkywayPeer({this.peerId});

  /// if you join room. return roomName.
  ReceiveRoomOpenCallback onReceiveRoomOpenCallback;

  /// if your room is closed. return roomName.
  ReceiveRoomCloseCallback onReceiveRoomCloseCallback;

  /// if error occur. return error.
  ReceiveRoomErrorCallback onReceiveRoomErrorCallback;

  /// if other peer join your room. return peerId.
  ReceiveRoomJoinCallback onReceiveRoomJoinCallback;

  /// if other peer leave your room. return peerId.
  ReceiveRoomLeaveCallback onReceiveRoomLeaveCallback;

  /// if receive other user stream. return peerId.
  ReceiveRoomStreamCallback onReceiveRoomStreamCallback;

  /// if remove stream. return peerId.
  ReceiveRoomRemoveStreamCallback onReceiveRoomRemoveStreamCallback;

  StreamSubscription<dynamic> _eventSubscription;

  void initialize() {
    _eventSubscription = EventChannel('flutter_skyway/$peerId')
        .receiveBroadcastStream()
        .listen(_eventListener, onError: _errorListener);
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
  }

  void _eventListener(dynamic event) {
    final Map<dynamic, dynamic> map = event;
    switch (map['event']) {
      case 'open':
        if (onReceiveRoomOpenCallback != null) {
          onReceiveRoomOpenCallback(map['roomName']);
        }
        break;
      case 'close':
        if (onReceiveRoomCloseCallback != null) {
          onReceiveRoomCloseCallback(map['roomName']);
        }
        break;
      case 'error':
        if (onReceiveRoomErrorCallback != null) {
          onReceiveRoomErrorCallback(map['error']);
        }
        break;
      case 'join':
        if (onReceiveRoomJoinCallback != null) {
          onReceiveRoomJoinCallback(map['peerId']);
        }
        break;
      case 'leave':
        if (onReceiveRoomLeaveCallback != null) {
          onReceiveRoomLeaveCallback(map['peerId']);
        }
        break;
      case 'stream':
        if (onReceiveRoomStreamCallback != null) {
          onReceiveRoomStreamCallback(map['peerId']);
        }
        break;
      case 'remove_stream':
        if (onReceiveRoomRemoveStreamCallback != null) {
          onReceiveRoomRemoveStreamCallback(map['peerId']);
        }
        break;
    }
  }

  void _errorListener(Object obj) {
    print('onError: $obj');
  }

  /// Join room with your roomName. If success true is returned.
  Future<bool> joinRoomAction(String roomName) async {
    return await _channel.invokeMethod('joinRoomAction', {
      'roomName': roomName,
    });
  }

  /// Leave room. If success true is returned.
  Future<bool> leaveRoomAction(String roomName) async {
    return await _channel.invokeMethod('leaveRoomAction');
  }

  /// Switch your Camera (front or back). If success true is returned.
  Future<bool> switchCameraAction() async {
    return await _channel.invokeMethod('switchCameraAction');
  }

  /// Switch your Audio . If true, your Audio is listened
  Future<bool> enableAudioAction(bool isEnable) async {
    return await _channel.invokeMethod('enableAudioAction', {
      'isEnable': isEnable,
    });
  }

  /// Switch your Video . If true, your Video is listened
  Future<bool> enableVideoAction(bool isEnable) async {
    return await _channel.invokeMethod('enableVideoAction', {
      'isEnable': isEnable,
    });
  }

  /// return peerId
  Future<String> showOtherVideoAction(String peerId, bool isEnable) async {
    return await _channel.invokeMethod('showOtherVideoAction', {
      'peerId': peerId,
      'isEnable': isEnable,
    });
  }

  /// return all peerId except you
  Future<List<String>> getAllPeerIdAction() async {
    return await _channel.invokeMethod('getAllPeerIdAction');
  }

  /// return showing peerId except you
  Future<List<String>> getShowingPeerIdsAction() async {
    return await _channel.invokeMethod('getShowingPeerIdsAction');
  }

  /// if success return true
  Future<bool> destroyPeerAction() async {
    return await _channel.invokeMethod('destroyPeerAction');
  }

  /// if success return true
  Future<bool> afterPlatformViewWaitingAction(
      String peerId, bool isMine) async {
    return await _channel.invokeMethod(
        'afterPlatformViewWaitingAction', {'peerId': peerId, 'isMine': isMine});
  }

  /// if success return true
  Future<bool> changeSpeakerAction(bool isSpeaker) async {
    return await _channel.invokeMethod('changeSpeakerAction', {
      'isSpeaker': isSpeaker,
    });
  }
}
