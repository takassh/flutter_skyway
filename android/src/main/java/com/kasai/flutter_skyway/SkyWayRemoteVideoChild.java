package com.kasai.flutter_skyway;


import io.flutter.plugin.common.PluginRegistry;
import io.skyway.Peer.Browser.Canvas;
import io.skyway.Peer.Browser.MediaStream;

public class SkyWayRemoteVideoChild {

    SkyWayRemoteVideoChild(MediaStream remoteStream,PluginRegistry.Registrar registrar){
        this.remoteStream = remoteStream;
        this.remoteStreamView = new Canvas(registrar.context());
    }

    public MediaStream remoteStream;
    public Canvas remoteStreamView;

    void setUpRemoteStream() {//描画を始める
        remoteStream.addVideoRenderer(remoteStreamView, 0);
    }

    void close() {
        if (null == remoteStream) {
            return;
        }
        tearDownRemoteStream();
    }

    private void tearDownRemoteStream() {
        remoteStream.removeVideoRenderer(remoteStreamView, 0);
        remoteStream.close();
    }
}