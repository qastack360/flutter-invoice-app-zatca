package com.example.flutter_invoice_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import android.os.Build
import android.Manifest

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val permissions = arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
            permissions.forEach { permission ->
                if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(arrayOf(permission), 0)
                }
            }
        }
    }
}