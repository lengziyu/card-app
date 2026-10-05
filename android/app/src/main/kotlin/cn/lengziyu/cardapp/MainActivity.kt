package cn.lengziyu.cardapp

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "cardfi/notifications",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "authorizationStatus" -> result.success(notificationAuthorizationStatus())
                "openSettings" -> result.success(openNotificationSettings())
                else -> result.notImplemented()
            }
        }
    }

    private fun notificationAuthorizationStatus(): String {
        val notificationsEnabled = NotificationManagerCompat.from(this)
            .areNotificationsEnabled()
        if (!notificationsEnabled) return "denied"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permissionGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
            if (!permissionGranted) return "denied"
        }
        return "authorized"
    }

    private fun openNotificationSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                val fallback = Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName"),
                )
                startActivity(fallback)
                true
            } catch (_: Exception) {
                false
            }
        }
    }
}
