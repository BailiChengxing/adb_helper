package com.example.adb_helper

import android.content.pm.PackageManager
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Build
import com.example.adb_helper.gateway.AndroidShellBackend
import com.example.adb_helper.gateway.AndroidAdbTransport
import com.example.adb_helper.gateway.ShellEventSink
import com.example.adb_helper.gateway.ShellSession
import com.example.adb_helper.gateway.TransportMode
import com.example.adb_helper.gateway.WireEvent
import rikka.shizuku.Shizuku
import com.topjohnwu.superuser.Shell
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ShellEventSink {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newCachedThreadPool()
    private val sessions = ConcurrentHashMap<String, ShellSession>()
    private val backend by lazy { AndroidShellBackend(this) }
    private val adbTransport by lazy { AndroidAdbTransport(applicationContext, this) }
    @Volatile private var eventSink: EventChannel.EventSink? = null
    private var pendingDocumentResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "discover" -> discover(result)
            "pair" -> pair(call, result)
            "connectWireless" -> connectWireless(call, result)
            "openSession" -> openSession(call, result)
            "writeStdin" -> writeStdin(call, result)
            "closeSession" -> closeSession(call, result)
            "execOnce" -> execOnce(call, result)
            "requestShizukuPermission" -> requestShizukuPermission(result)
            "executionCapabilities" -> executionCapabilities(call, result)
            "pickDocument" -> pickDocument(call, result)
            "listApplications" -> withAdbArgs(call, result) { transport, serial, _ ->
                adbTransport.listApplications(transport, serial)
            }
            "deviceInformation" -> deviceInformation(call, result)
            "listHostApplications" -> executor.execute {
                try {
                    val apps = packageManager.getInstalledPackages(
                        PackageManager.GET_ACTIVITIES or PackageManager.GET_META_DATA,
                    ).mapNotNull { packageInfo ->
                        val applicationInfo = packageInfo.applicationInfo ?: return@mapNotNull null
                        mapOf(
                            "packageName" to packageInfo.packageName,
                            "label" to packageManager.getApplicationLabel(applicationInfo).toString(),
                            "versionName" to packageInfo.versionName,
                            "versionCode" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                packageInfo.longVersionCode
                            } else {
                                @Suppress("DEPRECATION")
                                packageInfo.versionCode.toLong()
                            },
                            "systemApp" to (
                                applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM != 0
                            ),
                        )
                    }.sortedBy { it["label"] as String }
                    mainHandler.post { result.success(apps) }
                } catch (error: Exception) {
                    mainHandler.post {
                        result.error(
                            "HOST_APPS_FAILED",
                            error.message ?: "Unable to read applications on this device.",
                            null,
                        )
                    }
                }
            }
            "installApplication" -> withAdbArgs(call, result) { transport, serial, args ->
                adbTransport.installApplication(
                    transport,
                    serial,
                    args.requiredString("uri"),
                )
            }
            "installHostApplication" -> withAdbArgs(call, result) { transport, serial, args ->
                adbTransport.installHostApplication(
                    transport,
                    serial,
                    args.requiredString("packageName"),
                )
            }
            "uninstallApplication" -> withPackageArgs(call, result) { transport, serial, packageName ->
                adbTransport.uninstallApplication(transport, serial, packageName)
            }
            "launchApplication" -> withPackageArgs(call, result) { transport, serial, packageName ->
                adbTransport.launchApplication(transport, serial, packageName)
            }
            "forceStopApplication" -> withPackageArgs(call, result) { transport, serial, packageName ->
                adbTransport.forceStopApplication(transport, serial, packageName)
            }
            "clearApplicationData" -> withPackageArgs(call, result) { transport, serial, packageName ->
                adbTransport.clearApplicationData(transport, serial, packageName)
            }
            "setApplicationEnabled" -> withAdbArgs(call, result) { transport, serial, args ->
                adbTransport.setApplicationEnabled(
                    transport,
                    serial,
                    args.requiredString("packageName"),
                    args["enabled"] as? Boolean
                        ?: throw IllegalArgumentException("The enabled option is required."),
                )
            }
            "openApplicationSettings" -> withPackageArgs(call, result) { transport, serial, packageName ->
                adbTransport.openApplicationSettings(transport, serial, packageName)
            }
            "listFiles" -> withAdbArgs(call, result) { transport, serial, args ->
                adbTransport.listFiles(transport, serial, args.requiredString("path"))
            }
            "pushFile" -> withAdbArgs(call, result) { transport, serial, args ->
                adbTransport.pushFile(
                    transport,
                    serial,
                    args.requiredString("uri"),
                    args.requiredString("path"),
                )
            }
            "pullFile" -> withAdbArgs(call, result) { transport, serial, args ->
                adbTransport.pullFile(
                    transport,
                    serial,
                    args.requiredString("path"),
                    args.requiredString("uri"),
                )
            }
            "deleteFile" -> withAdbArgs(call, result) { transport, serial, args ->
                adbTransport.deleteFile(transport, serial, args.requiredString("path"))
            }
            "createDirectory" -> withAdbArgs(call, result) { transport, serial, args ->
                adbTransport.createDirectory(transport, serial, args.requiredString("path"))
            }
            "renameFile" -> withAdbArgs(call, result) { transport, serial, args ->
                adbTransport.renameFile(
                    transport,
                    serial,
                    args.requiredString("from"),
                    args.requiredString("to"),
                )
            }
            "statFile" -> withAdbArgs(call, result) { transport, serial, args ->
                adbTransport.statFile(transport, serial, args.requiredString("path"))
            }
            else -> result.notImplemented()
        }
    }

    private fun connectWireless(call: MethodCall, result: MethodChannel.Result) {
        val host = call.argument<String>("host")
            ?: return result.error("INVALID_ENDPOINT", "A wireless device IP is required.", null)
        val port = call.argument<Int>("port")
            ?: return result.error("INVALID_ENDPOINT", "An ADB port is required.", null)
        executor.execute {
            try {
                val device = adbTransport.connectWireless(host, port)
                mainHandler.post { result.success(device) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error(
                        "WIRELESS_CONNECT_FAILED",
                        error.message ?: "Unable to connect to the wireless ADB device.",
                        null,
                    )
                }
            }
        }
    }

    private fun deviceInformation(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments<Map<String, Any?>>() ?: emptyMap()
        if (args["transport"] != "local") {
            withAdbArgs(call, result) { transport, serial, _ ->
                adbTransport.deviceInformation(transport, serial)
            }
            return
        }
        executor.execute {
            try {
                val metrics = resources.displayMetrics
                val stat = android.os.StatFs(android.os.Environment.getDataDirectory().path)
                val info = linkedMapOf(
                    "Manufacturer" to Build.MANUFACTURER,
                    "Brand" to Build.BRAND,
                    "Model" to Build.MODEL,
                    "Device" to Build.DEVICE,
                    "Android version" to Build.VERSION.RELEASE,
                    "API level" to Build.VERSION.SDK_INT.toString(),
                    "Security patch" to Build.VERSION.SECURITY_PATCH,
                    "Build ID" to Build.DISPLAY,
                    "Build fingerprint" to Build.FINGERPRINT,
                    "Supported ABIs" to Build.SUPPORTED_ABIS.joinToString(),
                    "Screen resolution" to "${metrics.widthPixels} x ${metrics.heightPixels}",
                    "Screen density" to "${metrics.densityDpi} dpi",
                    "Data storage" to "${stat.availableBytes / (1024 * 1024)} MiB available / " +
                        "${stat.totalBytes / (1024 * 1024)} MiB total",
                )
                mainHandler.post { result.success(info) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error(
                        "DEVICE_INFO_FAILED",
                        error.message ?: "Unable to read this device's information.",
                        null,
                    )
                }
            }
        }
    }

    private fun withPackageArgs(
        call: MethodCall,
        result: MethodChannel.Result,
        operation: (String, String, String) -> Any?,
    ) {
        withAdbArgs(call, result) { transport, serial, args ->
            operation(transport, serial, args.requiredString("packageName"))
        }
    }

    private fun withAdbArgs(
        call: MethodCall,
        result: MethodChannel.Result,
        operation: (String, String, Map<String, Any?>) -> Any?,
    ) {
        val args = call.arguments<Map<String, Any?>>() ?: emptyMap()
        executor.execute {
            try {
                val transport = args["transport"] as? String
                    ?: throw IllegalArgumentException("An ADB transport is required.")
                val serial = args["serial"] as? String
                    ?: throw IllegalArgumentException("An ADB device is required.")
                val value = operation(transport, serial, args)
                mainHandler.post { result.success(if (value == Unit) null else value) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error(
                        "DEVICE_OPERATION_FAILED",
                        error.message ?: "Device operation failed.",
                        null,
                    )
                }
            }
        }
    }

    private fun pickDocument(call: MethodCall, result: MethodChannel.Result) {
        if (pendingDocumentResult != null) {
            result.error("PICKER_BUSY", "A document picker is already open.", null)
            return
        }
        val apkOnly = call.argument<Boolean>("apkOnly") == true
        val aabOnly = call.argument<Boolean>("aabOnly") == true
        val saveAs = call.argument<String>("saveAs")
        val intent = if (saveAs != null) {
            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(Intent.EXTRA_TITLE, saveAs)
            }
        } else {
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                if (apkOnly) {
                    putExtra(
                        Intent.EXTRA_MIME_TYPES,
                        arrayOf(
                            "application/vnd.android.package-archive",
                            "application/octet-stream",
                        ),
                    )
                } else if (aabOnly) {
                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/octet-stream"))
                }
            }
        }
        pendingDocumentResult = result
        try {
            startActivityForResult(intent, DOCUMENT_REQUEST_CODE)
        } catch (error: Exception) {
            pendingDocumentResult = null
            result.error(
                "DOCUMENT_PICKER_FAILED",
                error.message ?: "Unable to open document picker.",
                null,
            )
        }
    }

    private fun executionCapabilities(call: MethodCall, result: MethodChannel.Result) {
        val checkRoot = call.argument<Boolean>("checkRoot") == true
        executor.execute {
            val rootAvailable = if (checkRoot) {
                try {
                    Shell.getShell().isRoot
                } catch (_: Exception) {
                    false
                }
            } else false
            val capabilities = mapOf(
                "shizukuAvailable" to Shizuku.pingBinder(),
                "shizukuPermission" to hasShizukuPermission(),
                "rootAvailable" to rootAvailable,
            )
            mainHandler.post { result.success(capabilities) }
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != DOCUMENT_REQUEST_CODE) return
        val pending = pendingDocumentResult ?: return
        pendingDocumentResult = null
        val uri: Uri? = if (resultCode == RESULT_OK) data?.data else null
        pending.success(uri?.toString())
    }

    private fun Map<String, Any?>.requiredString(key: String): String =
        this[key] as? String ?: throw IllegalArgumentException("A $key value is required.")

    private fun discover(result: MethodChannel.Result) {
        executor.execute {
            try {
                val devices = adbTransport.discover()
                mainHandler.post { result.success(devices) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("DISCOVERY_FAILED", error.message ?: "Unable to discover ADB devices.", null)
                }
            }
        }
    }

    private fun pair(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments<Map<String, Any?>>() ?: emptyMap()
        val host = args["host"] as? String
            ?: return result.error("INVALID_PAIRING", "A pairing host is required.", null)
        val port = args["port"] as? Int
            ?: return result.error("INVALID_PAIRING", "A pairing port is required.", null)
        val code = args["code"] as? String
            ?: return result.error("INVALID_PAIRING", "A pairing code is required.", null)
        executor.execute {
            val pairingResult = try {
                adbTransport.pair(host, port, code)
            } catch (error: Exception) {
                mapOf("ok" to false, "message" to (error.message ?: "Wireless ADB pairing failed."))
            }
            mainHandler.post { result.success(pairingResult) }
        }
    }

    private fun openSession(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments<Map<String, Any?>>() ?: emptyMap()
        val transport = args["transport"] as? String
            ?: return result.error("INVALID_TRANSPORT", "An Android transport is required.", null)
        val mode = TransportMode.fromWire(transport)
        if (mode == null && transport != "wireless" && transport != "otg") {
            result.error("INVALID_TRANSPORT", "Unsupported Android transport.", null)
            return
        }
        if (mode == TransportMode.SHIZUKU && !hasShizukuPermission()) {
            requestShizukuPermission(result)
            return
        }
        val sessionId = UUID.randomUUID().toString()
        executor.execute {
            try {
                val session = when (transport) {
                    "wireless" -> adbTransport.openWireless(
                        sessionId,
                        args["serial"] as? String
                            ?: throw IllegalArgumentException("A wireless ADB address is required."),
                        args["workingDir"] as? String,
                    )
                    "otg" -> adbTransport.openOtg(
                        sessionId,
                        args["serial"] as? String
                            ?: throw IllegalArgumentException("A USB ADB device is required."),
                        args["workingDir"] as? String,
                    )
                    else -> backend.open(
                        sessionId = sessionId,
                        mode = mode ?: throw IllegalArgumentException("Unsupported Android transport."),
                        workingDir = args["workingDir"] as? String,
                    )
                }
                sessions[sessionId] = session
                mainHandler.post { result.success(sessionId) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("SHELL_START_FAILED", error.message ?: "Unable to start shell.", null)
                }
            }
        }
    }

    private fun writeStdin(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments<Map<String, Any?>>() ?: emptyMap()
        val sessionId = args["sessionId"] as? String
        val data = args["data"] as? String
        val session = sessionId?.let(sessions::get)
        if (session == null || data == null) {
            result.error("SESSION_NOT_FOUND", "Shell session is no longer available.", null)
            return
        }
        executor.execute {
            try {
                session.write(data)
                mainHandler.post { result.success(null) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("SHELL_WRITE_FAILED", error.message ?: "Unable to write to shell.", null)
                }
            }
        }
    }

    private fun closeSession(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = call.argument<String>("sessionId")
        val session = sessionId?.let(sessions::remove)
        if (session == null) {
            result.success(null)
            return
        }
        executor.execute {
            session.close()
            mainHandler.post { result.success(null) }
        }
    }

    private fun execOnce(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments<Map<String, Any?>>() ?: emptyMap()
        val mode = TransportMode.fromWire(args["transport"] as? String)
            ?: return result.error("INVALID_TRANSPORT", "Unsupported Android transport.", null)
        if (mode == TransportMode.SHIZUKU && !hasShizukuPermission()) {
            requestShizukuPermission(result)
            return
        }
        val command = args["command"] as? String
            ?: return result.error("INVALID_COMMAND", "A command is required.", null)
        executor.execute {
            try {
                val exitCode = backend.execOnce(
                    mode = mode,
                    command = command,
                    workingDir = args["workingDir"] as? String,
                )
                mainHandler.post { result.success(exitCode) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("COMMAND_FAILED", error.message ?: "Command failed.", null)
                }
            }
        }
    }

    private fun requestShizukuPermission(result: MethodChannel.Result) {
        if (!Shizuku.pingBinder()) {
            result.error(
                "SHIZUKU_UNAVAILABLE",
                "Start the Shizuku service before selecting the Shizuku transport.",
                null,
            )
            return
        }
        if (hasShizukuPermission()) {
            result.success(true)
            return
        }
        Shizuku.requestPermission(SHIZUKU_REQUEST_CODE)
        result.error(
            "SHIZUKU_PERMISSION_REQUIRED",
            "Grant Shizuku permission, then connect again.",
            null,
        )
    }

    private fun hasShizukuPermission(): Boolean =
        Shizuku.pingBinder() && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun emit(event: WireEvent) {
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "sessionId" to event.sessionId,
                    "stream" to event.stream,
                    "data" to event.data,
                    "exitCode" to event.exitCode,
                ),
            )
        }
    }

    override fun onDestroy() {
        pendingDocumentResult?.error(
            "ACTIVITY_DESTROYED",
            "The document picker was interrupted because the activity was closed.",
            null,
        )
        pendingDocumentResult = null
        sessions.values.forEach(ShellSession::close)
        sessions.clear()
        executor.shutdownNow()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "adb_helper/android"
        private const val EVENT_CHANNEL = "adb_helper/android/events"
        private const val SHIZUKU_REQUEST_CODE = 2307
        private const val DOCUMENT_REQUEST_CODE = 2308
    }
}
