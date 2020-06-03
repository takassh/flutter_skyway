import Flutter
import UIKit
import SkyWay
import AVFoundation

class FlutterSkywayPlatformView: NSObject, FlutterPlatformView {//playformViewでラップしている
    let platformView: UIView
    init(_ platformView: UIView) {
        self.platformView = platformView
        super.init()
    }
    func view() -> UIView {
        return platformView
    }
}

public class SwiftFlutterSkywayPlugin: NSObject {
    
    private static let CHANNEL = "flutter_skyway"
    
    private let registrar:FlutterPluginRegistrar
    
    private var _peer:SKWPeer
    private var _localStream:SKWMediaStream
    private var _localStreamView:SKWVideo = SKWVideo()
    private var _room:SKWSFURoom?
    private var areMuteAudio = [String:Bool]();//muteにしているかどうか
    private var areMuteVideo = [String:Bool]();
    
    private var allStreamsInRoom=[String: SKWMediaStream]()//roomの全てのstream
    private var videoChildren=[String:SkyWayRemoteVideoChild]()//これまで全てのvideoが格納(roomを離れたとしても)
    private var factories=[String:PlatformViewFactory]()//これまで使ったfactoryが格納(再びviewを設定したいときに使う)
    
    private var eventChannel:FlutterEventChannel?
    private var eventSink:FlutterEventSink?
    
    init(registrar: FlutterPluginRegistrar) {
        self.eventChannel = FlutterEventChannel()
        self._peer = SKWPeer(id: "tmp", options:SKWPeerOption())!
        self._localStream = SKWMediaStream()
        self.registrar = registrar
        super.init()
    }

    
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterSkywayPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    
    private func createEventChannel( peerId:String)->FlutterEventChannel {
        let eventChannel:FlutterEventChannel = FlutterEventChannel(name: SwiftFlutterSkywayPlugin.CHANNEL + "/" + peerId, binaryMessenger: registrar.messenger())
        return eventChannel;
    }
    
    
    private func connectAction(_ call:FlutterMethodCall,result:@escaping FlutterResult){
        guard let args = call.arguments as? [String: Any],
            let apiKey = args["apiKey"] as? String,
            let domain = args["domain"] as? String else {
                result(FlutterError(code: "InvalidArguments",
                                    message: "`apiKey` and `domain` must not be null.",
                                    details: nil))
                return
        }
        
        let option = SKWPeerOption.init()
        option.key = apiKey
        option.domain = domain
        
        if let _peer = SKWPeer.init(options: option){
        self._peer = _peer
        
        _peer.on(.PEER_EVENT_OPEN){ (object) in
            if let _strOwnId:String = object as? String{
                self.eventChannel = self.createEventChannel(peerId: _strOwnId);//自分のid
                self.eventChannel!.setStreamHandler(self)
                
                self.registrar.register(PlatformViewFactory(streamView: self._localStreamView), withId:"flutter_skyway/video_view/"+self._peer.identity!)
                
                
                
                
                result(_strOwnId);
                
                
            }
        }
        _peer.on(.PEER_EVENT_CLOSE){(object)in
            print("[On/Close]")
        }
        _peer.on(.PEER_EVENT_DISCONNECTED){(object)in
            print("[On/Disconnected]")
        }
        _peer.on(.PEER_EVENT_ERROR){(object)in
            let error:SKWPeerError  = object as! SKWPeerError
            print("[On/Error] \(error)")
        }
        }
    }
    
