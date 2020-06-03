//
//  SkyWayRemoteVideoChild.swift
//  flutter_skyway
//
//  Created by 笠井貴史 on 2020/05/29.
//

import SkyWay
import Foundation
import Flutter

public class SkyWayRemoteVideoChild: NSObject {
    init(remoteStream:SKWMediaStream) {
        self.remoteStream = remoteStream
        remoteStreamView = SKWVideo()
    }
    
    public var remoteStream:SKWMediaStream?
    public var remoteStreamView:SKWVideo
    
    func setUpRemoteStream(){
        remoteStream!.addVideoRenderer(remoteStreamView, track: 0)
    }
    
   public func close() {//描画を止める
        if (nil == remoteStream) {
            return;
        }
        tearDownRemoteStream();
    }

    private func tearDownRemoteStream() {
        remoteStream!.removeVideoRenderer(remoteStreamView, track: 0);
        remoteStream!.close();
    }
}
