package com.kasai.flutter_skyway;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Bundle;
import android.os.PersistableBundle;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;

import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;
import androidx.core.app.ActivityCompat;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.app.FlutterActivity;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import io.skyway.Peer.*;
import io.skyway.Peer.Browser.Canvas;
import io.skyway.Peer.Browser.MediaConstraints;
import io.skyway.Peer.Browser.MediaStream;
import io.skyway.Peer.Browser.Navigator;

public class FlutterSkywayPlugin extends FlutterActivity implements FlutterPlugin, MethodChannel.MethodCallHandler {

  public static boolean isPERMISSION_GRANTED = false;
  public static final String CHANNEL = "flutter_skyway";

  static PluginRegistry.Registrar registrar;

  private Peer _peer;// 自身
  private MediaStream _localStream;// 自身
  Canvas _localStreamView;// local streamのcanvas
  private SFURoom _room;// 入っているroom
  private Map<String, Boolean> areMuteAudio = new HashMap<>();
  private Map<String, Boolean> areMuteVideo = new HashMap<>();

  private Map<String, MediaStream> allStreamsInRoom = new HashMap<>();// 全てのstream
  private Map<String, SkyWayRemoteVideoChild> videoChildren = new HashMap<>();// これまで全てのvideoが格納(roomを離れたとしても)
  private Map<String, FlutterPlatformViewFactory> factories = new HashMap<>();// これまで使ったfactoryが格納(再びviewを設定したいときに使う)

  EventChannel.EventSink eventSink;
  EventChannel eventChannel;

  // method channelを登録
  public static void registerWith(PluginRegistry.Registrar _registrar) {

    final MethodChannel channel = new MethodChannel(_registrar.messenger(), CHANNEL);
    registrar = _registrar;
    channel.setMethodCallHandler(new FlutterSkywayPlugin());
  }

  private EventChannel createEventChannel(String peerId) {
    EventChannel eventChannel = new EventChannel(registrar.messenger(), CHANNEL + "/" + peerId);
    return eventChannel;
  }

//  @Override
//  public void onCreate(Bundle savedInstanceState) {
//    super.onCreate(savedInstanceState);
//    registerWith(this.registrarFor("main"));
//  }