    func joinRoomAction(_ call:FlutterMethodCall,result:@escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let roomName = args["roomName"] as? String else {
                result(FlutterError(code: "room name error",
                                    message: "You should input room name",
                                    details: nil))
                return
        }
        
        if ((nil == _peer.identity) || (0 == _peer.identity!.count)) {
            result(FlutterError(code: "peer id error",message: "Your PeerID is null or invalid",
                                details: nil));
            return;
        }
        
        self.startLocalStream()//ios側で準備できてからじゃないと黒くなる
        
        let option:SKWRoomOption = SKWRoomOption()
        
        option.mode = SKWRoomModeEnum.ROOM_MODE_SFU
        option.stream = _localStream;
        if let _room = _peer.joinRoom(withName: roomName, options: option){
    
        result(true)
        
            self._room = (_room as! SKWSFURoom)
        
        _room.on(.ROOM_EVENT_OPEN){(object)in
            if let roomName:String = object as? String{
               print("Enter Room: " + roomName);
                self.eventSink!(self.makeSink(event: "open", bodyName: "roomName", body: roomName))
            }
        }
        
        _room.on(.ROOM_EVENT_CLOSE){(object)in
            if let roomName:String = object as? String{
              
                // Unset callbacks
                _room.on(.ROOM_EVENT_OPEN, callback: nil);
                _room.on(.ROOM_EVENT_CLOSE, callback: nil);
                _room.on(.ROOM_EVENT_ERROR, callback: nil);
                _room.on(.ROOM_EVENT_PEER_JOIN, callback: nil);
                _room.on(.ROOM_EVENT_PEER_LEAVE,callback: nil);
                _room.on(.ROOM_EVENT_STREAM,callback: nil);
                _room.on(.ROOM_EVENT_REMOVE_STREAM,callback: nil);
                
                self._room!.close()
                self.videoChildren=[String:SkyWayRemoteVideoChild]()//もしかするとそれぞれcloseしないとかも
                self.allStreamsInRoom = [String:SKWMediaStream]()
                
                self.eventSink!(self.makeSink(event: "close",bodyName: "roomName",body: roomName));
            }
            
        }
        
        _room.on(.ROOM_EVENT_ERROR){(object)in
            if let error:SKWPeerError = object as? SKWPeerError{
                print("RoomEventEnum.ERROR:" + error.message)
                self.eventSink!(self.makeSink(event: "error",bodyName: "error",body: error.message));
            }
        }
        
        _room.on(.ROOM_EVENT_PEER_JOIN){[weak self](object)in
            if let peerId:String = object as? String,
                peerId != ""{
                
                print("Join Room: " + peerId);
                self!.eventSink!(self!.makeSink(event: "join",bodyName: "peerId",body: peerId));
            }
            
            
        }
        _room.on(.ROOM_EVENT_PEER_LEAVE){(object)in
            if let peerId:String = object as? String{
                print("Leave Room: " + peerId);
                self.eventSink!(self.makeSink(event: "leave",bodyName: "peerId",body: peerId));
            }
            
        }
        
        _room.on(.ROOM_EVENT_STREAM){remoteStream in
            if let stream:SKWMediaStream = remoteStream as? SKWMediaStream {
                
                self.allStreamsInRoom[stream.peerId!] = stream
                
                let video = SkyWayRemoteVideoChild(remoteStream: stream)

                if(self.videoChildren[stream.peerId!]==nil){
                    
                    let instance = PlatformViewFactory(streamView: video.remoteStreamView)
                    
                    self.factories[stream.peerId!] = instance
                    
                    self.registrar.register(instance, withId:"flutter_skyway/video_view/"+stream.peerId!)
                    //platform viewは作っておく
                    
                    self.videoChildren[stream.peerId!] = video
                    
                    
                }
                else{
                    
                    self.videoChildren[stream.peerId!] = video
                    self.factories[stream.peerId!]?.streamView = video.remoteStreamView
                }
  
                self.areMuteVideo[stream.peerId!] = false
                self.areMuteAudio[stream.peerId!] = false
                
                print("stream peerId: " + stream.peerId!);
                self.eventSink!(self.makeSink(event: "stream",bodyName: "peerId",body: stream.peerId!));
            }
            
           
            
        }
        
        _room.on(.ROOM_EVENT_REMOVE_STREAM){(object)in
            if let stream:SKWMediaStream = object as? SKWMediaStream{
                
                self.allStreamsInRoom[stream.peerId!]=nil
                print("remove stream peerId: " + stream.peerId!);
                
                if let video = self.videoChildren[stream.peerId!] {
                
                stream.setEnableAudioTrack(0, enable: false)
                stream.setEnableVideoTrack(0, enable: false)
               // self.videoChildren[stream.peerId!]=nil
                    
                self.eventSink!(self.makeSink(event: "remove_stream",bodyName: "peerId",body: stream.peerId!))
                    video.close()//idが消えるので最後にする
                }
            }
        }
        }
    }
    
