package com.example.adb_helper

import android.content.pm.PackageManager
import android.graphics.SurfaceTexture
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.view.Surface
import android.os.Looper
import android.os.Build
import android.provider.Settings
import io.github.muntashirakon.adb.AdbAuthenticationFailedException
import io.github.muntashirakon.adb.AdbPairingRequiredException
import com.example.adb_helper.gateway.AndroidShellBackend
import com.example.adb_helper.gateway.AndroidAdbTransport
import com.example.adb_helper.gateway.ShellEventSink
import com.example.adb_helper.gateway.ShellSession
import com.example.adb_helper.gateway.TransportMode
import com.example.adb_helper.gateway.WireEvent
import rikka.shizuku.Shizuku
import com.topjohnwu.superuser.Shell
import io.flutter.embedding.android.FlutterActivity
import io.flutter.view.TextureRegistry
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
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
    private val mirrors = ConcurrentHashMap<String, MirrorHandle>()
    private var textureRegistry: TextureRegistry? = null
    @Volatile private var eventSink: EventChannel.EventSink? = null
    private var pendingDocumentResult: MethodChannel.Result? = null
    private var pendingFileAccessResult: MethodChannel.Result? = null
    private var pendingShizukuPermissionCallback: ((Boolean) -> Unit)? = null
    private val shizukuPermissionListener =
        Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
            if (requestCode == SHIZUKU_REQUEST_CODE) {
                val callback = pendingShizukuPermissionCallback
                pendingShizukuPermissionCallback = null
                mainHandler.post {
                    callback?.invoke(grantResult == PackageManager.PERMISSION_GRANTED)
                }
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(this)
        textureRegistry = flutterEngine.renderer
        Shizuku.addRequestPermissionResultListener(shizukuPermissionListener)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "discover" -> discover(result)
            "scanLocalNetwork" -> scanLocalNetwork(result)
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
                if (transport == "local") {
                    adbTransport.listLocalApplications()
                } else {
                    adbTransport.listApplications(transport, serial)
                        .map(adbTransport::addHostApplicationMetadata)
                }
            }
            "deviceInformation" -> deviceInformation(call, result)
            "listHostApplications" -> executor.execute {
                try {
                    val apps = adbTransport.listLocalApplications()
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
                val path = args.requiredString("path")
                if (transport == "local") listLocalShell(path)
                else adbTransport.listFiles(transport, serial, path)
            }
            "pushFile" -> withAdbArgs(call, result) { transport, serial, args ->
                val uri = args.requiredString("uri")
                val path = args.requiredString("path")
                if (transport == "local") pushLocalShell(uri, path)
                else adbTransport.pushFile(transport, serial, uri, path)
            }
            "pullFile" -> withAdbArgs(call, result) { transport, serial, args ->
                val path = args.requiredString("path")
                val uri = args.requiredString("uri")
                if (transport == "local") pullLocalShell(path, uri)
                else adbTransport.pullFile(transport, serial, path, uri)
            }
            "deleteFile" -> withAdbArgs(call, result) { transport, serial, args ->
                val path = args.requiredString("path")
                if (transport == "local") deleteLocalShell(path)
                else adbTransport.deleteFile(transport, serial, path)
            }
            "createDirectory" -> withAdbArgs(call, result) { transport, serial, args ->
                val path = args.requiredString("path")
                if (transport == "local") createLocalDirectoryShell(path)
                else adbTransport.createDirectory(transport, serial, path)
            }
            "renameFile" -> withAdbArgs(call, result) { transport, serial, args ->
                val from = args.requiredString("from")
                val to = args.requiredString("to")
                if (transport == "local") renameLocalShell(from, to)
                else adbTransport.renameFile(transport, serial, from, to)
            }
            "startMirror" -> startMirror(call, result)
            "stopMirror" -> stopMirror(call, result)
            "statFile" -> withAdbArgs(call, result) { transport, serial, args ->
                val path = args.requiredString("path")
                if (transport == "local") statLocalShell(path)
                else adbTransport.statFile(transport, serial, path)
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
            } catch (error: AdbAuthenticationFailedException) {
                mainHandler.post {
                    result.error(
                        "ADB_AUTHORIZATION_REQUIRED",
                        "Approve USB debugging / wireless debugging authorization on the target device, then retry.",
                        null,
                    )
                }
            } catch (error: AdbPairingRequiredException) {
                mainHandler.post {
                    result.error(
                        "ADB_PAIRING_REQUIRED",
                        "Use Pair over Wi-Fi on the target device, then pair this app before retrying.",
                        null,
                    )
                }
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
                    ?: if (transport == "local") "local"
                    else throw IllegalArgumentException("An ADB device is required.")
                val value = operation(transport, serial, args)
                mainHandler.post { result.success(if (value == Unit) null else value) }
            } catch (error: AdbAuthenticationFailedException) {
                mainHandler.post {
                    result.error(
                        "ADB_AUTHORIZATION_REQUIRED",
                        "Approve USB debugging / wireless debugging authorization on the target device, then retry.",
                        null,
                    )
                }
            } catch (error: AdbPairingRequiredException) {
                mainHandler.post {
                    result.error(
                        "ADB_PAIRING_REQUIRED",
                        "Use Pair over Wi-Fi on the target device, then pair this app before retrying.",
                        null,
                    )
                }
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

    private fun startMirror(call: MethodCall, result: MethodChannel.Result) {
        val registry = textureRegistry
            ?: return result.error("TEXTURE_UNAVAILABLE", "Flutter texture registry is unavailable.", null)
        val args = call.arguments<Map<String, Any?>>() ?: emptyMap()
        val transport = args["transport"] as? String
            ?: return result.error("INVALID_TRANSPORT", "An ADB transport is required.", null)
        val serial = args["serial"] as? String
            ?: return result.error("INVALID_SERIAL", "An ADB device is required.", null)
        if (transport != "wireless" && transport != "otg") {
            result.error("UNSUPPORTED_TRANSPORT", "Scrcpy requires a wireless or USB ADB device.", null)
            return
        }

        val textureEntry = registry.createSurfaceTexture()
        val surfaceTexture = textureEntry.surfaceTexture()
        surfaceTexture.setDefaultBufferSize(1080, 1920)
        val surface = Surface(surfaceTexture)
        val mirrorId = UUID.randomUUID().toString()

        executor.execute {
            try {
                val serverBytes = assets.open("scrcpy-server").use { it.readBytes() }
                val session = adbTransport.startScrcpy(transport, serial, serverBytes, surface)
                if (!session.awaitSize(5_000)) {
                    session.stop()
                    throw IllegalStateException("The scrcpy video stream did not provide a frame size.")
                }
                surfaceTexture.setDefaultBufferSize(
                    session.width.coerceAtLeast(1),
                    session.height.coerceAtLeast(1),
                )
                mirrors[mirrorId] = MirrorHandle(session, textureEntry, surface)
                mainHandler.post {
                    result.success(
                        mapOf(
                            "mirrorId" to mirrorId,
                            "textureId" to textureEntry.id(),
                            "width" to session.width,
                            "height" to session.height,
                        ),
                    )
                }
            } catch (error: Exception) {
                mainHandler.post {
                    textureEntry.release()
                    surface.release()
                    result.error(
                        "MIRROR_START_FAILED",
                        error.message ?: "Unable to start scrcpy mirroring.",
                        null,
                    )
                }
            }
        }
    }

    private fun stopMirror(call: MethodCall, result: MethodChannel.Result) {
        val mirrorId = call.argument<String>("mirrorId")
            ?: return result.error("INVALID_MIRROR", "A mirror id is required.", null)
        val handle = mirrors.remove(mirrorId)
            ?: return result.success(null)

        executor.execute {
            try {
                handle.session.stop()
            } finally {
                mainHandler.post {
                    handle.surface.release()
                    handle.textureEntry.release()
                    result.success(null)
                }
            }
        }
    }

    private data class MirrorHandle(
        val session: com.example.adb_helper.gateway.ScrcpyMirrorSession,
        val textureEntry: TextureRegistry.SurfaceTextureEntry,
        val surface: Surface,
    )
    private fun localFileMode(): TransportMode = when {
        Shizuku.pingBinder() && hasShizukuPermission() -> TransportMode.SHIZUKU
        Shell.getShell().isRoot -> TransportMode.ROOT
        else -> throw IOException(
            "Local privileged file access requires Shizuku or root. " +
                "The app will not request storage-manager permission.",
        )
    }

    private fun runLocalCommand(command: String, input: ByteArray? = null): ByteArray {
        val captured = backend.runCaptured(localFileMode(), command, null, input)
        if (captured.exitCode != 0) {
            throw IOException(
                String(captured.output, Charsets.UTF_8).trim()
                    .ifBlank { "Local shell command failed with exit code ${captured.exitCode}." },
            )
        }
        return captured.output
    }

    private fun listLocalShell(path: String): List<Map<String, Any>> {
        val output = String(
            runLocalCommand("ls -la -n ${backend.shellQuote(path)}"),
            Charsets.UTF_8,
        )
        val regex = Regex("""^(\S+)\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})\s+(.+)$""")
        return output.lineSequence()
            .mapNotNull { line ->
                val match = regex.find(line) ?: return@mapNotNull null
                val name = match.groupValues[5]
                if (name == "." || name == "..") return@mapNotNull null
                mapOf(
                    "name" to name,
                    "path" to (if (path == "/") "/$name" else "$path/$name"),
                    "isDirectory" to match.groupValues[1].startsWith("d"),
                    "size" to (match.groupValues[2].toIntOrNull() ?: 0),
                    "mode" to match.groupValues[1],
                    "mtime" to "${match.groupValues[3]} ${match.groupValues[4]}",
                )
            }
            .toList()
    }

    private fun statLocalShell(path: String): Map<String, Any> {
        val output = String(
            runLocalCommand("stat -c '%s|%A|%y' ${backend.shellQuote(path)}"),
            Charsets.UTF_8,
        ).trim()
        val parts = output.split("|", limit = 3)
        if (parts.size != 3) throw IOException("Unable to read file metadata: $path")
        return mapOf(
            "size" to (parts[0].toIntOrNull() ?: 0),
            "mode" to parts[1],
            "mtime" to parts[2],
        )
    }

    private fun readDocumentBytes(uri: String): ByteArray =
        contentResolver.openInputStream(Uri.parse(uri))?.use { it.readBytes() }
            ?: throw IOException("Unable to read the selected document.")

    private fun writeDocumentBytes(uri: String, bytes: ByteArray) {
        val output = contentResolver.openOutputStream(Uri.parse(uri), "wt")
            ?: throw IOException("Unable to write to the selected document.")
        output.use { it.write(bytes) }
    }

    private fun pushLocalShell(uri: String, path: String) {
        val input = readDocumentBytes(uri)
        runLocalCommand("cat > ${backend.shellQuote(path)}", input)
    }

    private fun pullLocalShell(path: String, uri: String) {
        val bytes = runLocalCommand("cat ${backend.shellQuote(path)}")
        writeDocumentBytes(uri, bytes)
    }

    private fun deleteLocalShell(path: String) {
        runLocalCommand("rm -rf ${backend.shellQuote(path)}")
    }

    private fun createLocalDirectoryShell(path: String) {
        runLocalCommand("mkdir -p ${backend.shellQuote(path)}")
    }

    private fun renameLocalShell(from: String, to: String) {
        runLocalCommand(
            "mv ${backend.shellQuote(from)} ${backend.shellQuote(to)}",
        )
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
        when (requestCode) {
            DOCUMENT_REQUEST_CODE -> {
                val pending = pendingDocumentResult ?: return
                pendingDocumentResult = null
                val uri: Uri? = if (resultCode == RESULT_OK) data?.data else null
                pending.success(uri?.toString())
            }
            FILE_ACCESS_REQUEST_CODE -> {
                val pending = pendingFileAccessResult ?: return
                pendingFileAccessResult = null
                pending.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.R ||
                        Environment.isExternalStorageManager(),
                )
            }
        }
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

    private fun scanLocalNetwork(result: MethodChannel.Result) {
        executor.execute {
            try {
                val devices = adbTransport.scanLocalNetwork()
                mainHandler.post { result.success(devices) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error(
                        "NETWORK_SCAN_FAILED",
                        error.message ?: "Unable to scan the local network.",
                        null,
                    )
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
            requestShizukuPermission { granted ->
                if (granted) {
                    openSession(call, result)
                } else {
                    result.error(
                        "SHIZUKU_PERMISSION_DENIED",
                        "Shizuku permission was not granted.",
                        null,
                    )
                }
            }
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
            requestShizukuPermission { granted ->
                if (granted) {
                    execOnce(call, result)
                } else {
                    result.error(
                        "SHIZUKU_PERMISSION_DENIED",
                        "Shizuku permission was not granted.",
                        null,
                    )
                }
            }
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
        requestShizukuPermission { granted -> result.success(granted) }
    }

    private fun requestShizukuPermission(onResult: (Boolean) -> Unit) {
        if (!Shizuku.pingBinder()) {
            mainHandler.post { onResult(false) }
            return
        }
        if (hasShizukuPermission()) {
            mainHandler.post { onResult(true) }
            return
        }
        if (pendingShizukuPermissionCallback != null) {
            mainHandler.post { onResult(false) }
            return
        }
        pendingShizukuPermissionCallback = onResult
        Shizuku.requestPermission(SHIZUKU_REQUEST_CODE)
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
        Shizuku.removeRequestPermissionResultListener(shizukuPermissionListener)
        pendingShizukuPermissionCallback?.invoke(false)
        pendingShizukuPermissionCallback = null
        pendingDocumentResult?.error(
            "ACTIVITY_DESTROYED",
            "The document picker was interrupted because the activity was closed.",
            null,
        )
        pendingDocumentResult = null
        pendingFileAccessResult?.error(
            "ACTIVITY_DESTROYED",
            "The storage access request was interrupted because the activity was closed.",
            null,
        )
        pendingFileAccessResult = null
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
        private const val FILE_ACCESS_REQUEST_CODE = 2309
    }
}
