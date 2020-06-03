package com.kasai.flutter_skyway_example;

import com.kasai.flutter_skyway.FlutterSkywayPlugin;

import android.content.pm.PackageManager;
import android.os.Bundle;
import android.widget.Toast;

import com.kasai.flutter_skyway.FlutterSkywayPlugin;

import io.flutter.app.FlutterActivity;

public class MainActivity extends FlutterActivity{

    @Override
    public void onCreate(Bundle savedInstanceState) {

        super.onCreate(savedInstanceState);
        FlutterSkywayPlugin.registerWith(this.registrarFor("main"));
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String permissions[], int[] grantResults) {
        switch (requestCode) {
            case 0: {
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    FlutterSkywayPlugin.isPERMISSION_GRANTED = true;
                } else {
                    Toast.makeText(this,
                            "Failed to access the camera and microphone.\nclick allow when asked for permission.",
                            Toast.LENGTH_LONG).show();
                    FlutterSkywayPlugin.isPERMISSION_GRANTED = false;
                }
                break;
            }
        }
    }

}