    private func leaveRoomAction(result:FlutterResult) {
        self._room!.close()
        result(true);
    }
    
    private func switchCameraAction(result:FlutterResult){
        let r:Bool = self._localStream.switchCamera();
        if(true == r)    {
            result(true);
        }
        else {
            
            result(FlutterError(code: "can not switching",message: "can not switching",
                                details: nil))
        }
    }
    
    private func enableAudioAction(call:FlutterMethodCall,result:FlutterResult){
        guard let args = call.arguments as? [String: Any],
            let isEnable = args["isEnable"] as? Bool else {
                result(FlutterError(code: "argument error",
                                    message: "isEnable is necessary",
                                    details: nil))
                return
        }
        _localStream.setEnableAudioTrack(0,enable: isEnable);
        
        areMuteAudio[_peer.identity!] = !isEnable
        
        result(isEnable);
    }
    
    private func enableVideoAction(call:FlutterMethodCall,result:FlutterResult){
        guard let args = call.arguments as? [String: Any],
            let isEnable = args["isEnable"] as? Bool else {
                result(FlutterError(code: "argument error",
                                    message: "isEnable is necessary",
                                    details: nil))
                return
        }
        _localStream.setEnableVideoTrack(0,enable: isEnable);
        
        areMuteVideo[_peer.identity!] = !isEnable
        
        
        result(isEnable);
    }
    
    private func showOtherVideoAction(call:FlutterMethodCall,result:FlutterResult){
        guard let args = call.arguments as? [String: Any],
            let peerId = args["peerId"] as? String ,
        let isEnable = args["isEnable"] as? Bool else {
                result(FlutterError(code: "argument error",
                                    message: "peerId or isEnable is necessary",
                                    details: nil))
                return
        }
        
        if let stream = allStreamsInRoom[peerId]{
            if  let video = videoChildren[stream.peerId!]{
                
                areMuteVideo[stream.peerId!] = !isEnable
                areMuteAudio[stream.peerId!] = !isEnable
                stream.setEnableAudioTrack(0,enable: isEnable)
                stream.setEnableVideoTrack(0,enable: isEnable)
                video.setUpRemoteStream()
                
                result(peerId);
            }
        }
    }
    
    private func getAllPeerIdAction(result:FlutterResult) {
        
        let allPeerId:Array<String> = [String](allStreamsInRoom.keys)
        result(allPeerId);
    }
    
    private func getShowingPeerIdsAction(result:FlutterResult) {
        
        let showingPeerIds:Array<String> = [String](videoChildren.keys)
        result(showingPeerIds);
    }
    
    private func destroyPeerAction(result:FlutterResult) {
        _localStream.removeVideoRenderer(_localStreamView,track: 0);
        _localStream.close();
        
        SKWNavigator.terminate();
        
        
        unsetPeerCallback(peer: _peer);
        if (!_peer.isDisconnected) {
            _peer.disconnect();
        }
        
        if (!_peer.isDestroyed) {
            _peer.destroy();
        }
        
        result(true);
    }
    