  @Override
  public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
    // flutterPluginBinding.getPlatformViewRegistry().registerViewFactory("flutter_skyway/video_view",new
    // SfuPlatformViewFactory(views));
    // いらないぽい
  }

  @Override
  public void onDetachedFromEngine(FlutterPluginBinding flutterPluginBinding) {
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {

    // Note: this method is invoked on the main thread.
    if (call.method.equals("connectAction")) {
      connectAction(call, result);
    } else if (call.method.equals("joinRoomAction")) {
      if (isPERMISSION_GRANTED) {
        joinRoomAction(call, result);
      } else {
        result.error("permission error", "permission error", "");
      }
    } else if (call.method.equals("leaveRoomAction")) {
      if (isPERMISSION_GRANTED) {
        leaveRoomAction(result);
      } else {
        result.error("permission error", "permission error", "");
      }
    } else if (call.method.equals("switchCameraAction")) {
      if (isPERMISSION_GRANTED) {
        switchCameraAction(result);
      } else {
        result.error("permission error", "permission error", "");
      }
    } else if (call.method.equals("enableAudioAction")) {
      if (isPERMISSION_GRANTED) {
        enableAudioAction(call, result);
      } else {
        result.error("permission error", "permission error", "");
      }
    } else if (call.method.equals("enableVideoAction")) {
      if (isPERMISSION_GRANTED) {
        enableVideoAction(call, result);
      } else {
        result.error("permission error", "permission error", "");
      }
    } else if (call.method.equals("showOtherVideoAction")) {
      if (isPERMISSION_GRANTED) {
        showOtherVideoAction(call, result);
      } else {
        result.error("permission error", "permission error", "");
      }
    } else if (call.method.equals("getAllPeerIdAction")) {
      if (isPERMISSION_GRANTED) {
        getAllPeerIdAction(result);
      } else {
        result.error("permission error", "permission error", "");
      }
    } else if (call.method.equals("getShowingPeerIdsAction")) {
      if (isPERMISSION_GRANTED) {
        getShowingPeerIdsAction(result);
      } else {
        result.error("permission error", "permission error", "");
      }
    } else if (call.method.equals("destroyPeerAction")) {
      if (isPERMISSION_GRANTED) {
        destroyPeerAction(result);
      } else {
        result.error("permission error", "permission error", "");
      }
    } else if (call.method.equals("changeSpeakerAction")) {
      if (isPERMISSION_GRANTED) {
        changeSpeakerAction(call, result);
      } else {
        result.error("permission error", "permission error", "");
      }
    } else if (call.method.equals("afterPlatformViewWaitingAction")) {
      if (isPERMISSION_GRANTED) {
        afterPlatformViewWaitingAction(call, result);
      } else {
        result.error("permission error", "permission error", "");
      }
    }
  }

  private void connectAction(MethodCall call, final MethodChannel.Result result) {
    Map<String, String> args = (Map<String, String>) call.arguments;// 引数取得

    final Activity activity = registrar.activity();

    PeerOption option = new PeerOption();
    option.key = args.get("apiKey");
    option.domain = args.get("domain");
    _peer = new Peer(registrar.context(), option);

    // OPEN
    _peer.on(Peer.PeerEventEnum.OPEN, new OnCallback() {
      @Override
      public void onCallback(Object object) {

        // Show my ID
        String _strOwnId = (String) object;

        // Request permissions
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED
            && ContextCompat.checkSelfPermission(activity,
                Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
          ActivityCompat.requestPermissions(activity,
              new String[] { Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO }, 0);
        } else {
          // Get a local MediaStream & show it
          isPERMISSION_GRANTED = true;
           startLocalStream();
        }

        eventChannel = createEventChannel(_strOwnId);// 自分のid
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
          @Override
          public void onListen(Object arguments, EventChannel.EventSink events) {
            eventSink = events;
          }

          @Override
          public void onCancel(Object arguments) {

          }
        });

        registrar.platformViewRegistry().registerViewFactory("flutter_skyway/video_view/" + _peer.identity(),
            new FlutterPlatformViewFactory(_localStreamView));

        result.success(_strOwnId);
      }
    });

    _peer.on(Peer.PeerEventEnum.CLOSE, new OnCallback() {
      @Override
      public void onCallback(Object object) {
        Log.d(CHANNEL, "[On/Close]");
      }
    });
    _peer.on(Peer.PeerEventEnum.DISCONNECTED, new OnCallback() {
      @Override
      public void onCallback(Object object) {
        Log.d(CHANNEL, "[On/Disconnected]");
      }
    });
    _peer.on(Peer.PeerEventEnum.ERROR, new OnCallback() {
      @Override
      public void onCallback(Object object) {
        PeerError error = (PeerError) object;
        Log.d(CHANNEL, "[On/Error]" + error.message);
      }
    });
  }

  void joinRoomAction(MethodCall call, final MethodChannel.Result result) {
    Map<String, String> args = (Map<String, String>) call.arguments;// 引数取得
    String roomName = args.get("roomName");
    if ((null == _peer) || (null == _peer.identity()) || (0 == _peer.identity().length())) {
      result.error("peer id error", "Your PeerID is null or invalid", "");
      return;
    }

    // Get room name
    if (TextUtils.isEmpty(roomName)) {
      result.error("room name error", "You should input room name", "");
      return;
    }

    //startLocalStream();

    RoomOption option = new RoomOption();
    option.mode = RoomOption.RoomModeEnum.SFU;
    option.stream = _localStream;
    _room = (SFURoom) _peer.joinRoom(roomName, option);
    result.success(true);

    _room.on(Room.RoomEventEnum.OPEN, new OnCallback() {
      @Override
      public void onCallback(Object object) {
        if (!(object instanceof String))
          return;

        String roomName = (String) object;
        Log.i(CHANNEL, "Enter Room: " + roomName);

        eventSink.success(makeSink("open", "roomName", roomName));
      }
    });

    _room.on(Room.RoomEventEnum.CLOSE, new OnCallback() {
      @Override
      public void onCallback(Object object) {
        String roomName = (String) object;
        Log.i(CHANNEL, "Leave Room: " + roomName);

        // Unset callbacks
        _room.on(Room.RoomEventEnum.OPEN, null);
        _room.on(Room.RoomEventEnum.CLOSE, null);
        _room.on(Room.RoomEventEnum.ERROR, null);
        _room.on(Room.RoomEventEnum.PEER_JOIN, null);
        _room.on(Room.RoomEventEnum.PEER_LEAVE, null);
        _room.on(Room.RoomEventEnum.STREAM, null);
        _room.on(Room.RoomEventEnum.REMOVE_STREAM, null);

        _room = null;
        videoChildren = new HashMap<>();// もしかするとそれぞれcloseしないとかも
        allStreamsInRoom = new HashMap<>();

        eventSink.success(makeSink("close", "roomName", roomName));
      }
    });

    _room.on(Room.RoomEventEnum.ERROR, new OnCallback() {
      @Override
      public void onCallback(Object object) {
        PeerError error = (PeerError) object;
        Log.d(CHANNEL, "RoomEventEnum.ERROR:" + error);

        eventSink.success(makeSink("error", "error", error.message));
      }
    });

    _room.on(Room.RoomEventEnum.PEER_JOIN, new OnCallback() {
      @Override
      public void onCallback(Object object) {
        Log.d(CHANNEL, "RoomEventEnum.PEER_JOIN:");

        if (!(object instanceof String))
          return;

        String peerId = (String) object;
        Log.i(CHANNEL, "Join Room: " + peerId);

        eventSink.success(makeSink("join", "peerId", peerId));

      }
    });
    _room.on(Room.RoomEventEnum.PEER_LEAVE, new OnCallback() {
      @Override
      public void onCallback(Object object) {
        Log.d(CHANNEL, "RoomEventEnum.PEER_LEAVE:");

        if (!(object instanceof String))
          return;

        String peerId = (String) object;
        Log.i(CHANNEL, "Leave Room: " + peerId);

        eventSink.success(makeSink("leave", "peerId", peerId));
      }
    });

    _room.on(Room.RoomEventEnum.STREAM, new OnCallback() {
      @Override
      public void onCallback(Object object) {

        if (!(object instanceof MediaStream))
          return;

        final MediaStream stream = (MediaStream) object;

        SkyWayRemoteVideoChild video = new SkyWayRemoteVideoChild(stream, registrar);

        if (videoChildren.get(stream.getPeerId()) == null) {
          FlutterPlatformViewFactory instance = new FlutterPlatformViewFactory(video.remoteStreamView);

          factories.put(stream.getPeerId(), instance);

          registrar.platformViewRegistry().registerViewFactory("flutter_skyway/video_view/" + stream.getPeerId(),
              instance);
          // platform viewは作っておく

          videoChildren.put(stream.getPeerId(), video);
        } else {
          videoChildren.put(stream.getPeerId(), video);
          factories.get(stream.getPeerId()).streamView = video.remoteStreamView;
        }

        areMuteVideo.put(stream.getPeerId(), false);
        areMuteAudio.put(stream.getPeerId(), false);

        eventSink.success(makeSink("stream", "peerId", stream.getPeerId()));
      }
    });

    _room.on(Room.RoomEventEnum.REMOVE_STREAM, new OnCallback() {
      @Override
      public void onCallback(Object object) {

        if (!(object instanceof MediaStream))
          return;

        final MediaStream stream = (MediaStream) object;

        allStreamsInRoom.remove(stream.getPeerId());

        SkyWayRemoteVideoChild video = videoChildren.get(stream.getPeerId());

        stream.setEnableAudioTrack(0, false);
        stream.setEnableVideoTrack(0, false);
        // videoChildren.remove(stream.getPeerId());

        eventSink.success(makeSink("remove_stream", "peerId", stream.getPeerId()));
        video.close();// idが消えるので最後にする
      }
    });

  }

  private void leaveRoomAction(MethodChannel.Result result) {
    if (null == _peer || null == _room) {
      result.error("not exist error", "room or peer is not exist", "");
      return;
    }
    _room.close();
    result.success(true);
  }

  private void switchCameraAction(MethodChannel.Result result) {
    if (null != _localStream) {
      Boolean r = _localStream.switchCamera();
      if (true == r) {
        result.success(true);
      } else {

        result.error("can not switching", "can not switching", "");
      }
    }
  }

  private void enableAudioAction(MethodCall call, MethodChannel.Result result) {
    if (null != _localStream) {
      Map<String, Boolean> args = (Map<String, Boolean>) call.arguments;// 引数取得
      boolean isEnable = args.get("isEnable");
      _localStream.setEnableAudioTrack(0, isEnable);

      areMuteVideo.put(_peer.identity(), !isEnable);
      result.success(isEnable);
      return;
    }

    result.error("initializing error", "localStream is not Initialized", "");
  }

  private void enableVideoAction(MethodCall call, MethodChannel.Result result) {
    if (null != _localStream) {
      Map<String, Boolean> args = (Map<String, Boolean>) call.arguments;// 引数取得
      boolean isEnable = args.get("isEnable");
      _localStream.setEnableVideoTrack(0, isEnable);

      areMuteAudio.put(_peer.identity(), !isEnable);
      result.success(isEnable);
      return;
    }

    result.error("initializing error", "localStream is not Initialized", "");
  }

  private void showOtherVideoAction(MethodCall call, MethodChannel.Result result) {
    Map<String, Object> args = (Map<String, Object>) call.arguments;// 引数取得
    String peerId = (String) args.get("peerId");
    Boolean isEnable = (Boolean) args.get("isEnable");

    MediaStream stream = allStreamsInRoom.get(peerId);
    SkyWayRemoteVideoChild video = videoChildren.get(stream.getPeerId());

    areMuteAudio.put(_peer.identity(), !isEnable);
    areMuteVideo.put(_peer.identity(), !isEnable);
    stream.setEnableAudioTrack(0, isEnable);// 大元をを消せるわけではないらしい
    stream.setEnableVideoTrack(0, isEnable);
    video.setUpRemoteStream();

    result.success(peerId);
  }

  private void getAllPeerIdAction(MethodChannel.Result result) {

    List<String> allPeerId = new ArrayList<>();

    // keySetを使用してMapの要素数分ループする
    for (String key : allStreamsInRoom.keySet()) {
      allPeerId.add(key);
    }
    result.success(allPeerId);
  }

  private void getShowingPeerIdsAction(MethodChannel.Result result) {

    List<String> showingPeerIds = new ArrayList<>();

    // keySetを使用してMapの要素数分ループする
    for (String key : videoChildren.keySet()) {
      showingPeerIds.add(key);
    }
    result.success(showingPeerIds);
  }

  private void destroyPeerAction(MethodChannel.Result result) {
    if (null != _localStream) {
      _localStream.removeVideoRenderer(_localStreamView, 0);
      _localStream.close();
    }

    Navigator.terminate();

    if (null != _peer) {
      unsetPeerCallback(_peer);
      if (!_peer.isDisconnected()) {
        _peer.disconnect();
      }

      if (!_peer.isDestroyed()) {
        _peer.destroy();
      }

      _peer = null;
    }

    result.success(true);
  }

  private void changeSpeakerAction(MethodCall call, MethodChannel.Result result) {
    Map<String, Boolean> args = (Map<String, Boolean>) call.arguments;// 引数取得
    Boolean isSpeaker = args.get("isSpeaker");

    AudioManager audioManager = (AudioManager) registrar.context().getSystemService(Context.AUDIO_SERVICE);
    audioManager.setMode(AudioManager.MODE_IN_COMMUNICATION);
    MediaPlayer mediaPlayer = new MediaPlayer();

    audioManager.setSpeakerphoneOn(isSpeaker);

    mediaPlayer.setAudioStreamType(AudioManager.MODE_IN_COMMUNICATION);

    result.success(true);
  }

  private void afterPlatformViewWaitingAction(MethodCall call, MethodChannel.Result result) {
    Map<String, Object> args = (Map<String, Object>) call.arguments;// 引数取得
    String peerId = (String) args.get("peerId");
    Boolean isMine = (Boolean) args.get("isMine");

    if (isMine && !areMuteAudio.get(_peer.identity()) && !areMuteVideo.get(_peer.identity())) {
      _localStream.removeVideoRenderer(_localStreamView, 0);
      _localStream.addVideoRenderer(_localStreamView, 0);

    } else {
      if (!areMuteAudio.get(peerId) && !areMuteVideo.get(peerId)) {
        factories.get(peerId).streamView = videoChildren.get(peerId).remoteStreamView;
        videoChildren.get(peerId).remoteStream.addVideoRenderer(videoChildren.get(peerId).remoteStreamView, 0);
      }
    }

    result.success(true);
  }

  void startLocalStream() {
    Navigator.initialize(_peer);
    MediaConstraints constraints = new MediaConstraints();
    _localStream = Navigator.getUserMedia(constraints);

    _localStreamView = new Canvas(registrar.context());
    _localStream.addVideoRenderer(_localStreamView, 0);
  }

  void unsetPeerCallback(Peer peer) {
    if (null == _peer) {
      return;
    }
    peer.on(Peer.PeerEventEnum.OPEN, null);
    peer.on(Peer.PeerEventEnum.CONNECTION, null);
    peer.on(Peer.PeerEventEnum.CALL, null);
    peer.on(Peer.PeerEventEnum.CLOSE, null);
    peer.on(Peer.PeerEventEnum.DISCONNECTED, null);
    peer.on(Peer.PeerEventEnum.ERROR, null);
  }

  Map makeSink(String event, String bodyName, String body) {

    Map<String, String> send = new HashMap<String, String>();
    send.put("event", event);
    send.put(bodyName, body);
    return send;
  }
}

class FlutterPlatformViewFactory extends PlatformViewFactory {

  public FlutterPlatformViewFactory(Canvas streamView) {

    super(StandardMessageCodec.INSTANCE);
    this.streamView = streamView;
  }

  public Canvas streamView;

  @Override
  public PlatformView create(Context context, int viewId, Object args) {

    return new FlutterPlatformView(streamView);
  }
}

class FlutterPlatformView implements PlatformView {

  FlutterPlatformView(Canvas view) {
    this.view = view;
  }

  Canvas view;

  @Override
  public View getView() {
    return view;
  }

  @Override
  public void dispose() {

  }
}