package app.classsync.classsync

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingInstall: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "classsync/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "save" -> {
                        val slots = call.arguments as? List<*> ?: emptyList<Any>()
                        val json = JSONArray()
                        slots.forEach { item ->
                            if (item is Map<*, *>) {
                                val record = JSONObject()
                                item.forEach { (key, value) ->
                                    if (key is String) record.put(key, value)
                                }
                                json.put(record)
                            }
                        }
                        getSharedPreferences(NextClassWidgetProvider.PREFS, MODE_PRIVATE)
                            .edit().putString(NextClassWidgetProvider.SLOTS, json.toString()).apply()
                        NextClassWidgetProvider.refreshAll(this)
                        result.success(null)
                    }
                    "pin" -> {
                        val manager = AppWidgetManager.getInstance(this)
                        val supported = Build.VERSION.SDK_INT >= 26 &&
                            manager.isRequestPinAppWidgetSupported
                        if (supported) {
                            manager.requestPinAppWidget(
                                ComponentName(this, NextClassWidgetProvider::class.java),
                                null, null,
                            )
                        }
                        result.success(supported)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "classsync/updates")
            .setMethodCallHandler { call, result ->
                if (call.method != "installApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.arguments as? String
                val file = path?.let { File(it).canonicalFile }
                val updateDir = File(cacheDir, "classsync-updates").canonicalFile
                if (file == null || file.parentFile != updateDir ||
                    file.name != "ClassSync-Android.apk" || !file.isFile) {
                    result.error("invalid_apk", "Update file is unavailable.", null)
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                    pendingInstall = file
                    startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName")))
                    result.success(null)
                } else {
                    launchInstaller(file)
                    result.success(null)
                }
            }
    }

    override fun onResume() {
        super.onResume()
        val file = pendingInstall ?: return
        if (Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls()) {
            pendingInstall = null
            launchInstaller(file)
        }
    }

    private fun launchInstaller(file: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }
}