    private func changeSpeakerAction(_ call:FlutterMethodCall, result:FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let isSpeaker = args["isSpeaker"] as? Bool else {
                result(FlutterError(code: "argument error",
                                    message: "isSpeaker is necessary",
                                    details: nil))
                return
        }
        
        
        let audioSession = AVAudioSession.sharedInstance()
        if(isSpeaker){
            do {
                try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
                result(true)
            } catch let error as NSError {
                print("audioSession error: \(error.localizedDescription)")
                result(FlutterError(code: "session error",
                                    message: "audioSession error: \(error.localizedDescription)",
                    details: nil))
            }
        }
        else{
            do {
                try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.none)
                result(true)
            } catch let error as NSError {
                print("audioSession error: \(error.localizedDescription)")
                result(FlutterError(code: "session error",
                                    message: "audioSession error: \(error.localizedDescription)",
                    details: nil))
            }
        }
    }
    
    private func afterPlatformViewWaitingAction(_ call:FlutterMethodCall,result:FlutterResult){
        guard let args = call.arguments as? [String: Any],
            let peerId = args["peerId"] as? String,
            let isMine = args["isMine"] as? Bool else {
                result(FlutterError(code: "argument error",
                                    message: "peerId or isMine is necessary",
                                    details: nil))
                return
        }
        
        if(isMine && !areMuteVideo[self._peer.identity!]! && !areMuteAudio[self._peer.identity!]!){
            
                self._localStream.removeVideoRenderer(self._localStreamView, track: 0)
                self._localStream.addVideoRenderer(self._localStreamView, track: 0)
            
        }
        else{
            if(!areMuteVideo[peerId]! && !areMuteAudio[peerId]!){
            self.factories[peerId]?.streamView = self.videoChildren[peerId]!.remoteStreamView
            self.videoChildren[peerId]!.remoteStream!.addVideoRenderer(self.videoChildren[peerId]!.remoteStreamView, track: 0)
            }
        }
        
        result(true)
    }
    
    func startLocalStream() {
        
        SKWNavigator.initialize(self._peer)
        
        let constraints =  SKWMediaConstraints()
        constraints.maxHeight=10000
        constraints.maxWidth=10000
        
        areMuteAudio[self._peer.identity!] = false;
        areMuteVideo[self._peer.identity!] = false;
        
        if let localStream = SKWNavigator.getUserMedia(constraints){
            localStream.addVideoRenderer(self._localStreamView, track: 0)
            self._localStream = localStream
        }
        
    }
    
    

    func unsetPeerCallback(peer:SKWPeer) {
        peer.on(.PEER_EVENT_OPEN, callback: nil);
        peer.on(.PEER_EVENT_CONNECTION, callback: nil);
        peer.on(.PEER_EVENT_CALL, callback: nil);
        peer.on(.PEER_EVENT_CLOSE, callback: nil);
        peer.on(.PEER_EVENT_DISCONNECTED, callback: nil);
        peer.on(.PEER_EVENT_ERROR, callback: nil);
    }
    
    func makeSink(event:String,bodyName:String,body:String)->Dictionary<String,String>{
        
        var send:Dictionary<String, String> = Dictionary<String, String>();
        
        send["event"] = event
        send[bodyName] = body
        return send;
    }
}

extension SwiftFlutterSkywayPlugin: FlutterPlugin {
    enum Method: String {
        case connectAction
        case joinRoomAction
        case leaveRoomAction
        case switchCameraAction
        case enableAudioAction
        case enableVideoAction
        case showOtherVideoAction
        case getAllPeerIdAction
        case getShowingPeerIdsAction
        case destroyPeerAction
        case afterPlatformViewWaitingAction
        case changeSpeakerAction
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let method = Method.init(rawValue: call.method) else {
            result(FlutterMethodNotImplemented)
            return
        }
        switch method {
        case .connectAction: connectAction(call, result: result)
        case .joinRoomAction: joinRoomAction(call, result:result)
        case .leaveRoomAction: leaveRoomAction(result:result)
        case .switchCameraAction: switchCameraAction(result:result)
        case .enableAudioAction: enableAudioAction(call: call,result:result)
        case .enableVideoAction: enableVideoAction(call: call,result:result)
        case .showOtherVideoAction: showOtherVideoAction(call: call,result:result)
        case .getAllPeerIdAction: getAllPeerIdAction(result:result)
        case .getShowingPeerIdsAction: getShowingPeerIdsAction(result:result)
        case .destroyPeerAction: destroyPeerAction(result:result)
        case .afterPlatformViewWaitingAction: afterPlatformViewWaitingAction(call, result: result)
        case .changeSpeakerAction: changeSpeakerAction(call,result: result)
        }
    }
}
extension SwiftFlutterSkywayPlugin: FlutterStreamHandler{
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        
        return nil
    }
}

class PlatformViewFactory:NSObject{
    
    init(streamView:SKWVideo) {
        self.streamView=streamView
    }
    
    public var streamView:SKWVideo
}
extension PlatformViewFactory: FlutterPlatformViewFactory {
    public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let view = UIView()
        view.frame = frame
        view.backgroundColor = .black
        
        streamView.frame = view.bounds
        streamView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(streamView)
        return PlatformView(view)
    }
}

private class PlatformView: NSObject, FlutterPlatformView {
    let platformView: UIView
    init(_ platformView: UIView) {
        self.platformView = platformView
        super.init()
    }
    func view() -> UIView {
        return platformView
    }
}
