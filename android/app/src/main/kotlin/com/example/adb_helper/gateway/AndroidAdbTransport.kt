package com.example.adb_helper.gateway

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.net.Uri
import android.view.Surface
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import io.github.muntashirakon.adb.AdbConnection as WirelessAdbConnection
import io.github.muntashirakon.adb.PairingConnectionCtx
import java.io.File
import java.io.ByteArrayInputStream
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.IOException
import java.io.InputStream
import java.io.InputStreamReader
import java.io.OutputStream
import java.net.InetAddress
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.nio.charset.StandardCharsets
import java.security.KeyPairGenerator
import java.security.Security
import java.security.cert.Certificate
import java.security.cert.CertificateFactory
import java.util.Date
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicBoolean
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder

class AndroidAdbTransport(
    private val context: Context,
    private val eventSink: ShellEventSink,
) {
    private data class AdbConnectionHandle(
        val connection: WirelessAdbConnection,
        val close: () -> Unit,
    )

    private val usbManager = context.getSystemService(UsbManager::class.java)
    private val nsdManager = context.getSystemService(NsdManager::class.java)


    fun discover(): List<Map<String, String>> {
        val result = mutableListOf(
            mapOf("id" to "local", "label" to "This device", "transport" to "local"),
        )
        result += usbManager.deviceList.values.mapNotNull { device ->
            if (findAdbInterface(device) == null) return@mapNotNull null
            mapOf(
                "id" to device.deviceName,
                "label" to (device.productName ?: device.deviceName),
                "transport" to "otg",
            )
        }
        result += discoverWirelessDevices()
        return result
    }

    fun scanLocalNetwork(): List<Map<String, String>> {
        val mdnsExecutor = Executors.newSingleThreadExecutor()
        val mdnsScan = mdnsExecutor.submit<List<WirelessEndpoint>> {
            findWirelessEndpoints(5, TimeUnit.SECONDS)
        }
        val active = try {
            (scanLegacyAdbEndpoints() + mdnsScan.get(10, TimeUnit.SECONDS))
                .distinctBy { it.serial }
        } catch (error: java.util.concurrent.ExecutionException) {
            mdnsScan.cancel(true)
            val cause = error.cause
            if (cause is Exception) throw cause
            throw error
        } catch (error: Exception) {
            mdnsScan.cancel(true)
            throw error
        } finally {
            mdnsExecutor.shutdownNow()
        }
        active.forEach(::saveWirelessEndpoint)
        return active.map { endpoint ->
            mapOf(
                "id" to endpoint.serial,
                "label" to endpoint.label,
                "transport" to "wireless",
            )
        }
    }

    fun pair(host: String, port: Int, code: String): Map<String, Any?> {
        AdbProtocolSpec.validatePairing(host, port, code)
        val keyMaterial = wirelessKeyMaterial()
        PairingConnectionCtx(
            host,
            port,
            code.toByteArray(StandardCharsets.UTF_8),
            keyMaterial.privateKey,
            keyMaterial.certificate,
            "adb_helper",
        ).use { it.start() }
        val endpoint = findWirelessEndpoint(host, 8, TimeUnit.SECONDS)
        if (endpoint == null) {
            return mapOf(
                "ok" to true,
                "message" to "Pairing succeeded. Keep Wireless debugging enabled and refresh the device list.",
            )
        }
        saveWirelessEndpoint(endpoint)
        return mapOf(
            "ok" to true,
            "message" to "Wireless debugging device paired.",
            "serial" to endpoint.serial,
        )
    }

    fun connectWireless(host: String, port: Int): Map<String, String> {
        AdbProtocolSpec.validateEndpoint(host, port)
        val address = InetAddress.getByName(host).hostAddress
            ?: throw IOException("Unable to resolve the wireless device address.")
        val key = wirelessKeyMaterial()
        val connection = WirelessAdbConnection.Builder()
            .setHost(address)
            .setPort(port)
            .setPrivateKey(key.privateKey)
            .setCertificate(key.certificate)
            .setDeviceName("adb_helper")
            .build()
        if (!connection.connect(30, TimeUnit.SECONDS, false)) {
            connection.close()
            throw IOException("ADB connection failed. Pair the device first or verify its IP and port.")
        }
        connection.close()
        val endpoint = WirelessEndpoint(address, port, address)
        saveWirelessEndpoint(endpoint)
        return mapOf(
            "id" to endpoint.serial,
            "label" to endpoint.label,
        )
    }

    fun listApplications(transport: String, serial: String): List<Map<String, Any?>> =
        withAdbConnection(transport, serial) { connection ->
            val all = shellChecked(connection, "pm list packages --show-versioncode")
            val system = shellChecked(connection, "pm list packages -s")
                .lineSequence()
                .mapNotNull { it.removePrefix("package:").takeIf(String::isNotBlank) }
                .toSet()
            val disabled = shellChecked(connection, "pm list packages -d")
                .lineSequence()
                .mapNotNull { it.removePrefix("package:").takeIf(String::isNotBlank) }
                .toSet()
            all.lineSequence()
                .mapNotNull { line ->
                    val packageName = line.substringAfter("package:", "").substringBefore(' ')
                    if (packageName.isBlank()) return@mapNotNull null
                    val versionCode = Regex("""versionCode:(\d+)""")
                        .find(line)?.groupValues?.get(1)?.toLongOrNull()
                    mapOf(
                        "packageName" to packageName,
                        "versionCode" to versionCode,
                        "systemApp" to (packageName in system),
                        "enabled" to (packageName !in disabled),
                    )
                }
                .distinctBy { it["packageName"] }
                .sortedBy { it["packageName"] as String }
                .toList()
        }

    fun listLocalApplications(): List<Map<String, Any?>> =
        installedPackages().mapNotNull { packageInfo ->
            val applicationInfo = packageInfo.applicationInfo ?: return@mapNotNull null
            hostApplicationMetadata(packageInfo, applicationInfo)
        }.sortedBy { it["label"] as String }

    fun addHostApplicationMetadata(
        remote: Map<String, Any?>,
    ): Map<String, Any?> {
        val packageName = remote["packageName"] as? String ?: return remote
        val applicationInfo = try {
            context.packageManager.getApplicationInfo(packageName, 0)
        } catch (_: android.content.pm.PackageManager.NameNotFoundException) {
            return remote
        }
        val metadata = hostApplicationMetadata(null, applicationInfo)
        return remote + metadata.filterKeys { it == "label" || it == "icon" }
    }

    @Suppress("DEPRECATION")
    private fun installedPackages(): List<PackageInfo> =
        context.packageManager.getInstalledPackages(
            android.content.pm.PackageManager.GET_META_DATA,
        )

    private fun hostApplicationMetadata(
        packageInfo: PackageInfo?,
        applicationInfo: ApplicationInfo,
    ): Map<String, Any?> {
        val drawable = context.packageManager.getApplicationIcon(applicationInfo)
        val width = drawable.intrinsicWidth.takeIf { it > 0 }?.coerceAtMost(96) ?: 64
        val height = drawable.intrinsicHeight.takeIf { it > 0 }?.coerceAtMost(96) ?: 64
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, width, height)
        drawable.draw(canvas)
        val output = java.io.ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
        bitmap.recycle()
        val metadata = linkedMapOf<String, Any?>(
            "packageName" to applicationInfo.packageName,
            "label" to context.packageManager.getApplicationLabel(applicationInfo).toString(),
            "icon" to output.toByteArray(),
            "systemApp" to (applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM != 0),
        )
        if (packageInfo != null) {
            metadata["versionName"] = packageInfo.versionName
            metadata["versionCode"] = packageInfo.longVersionCode
        }
        return metadata
    }

    fun deviceInformation(transport: String, serial: String): Map<String, String> =
        withAdbConnection(transport, serial) { connection ->
            val properties = shellChecked(connection, "getprop")
                .lineSequence()
                .mapNotNull { line ->
                    val match = Regex("""^\[([^]]+)]: \[(.*)]$""").find(line)
                        ?: return@mapNotNull null
                    match.groupValues[1] to match.groupValues[2]
                }
                .toMap()
            val info = linkedMapOf(
                "Manufacturer" to properties["ro.product.manufacturer"],
                "Brand" to properties["ro.product.brand"],
                "Model" to properties["ro.product.model"],
                "Device" to properties["ro.product.device"],
                "Android version" to properties["ro.build.version.release"],
                "API level" to properties["ro.build.version.sdk"],
                "Security patch" to properties["ro.build.version.security_patch"],
                "Build ID" to properties["ro.build.display.id"],
                "Build fingerprint" to properties["ro.build.fingerprint"],
                "Primary ABI" to properties["ro.product.cpu.abi"],
                "Serial number" to properties["ro.serialno"],
                "Screen resolution" to shellChecked(connection, "wm size"),
                "Screen density" to shellChecked(connection, "wm density"),
                "Memory" to shellChecked(connection, "cat /proc/meminfo | head -n 3"),
                "Data storage" to shellChecked(connection, "df -h /data"),
            )
            info.mapNotNull { (key, value) ->
                value?.trim()?.takeIf(String::isNotEmpty)?.let { key to it }
            }.toMap()
        }

    fun installApplication(transport: String, serial: String, documentUri: String) {
        val uri = Uri.parse(documentUri)
        val displayName = if (uri.scheme == "content") {
            context.contentResolver.query(
                uri,
                arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getString(0)
                } else {
                    null
                }
            }
        } else {
            uri.lastPathSegment
        }
        if (displayName?.endsWith(".aab", ignoreCase = true) == true) {
            throw IOException(
                "Android App Bundles require bundletool conversion; select an APK or convert the bundle to APKs first.",
            )
        }
        val temporaryPath = "/data/local/tmp/adb_helper_${UUID.randomUUID()}.apk"
        withAdbConnection(transport, serial) { connection ->
            context.contentResolver.openInputStream(uri)?.use { source ->
                pushStream(connection, source, temporaryPath)
            } ?: throw IOException("Unable to read the selected APK.")
            try {
                val output = shellChecked(
                    connection,
                    "pm install -r ${shellQuote(temporaryPath)}",
                )
                if (COMMAND_FAILURE.containsMatchIn(output)) {
                    throw IOException(output.trim())
                }
            } finally {
                shellChecked(connection, "rm -f ${shellQuote(temporaryPath)}")
            }
        }
    }

    fun installHostApplication(transport: String, serial: String, packageName: String) {
        if (!PACKAGE_NAME.matches(packageName)) {
            throw IllegalArgumentException("The application package name is invalid.")
        }
        val packageInfo = try {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(
                packageName,
                android.content.pm.PackageManager.GET_META_DATA,
            )
        } catch (error: android.content.pm.PackageManager.NameNotFoundException) {
            throw IOException("The application is no longer installed on this device.", error)
        }
        val applicationInfo = packageInfo.applicationInfo
            ?: throw IOException("Unable to locate the application's APK files.")
        val sourcePaths = listOfNotNull(applicationInfo.sourceDir) +
            (applicationInfo.splitSourceDirs?.toList() ?: emptyList())
        if (sourcePaths.isEmpty()) {
            throw IOException("No APK files were found for this application.")
        }
        val stagedPaths = sourcePaths.indices.map { index ->
            "/data/local/tmp/adb_helper_${UUID.randomUUID()}_$index.apk"
        }
        withAdbConnection(transport, serial) { connection ->
            try {
                sourcePaths.zip(stagedPaths).forEach { (sourcePath, targetPath) ->
                    File(sourcePath).inputStream().use { source ->
                        pushStream(connection, source, targetPath)
                    }
                }
                val output = shellChecked(
                    connection,
                    "pm install-multiple -r ${stagedPaths.joinToString(" ") { shellQuote(it) }}",
                )
                if (COMMAND_FAILURE.containsMatchIn(output)) {
                    throw IOException(output.trim())
                }
            } finally {
                shellChecked(
                    connection,
                    "rm -f ${stagedPaths.joinToString(" ") { shellQuote(it) }}",
                )
            }
        }
    }

    fun uninstallApplication(transport: String, serial: String, packageName: String) =
        runPackageCommand(transport, serial, packageName) {
            "pm uninstall --user 0 ${shellQuote(it)}"
        }

    fun launchApplication(transport: String, serial: String, packageName: String) =
        runPackageCommand(transport, serial, packageName) {
            "monkey -p ${shellQuote(it)} 1"
        }

    fun forceStopApplication(transport: String, serial: String, packageName: String) =
        runPackageCommand(transport, serial, packageName) {
            "am force-stop ${shellQuote(it)}"
        }

    fun clearApplicationData(transport: String, serial: String, packageName: String) =
        runPackageCommand(transport, serial, packageName) {
            "pm clear ${shellQuote(it)}"
        }

    fun setApplicationEnabled(
        transport: String,
        serial: String,
        packageName: String,
        enabled: Boolean,
    ) = runPackageCommand(transport, serial, packageName) {
        if (enabled) "pm enable ${shellQuote(it)}"
        else "pm disable-user --user 0 ${shellQuote(it)}"
    }

    fun openApplicationSettings(transport: String, serial: String, packageName: String) =
        runPackageCommand(transport, serial, packageName) {
            "am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d ${shellQuote("package:$it")}"
        }

    fun listFiles(transport: String, serial: String, path: String): List<Map<String, Any>> =
        withAdbConnection(transport, serial) { connection ->
            val output = shellChecked(
                connection,
                "ls -la -n ${shellQuote(validateRemotePath(path))}",
            )
            output.lineSequence().mapNotNull { line ->
                val match = FILE_LIST_LINE.matchEntire(line) ?: return@mapNotNull null
                val name = match.groupValues[5]
                if (name == "." || name == "..") return@mapNotNull null
                val fullPath = joinRemotePath(path, name)
                mapOf(
                    "name" to name,
                    "path" to fullPath,
                    "isDirectory" to match.groupValues[1].startsWith("d"),
                    "size" to (match.groupValues[2].toLongOrNull() ?: 0L),
                    "mode" to match.groupValues[1],
                    "mtime" to "${match.groupValues[3]} ${match.groupValues[4]}",
                )
            }.toList()
        }

    fun statFile(transport: String, serial: String, path: String): Map<String, Any> {
        val validated = validateRemotePath(path)
        val parent = validated.substringBeforeLast('/', "").ifBlank { "/" }
        val entry = listFiles(transport, serial, parent).firstOrNull {
            it["path"] == validated
        } ?: throw IOException("File not found: $validated")
        return mapOf(
            "size" to entry["size"]!!,
            "mode" to entry["mode"]!!,
            "mtime" to entry["mtime"]!!,
        )
    }

    fun listLocalFiles(path: String): List<Map<String, Any>> {
        val directory = File(validateRemotePath(path)).canonicalFile
        if (!directory.exists()) throw IOException("Directory not found: $path")
        if (!directory.isDirectory) throw IOException("Not a directory: $path")
        val children = directory.listFiles()
            ?: throw IOException("Unable to read directory: $path")
        return children.sortedWith(compareBy<File>({ !it.isDirectory }, { it.name.lowercase() }))
            .map { child ->
                mapOf(
                    "name" to child.name,
                    "path" to child.absolutePath,
                    "isDirectory" to child.isDirectory,
                    "size" to if (child.isFile) child.length() else 0L,
                    "mode" to localFileMode(child),
                    "mtime" to SimpleDateFormat(
                        "yyyy-MM-dd HH:mm",
                        Locale.getDefault(),
                    ).format(Date(child.lastModified())),
                )
            }
    }

    fun statLocalFile(path: String): Map<String, Any> {
        val file = File(validateRemotePath(path)).canonicalFile
        if (!file.exists()) throw IOException("File not found: $path")
        return mapOf(
            "size" to if (file.isFile) file.length() else 0L,
            "mode" to localFileMode(file),
            "mtime" to SimpleDateFormat(
                "yyyy-MM-dd HH:mm",
                Locale.getDefault(),
            ).format(Date(file.lastModified())),
        )
    }

    fun pushLocalFile(documentUri: String, path: String) {
        val destination = File(validateRemotePath(path)).canonicalFile
        context.contentResolver.openInputStream(Uri.parse(documentUri))?.use { input ->
            destination.outputStream().use { output -> input.copyTo(output) }
        } ?: throw IOException("Unable to read the selected document.")
    }

    fun pullLocalFile(path: String, documentUri: String) {
        val source = File(validateRemotePath(path)).canonicalFile
        if (!source.isFile) throw IOException("Not a file: $path")
        val output = context.contentResolver.openOutputStream(Uri.parse(documentUri), "wt")
            ?: throw IOException("Unable to write to the selected document.")
        source.inputStream().use { input -> output.use { input.copyTo(it) } }
    }

    fun deleteLocalFile(path: String) {
        val file = File(validateRemotePath(path)).canonicalFile
        val deleted = if (file.isDirectory) file.deleteRecursively() else file.delete()
        if (!deleted) throw IOException("Unable to delete: $path")
    }

    fun createLocalDirectory(path: String) {
        val directory = File(validateRemotePath(path)).canonicalFile
        if (!directory.mkdirs() && !directory.isDirectory) {
            throw IOException("Unable to create directory: $path")
        }
    }

    fun renameLocalFile(from: String, to: String) {
        val source = File(validateRemotePath(from)).canonicalFile
        val destination = File(validateRemotePath(to)).canonicalFile
        if (!source.renameTo(destination)) {
            throw IOException("Unable to rename $from to $to.")
        }
    }

    private fun localFileMode(file: File): String = buildString {
        append(if (file.isDirectory) 'd' else '-')
        append(if (file.canRead()) 'r' else '-')
        append(if (file.canWrite()) 'w' else '-')
        append(if (file.canExecute()) 'x' else '-')
    }

    fun pushFile(transport: String, serial: String, documentUri: String, path: String) {
        context.contentResolver.openInputStream(Uri.parse(documentUri))?.use { input ->
            withAdbConnection(transport, serial) { connection ->
                pushStream(connection, input, validateRemotePath(path))
            }
        } ?: throw IOException("Unable to read the selected document.")
    }

    fun pullFile(transport: String, serial: String, path: String, documentUri: String) {
        val output = context.contentResolver.openOutputStream(Uri.parse(documentUri), "wt")
            ?: throw IOException("Unable to write to the selected document.")
        output.use { destination ->
            withAdbConnection(transport, serial) { connection ->
                pullStream(connection, validateRemotePath(path), destination)
            }
        }
    }

    fun deleteFile(transport: String, serial: String, path: String) =
        runFileCommand(transport, serial, path) { "rm -rf -- ${shellQuote(it)}" }

    fun createDirectory(transport: String, serial: String, path: String) =
        runFileCommand(transport, serial, path) { "mkdir -p -- ${shellQuote(it)}" }

    fun renameFile(transport: String, serial: String, from: String, to: String) {
        val source = validateRemotePath(from)
        val destination = validateRemotePath(to)
        withAdbConnection(transport, serial) { connection ->
            shellChecked(connection, "mv -- ${shellQuote(source)} ${shellQuote(destination)}")
        }
    }

    private fun runPackageCommand(
        transport: String,
        serial: String,
        packageName: String,
        command: (String) -> String,
    ) {
        require(PACKAGE_NAME.matches(packageName)) { "Invalid Android package name." }
        withAdbConnection(transport, serial) { connection ->
            val output = shellChecked(connection, command(packageName))
            if (COMMAND_FAILURE.containsMatchIn(output)) {
                throw IOException(output.trim())
            }
        }
    }

    private fun runFileCommand(
        transport: String,
        serial: String,
        path: String,
        command: (String) -> String,
    ) {
        withAdbConnection(transport, serial) { connection ->
            shellChecked(connection, command(validateRemotePath(path)))
        }
    }

    private fun openAdbConnection(
        transport: String,
        serial: String,
    ): AdbConnectionHandle {
        val handle = when (transport) {
            "wireless" -> {
                val endpoint = AdbProtocolSpec.parseWirelessEndpoint(serial)
                val key = wirelessKeyMaterial()
                val connection = WirelessAdbConnection.Builder()
                    .setHost(endpoint.first)
                    .setPort(endpoint.second)
                    .setPrivateKey(key.privateKey)
                    .setCertificate(key.certificate)
                    .setDeviceName("adb_helper")
                    .build()
                if (!connection.connect(30, TimeUnit.SECONDS, false)) {
                    connection.close()
                    throw IOException("Wireless ADB authorization timed out.")
                }
                AdbConnectionHandle(connection) { connection.close() }
            }
            "otg" -> openOtgConnection(serial)
            else -> throw IllegalArgumentException(
                "Scrcpy mirroring requires a wireless or USB ADB device.",
            )
        }
        return handle
    }

    private fun <T> withAdbConnection(
        transport: String,
        serial: String,
        operation: (WirelessAdbConnection) -> T,
    ): T {
        val handle = openAdbConnection(transport, serial)
        return try {
            operation(handle.connection)
        } finally {
            handle.close()
        }
    }

    fun startScrcpy(
        transport: String,
        serial: String,
        serverBytes: ByteArray,
        surface: Surface,
    ): ScrcpyMirrorSession {
        val handle = openAdbConnection(transport, serial)
        var started = false
        try {
            pushStream(
                handle.connection,
                ByteArrayInputStream(serverBytes),
                SCRCPY_REMOTE_PATH,
            )
            shellChecked(
                handle.connection,
                "pkill -f com.genymobile.scrcpy.Server >/dev/null 2>&1 || true",
            )
            val serverShell = handle.connection.open(
                "shell:CLASSPATH=$SCRCPY_REMOTE_PATH app_process / " +
                    "com.genymobile.scrcpy.Server 4.1 audio=false control=false " +
                    "tunnel_forward=true",
            )
            Thread.sleep(250)
            val videoStream = handle.connection.open(SCRCPY_LOCAL_DESTINATION)
            val session = ScrcpyMirrorSession(
                videoStream.openInputStream(),
                surface,
            ) {
                try {
                    videoStream.close()
                } finally {
                    try {
                        serverShell.close()
                    } finally {
                        handle.close()
                    }
                }
            }
            session.start()
            started = true
            return session
        } finally {
            if (!started) handle.close()
        }
    }

    private fun openOtgConnection(deviceName: String): AdbConnectionHandle {
        val device = usbManager.deviceList.values.firstOrNull { it.deviceName == deviceName }
            ?: throw IOException("The USB ADB device is no longer connected.")
        val intf = findAdbInterface(device)
            ?: throw IOException("The USB device does not expose an ADB interface.")
        if (!requestUsbPermission(device)) {
            throw IOException("USB debugging permission was not granted.")
        }
        val usbConnection = usbManager.openDevice(device)
            ?: throw IOException("Unable to open the USB ADB device.")
        if (!usbConnection.claimInterface(intf, true)) {
            usbConnection.close()
            throw IOException("Unable to claim the USB ADB interface.")
        }
        val bulkIn: UsbEndpoint
        val bulkOut: UsbEndpoint
        try {
            bulkIn = findEndpoint(intf, UsbConstants.USB_DIR_IN)
            bulkOut = findEndpoint(intf, UsbConstants.USB_DIR_OUT)
        } catch (error: Exception) {
            usbConnection.releaseInterface(intf)
            usbConnection.close()
            throw error
        }
        val serverSocket = try {
            ServerSocket(0, 1, InetAddress.getLoopbackAddress())
        } catch (error: Exception) {
            usbConnection.releaseInterface(intf)
            usbConnection.close()
            throw error
        }
        Thread({
            try {
                val remote = serverSocket.accept()
                startUsbTunnel(remote, usbConnection, bulkIn, bulkOut)
            } catch (_: IOException) {
                serverSocket.close()
            }
        }, "adb-usb-operation").apply { isDaemon = true; start() }

        val connection = try {
            val key = wirelessKeyMaterial()
            WirelessAdbConnection.Builder()
                .setHost(InetAddress.getLoopbackAddress().hostAddress!!)
                .setPort(serverSocket.localPort)
                .setPrivateKey(key.privateKey)
                .setCertificate(key.certificate)
                .setDeviceName("adb_helper")
                .build()
                .also {
                    if (!it.connect(30, TimeUnit.SECONDS, false)) {
                        it.close()
                        throw IOException("USB ADB authorization timed out.")
                    }
                }
        } catch (error: Exception) {
            serverSocket.close()
            usbConnection.releaseInterface(intf)
            usbConnection.close()
            throw error
        }
        return AdbConnectionHandle(connection) {
            try {
                connection.close()
            } finally {
                serverSocket.close()
                usbConnection.releaseInterface(intf)
                usbConnection.close()
            }
        }
    }

    private fun shellChecked(connection: WirelessAdbConnection, command: String): String {
        val response = connection.open("shell:$command; echo __ADB_EXIT__\$?")
            .let { stream ->
                try {
                    InputStreamReader(stream.openInputStream(), StandardCharsets.UTF_8).readText()
                } finally {
                    stream.close()
                }
            }
        val marker = EXIT_CODE.find(response)
            ?: throw IOException(response.trim().ifBlank { "The ADB shell command returned no status." })
        val output = response.removeRange(marker.range).trim()
        val exitCode = marker.groupValues[1].toInt()
        if (exitCode != 0) {
            throw IOException(output.ifBlank { "ADB shell command failed with exit code $exitCode." })
        }
        return output
    }

    private fun pushStream(
        connection: WirelessAdbConnection,
        source: InputStream,
        path: String,
    ) {
        val stream = connection.open("sync:")
        try {
            val input = DataInputStream(BufferedInputStream(stream.openInputStream()))
            val output = BufferedOutputStream(stream.openOutputStream())
            writeSyncPacket(output, "SEND", "$path,0644".toByteArray(StandardCharsets.UTF_8))
            val buffer = ByteArray(SYNC_DATA_SIZE)
            while (true) {
                val length = source.read(buffer)
                if (length < 0) break
                writeSyncPacket(output, "DATA", buffer.copyOf(length))
            }
            writeAscii(output, "DONE")
            writeIntLe(output, (System.currentTimeMillis() / 1000L).toInt())
            output.flush()
            readSyncStatus(input)
        } finally {
            stream.close()
        }
    }

    private fun pullStream(
        connection: WirelessAdbConnection,
        path: String,
        destination: java.io.OutputStream,
    ) {
        val stream = connection.open("sync:")
        try {
            val input = DataInputStream(BufferedInputStream(stream.openInputStream()))
            val output = BufferedOutputStream(stream.openOutputStream())
            writeSyncPacket(output, "RECV", path.toByteArray(StandardCharsets.UTF_8))
            output.flush()
            while (true) {
                val id = ByteArray(4)
                input.readFully(id)
                val length = readIntLe(input)
                when (String(id, StandardCharsets.US_ASCII)) {
                    "DATA" -> {
                        if (length !in 0..SYNC_DATA_SIZE) {
                            throw IOException("Invalid ADB file data packet.")
                        }
                        val buffer = ByteArray(length)
                        input.readFully(buffer)
                        destination.write(buffer)
                    }
                    "DONE" -> {
                        if (length > 0) input.skipBytes(length)
                        return
                    }
                    "FAIL" -> {
                        if (length !in 0..MAX_SYNC_ERROR_SIZE) {
                            throw IOException("Invalid ADB file transfer error packet.")
                        }
                        val message = ByteArray(length)
                        input.readFully(message)
                        throw IOException(String(message, StandardCharsets.UTF_8))
                    }
                    else -> throw IOException("Unexpected ADB file transfer response.")
                }
            }
        } finally {
            stream.close()
        }
    }

    private fun readSyncStatus(input: DataInputStream) {
        val id = ByteArray(4)
        input.readFully(id)
        val length = readIntLe(input)
        when (String(id, StandardCharsets.US_ASCII)) {
            "OKAY" -> if (length > 0) input.skipBytes(length)
            "FAIL" -> {
                if (length !in 0..MAX_SYNC_ERROR_SIZE) {
                    throw IOException("Invalid ADB file transfer error packet.")
                }
                val message = ByteArray(length)
                input.readFully(message)
                throw IOException(String(message, StandardCharsets.UTF_8))
            }
            else -> throw IOException("Unexpected ADB file transfer response.")
        }
    }

    private fun writeSyncPacket(output: OutputStream, id: String, data: ByteArray) {
        writeAscii(output, id)
        writeIntLe(output, data.size)
        output.write(data)
    }

    private fun writeAscii(output: OutputStream, value: String) {
        output.write(value.toByteArray(StandardCharsets.US_ASCII))
    }

    private fun writeIntLe(output: OutputStream, value: Int) {
        output.write(value and 0xff)
        output.write(value ushr 8 and 0xff)
        output.write(value ushr 16 and 0xff)
        output.write(value ushr 24 and 0xff)
    }

    private fun readIntLe(input: DataInputStream): Int {
        val bytes = ByteArray(4)
        input.readFully(bytes)
        return (bytes[0].toInt() and 0xff) or
            ((bytes[1].toInt() and 0xff) shl 8) or
            ((bytes[2].toInt() and 0xff) shl 16) or
            ((bytes[3].toInt() and 0xff) shl 24)
    }

    private fun shellQuote(value: String): String {
        require('\u0000' !in value) { "A path or package name contains an invalid character." }
        return "'" + value.replace("'", "'\\''") + "'"
    }

    private fun validateRemotePath(path: String): String {
        require(path.startsWith("/") && path.isNotBlank()) {
            "The device path must be an absolute path."
        }
        require(path.none { it == '\u0000' || it == '\n' || it == '\r' }) {
            "The device path contains an invalid character."
        }
        return path
    }

    private fun joinRemotePath(parent: String, name: String): String =
        if (parent == "/") "/$name" else "${parent.trimEnd('/')}/$name"

    fun openWireless(sessionId: String, serial: String, workingDir: String?): ShellSession {
        val endpoint = AdbProtocolSpec.parseWirelessEndpoint(serial)
        val key = wirelessKeyMaterial()
        val connection = WirelessAdbConnection.Builder()
            .setHost(endpoint.first)
            .setPort(endpoint.second)
            .setPrivateKey(key.privateKey)
            .setCertificate(key.certificate)
            .setDeviceName("adb_helper")
            .build()
        if (!connection.connect(30, TimeUnit.SECONDS, false)) {
            connection.close()
            throw IOException("Wireless ADB authorization timed out.")
        }
        val stream = try {
            connection.open(AdbProtocolSpec.shellDestination())
        } catch (error: Exception) {
            connection.close()
            throw error
        }
        val input = stream.openInputStream()
        val output = stream.openOutputStream()
        try {
            sendWorkingDirectory(output, workingDir)
        } catch (error: Exception) {
            stream.close()
            connection.close()
            throw error
        }
        return createSession(
            sessionId,
            input,
            output,
        ) {
            try {
                stream.close()
            } finally {
                connection.close()
            }
        }
    }

    fun openOtg(sessionId: String, deviceName: String, workingDir: String?): ShellSession {
        val device = usbManager.deviceList.values.firstOrNull { it.deviceName == deviceName }
            ?: throw IOException("The USB ADB device is no longer connected.")
        val intf = findAdbInterface(device)
            ?: throw IOException("The USB device does not expose an ADB interface.")
        if (!requestUsbPermission(device)) {
            throw IOException("USB debugging permission was not granted.")
        }
        val usbConnection = usbManager.openDevice(device)
            ?: throw IOException("Unable to open the USB ADB device.")
        if (!usbConnection.claimInterface(intf, true)) {
            usbConnection.close()
            throw IOException("Unable to claim the USB ADB interface.")
        }
        val (bulkIn, bulkOut) = try {
            findEndpoint(intf, UsbConstants.USB_DIR_IN) to
                findEndpoint(intf, UsbConstants.USB_DIR_OUT)
        } catch (error: Exception) {
            usbConnection.releaseInterface(intf)
            usbConnection.close()
            throw error
        }
        val serverSocket = try {
            ServerSocket(0, 1, InetAddress.getLoopbackAddress())
        } catch (error: Exception) {
            usbConnection.close()
            throw error
        }
        Thread({
            try {
                val remote = serverSocket.accept()
                startUsbTunnel(remote, usbConnection, bulkIn, bulkOut)
            } catch (_: IOException) {
                serverSocket.close()
            }
        }, "adb-usb-tunnel-$sessionId").apply { isDaemon = true; start() }
        val key = try {
            wirelessKeyMaterial()
        } catch (error: Exception) {
            serverSocket.close()
            usbConnection.releaseInterface(intf)
            usbConnection.close()
            throw error
        }
        val adbConnection = try {
            WirelessAdbConnection.Builder()
                .setHost(InetAddress.getLoopbackAddress().hostAddress!!)
                .setPort(serverSocket.localPort)
                .setPrivateKey(key.privateKey)
                .setCertificate(key.certificate)
                .setDeviceName("adb_helper")
                .build()
                .also {
                    if (!it.connect(30, TimeUnit.SECONDS, false)) {
                        it.close()
                        throw IOException("USB ADB authorization timed out.")
                    }
                }
        } catch (error: Exception) {
            serverSocket.close()
            usbConnection.releaseInterface(intf)
            usbConnection.close()
            throw error
        }
        val stream = try {
            adbConnection.open(AdbProtocolSpec.shellDestination())
        } catch (error: Exception) {
            adbConnection.close()
            serverSocket.close()
            usbConnection.releaseInterface(intf)
            usbConnection.close()
            throw error
        }
        val input = stream.openInputStream()
        val output = stream.openOutputStream()
        try {
            sendWorkingDirectory(output, workingDir)
        } catch (error: Exception) {
            try {
                stream.close()
            } finally {
                try {
                    adbConnection.close()
                } finally {
                    serverSocket.close()
                    usbConnection.releaseInterface(intf)
                    usbConnection.close()
                }
            }
            throw error
        }
        return createSession(
            sessionId,
            input,
            output,
        ) {
            try {
                stream.close()
            } finally {
                try {
                    adbConnection.close()
                } finally {
                    serverSocket.close()
                    usbConnection.releaseInterface(intf)
                    usbConnection.close()
                }
            }
        }
    }

    private fun startUsbTunnel(
        socket: Socket,
        connection: UsbDeviceConnection,
        endpointIn: UsbEndpoint,
        endpointOut: UsbEndpoint,
    ) {
        val closed = AtomicBoolean(false)
        val socketToUsb = Thread({
            try {
                val input = socket.getInputStream()
                val buffer = ByteArray(16 * 1024)
                while (!closed.get()) {
                    val length = input.read(buffer)
                    if (length < 0) break
                    var offset = 0
                    while (offset < length) {
                        val written = connection.bulkTransfer(
                            endpointOut,
                            buffer,
                            offset,
                            length - offset,
                            USB_TRANSFER_TIMEOUT_MS,
                        )
                        if (written <= 0) throw IOException("USB ADB bulk write failed.")
                        offset += written
                    }
                }
            } catch (_: IOException) {
                closed.set(true)
            } finally {
                runCatching { socket.close() }
            }
        }, "adb-usb-write").apply { isDaemon = true; start() }

        try {
            val output = socket.getOutputStream()
            val buffer = ByteArray(16 * 1024)
            while (!closed.get()) {
                val length = connection.bulkTransfer(
                    endpointIn,
                    buffer,
                    buffer.size,
                    USB_TRANSFER_TIMEOUT_MS,
                )
                if (length > 0) output.write(buffer, 0, length)
                else if (length < 0 && socket.isClosed) break
            }
        } catch (_: IOException) {
            closed.set(true)
        } finally {
            closed.set(true)
            runCatching { socket.close() }
            socketToUsb.interrupt()
        }
    }

    private fun discoverWirelessDevices(): List<Map<String, String>> {
        val discovered = findWirelessEndpoints(4, TimeUnit.SECONDS)
        discovered.forEach(::saveWirelessEndpoint)
        val saved = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .all
            .mapNotNull { (serial, label) ->
                val endpoint = runCatching {
                    AdbProtocolSpec.parseWirelessEndpoint(serial)
                }.getOrNull() ?: return@mapNotNull null
                WirelessEndpoint(
                    endpoint.first,
                    endpoint.second,
                    label as? String ?: endpoint.first,
                )
            }
        return (discovered + saved).distinctBy { it.serial }.map { endpoint ->
            saveWirelessEndpoint(endpoint)
            mapOf(
                "id" to endpoint.serial,
                "label" to endpoint.label,
                "transport" to "wireless",
            )
        }
    }

    private fun findWirelessEndpoint(host: String, timeout: Long, unit: TimeUnit): WirelessEndpoint? {
        val expectedAddress = try {
            InetAddress.getByName(host).hostAddress
        } catch (_: java.net.UnknownHostException) {
            return null
        }
        return findWirelessEndpoints(timeout, unit).firstOrNull {
            it.host == expectedAddress
        }
    }

    private fun findWirelessEndpoints(timeout: Long, unit: TimeUnit): List<WirelessEndpoint> {
        val found = java.util.concurrent.CopyOnWriteArrayList<WirelessEndpoint>()
        val latch = CountDownLatch(1)
        val resolutionLock = Object()
        val pending = java.util.ArrayDeque<NsdServiceInfo>()
        var resolving = false
        val seen = java.util.concurrent.ConcurrentHashMap.newKeySet<String>()
        lateinit var resolveNext: () -> Unit
        resolveNext = {
            val next = synchronized(resolutionLock) {
                if (resolving || pending.isEmpty()) {
                    null
                } else {
                    resolving = true
                    pending.removeFirst()
                }
            }
            if (next != null) {
                val resolveListener = object : NsdManager.ResolveListener {
                    override fun onResolveFailed(info: NsdServiceInfo, errorCode: Int) {
                        synchronized(resolutionLock) {
                            resolving = false
                            resolutionLock.notifyAll()
                        }
                        resolveNext()
                    }

                    override fun onServiceResolved(info: NsdServiceInfo) {
                        val address = info.host?.hostAddress
                        if (address != null && info.port in 1..65535) {
                            found += WirelessEndpoint(
                                host = address,
                                port = info.port,
                                label = info.serviceName.ifBlank { address },
                            )
                        }
                        synchronized(resolutionLock) {
                            resolving = false
                            resolutionLock.notifyAll()
                        }
                        resolveNext()
                    }
                }
                try {
                    nsdManager.resolveService(next, resolveListener)
                } catch (_: IllegalArgumentException) {
                    synchronized(resolutionLock) {
                        resolving = false
                        resolutionLock.notifyAll()
                    }
                    resolveNext()
                }
            }
        }
        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) = Unit

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                if (
                    serviceInfo.serviceType == AdbProtocolSpec.WIRELESS_SERVICE_TYPE &&
                    seen.add(serviceInfo.serviceName)
                ) {
                    synchronized(resolutionLock) {
                        pending.addLast(serviceInfo)
                    }
                    resolveNext()
                }
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                seen.remove(serviceInfo.serviceName)
            }

            override fun onDiscoveryStopped(serviceType: String) {
                latch.countDown()
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                try {
                    nsdManager.stopServiceDiscovery(this)
                } catch (_: IllegalArgumentException) {
                    latch.countDown()
                }
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                latch.countDown()
            }
        }
        val multicastLock = context.getSystemService(WifiManager::class.java)
            ?.createMulticastLock("adb_helper_wireless_scan")
        multicastLock?.setReferenceCounted(false)
        multicastLock?.acquire()
        try {
            nsdManager.discoverServices(
                AdbProtocolSpec.WIRELESS_SERVICE_TYPE,
                NsdManager.PROTOCOL_DNS_SD,
                listener,
            )
            Thread.sleep(unit.toMillis(timeout))
        } finally {
            try {
                nsdManager.stopServiceDiscovery(listener)
            } catch (_: IllegalArgumentException) {
                latch.countDown()
            }
            latch.await(2, TimeUnit.SECONDS)
            if (multicastLock?.isHeld == true) multicastLock.release()
        }
        val resolutionDeadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
        synchronized(resolutionLock) {
            while (resolving || pending.isNotEmpty()) {
                val remaining = resolutionDeadline - System.nanoTime()
                if (remaining <= 0) break
                TimeUnit.NANOSECONDS.timedWait(resolutionLock, remaining)
            }
        }
        return found.distinctBy { it.serial }
    }

    private fun scanLegacyAdbEndpoints(): List<WirelessEndpoint> {
        val interfaces = NetworkInterface.getNetworkInterfaces() ?: return emptyList()
        val candidates = interfaces.toList()
            .filter { it.isUp && !it.isLoopback }
            .flatMap { it.interfaceAddresses }
            .flatMap { interfaceAddress ->
                val local = interfaceAddress.address as? Inet4Address
                    ?: return@flatMap emptyList()
                if (!local.isSiteLocalAddress) return@flatMap emptyList()
                val prefix = interfaceAddress.networkPrefixLength.toInt()
                if (prefix !in 16..30) return@flatMap emptyList()
                val localValue = ipv4ToLong(local)
                val mask = (0xffffffffL shl (32 - prefix)) and 0xffffffffL
                val firstHost = (localValue and mask) + 1
                val lastHost = (localValue and mask) + (mask xor 0xffffffffL) - 1
                if (lastHost < firstHost) return@flatMap emptyList()
                val start = if (lastHost - firstHost + 1 > MAX_SUBNET_SCAN_HOSTS) {
                    (localValue - MAX_SUBNET_SCAN_HOSTS / 2)
                        .coerceAtLeast(firstHost)
                } else firstHost
                val end = if (lastHost - firstHost + 1 > MAX_SUBNET_SCAN_HOSTS) {
                    (start + MAX_SUBNET_SCAN_HOSTS - 1).coerceAtMost(lastHost)
                } else lastHost
                (start..end)
                    .filter { it != localValue }
                    .map(::longToIpv4)
            }
            .distinct()
            .take(MAX_SUBNET_SCAN_HOSTS.toInt())
        if (candidates.isEmpty()) return emptyList()

        val scanner = Executors.newFixedThreadPool(SUBNET_SCAN_THREADS)
        val futures = try {
            candidates.map { host ->
                scanner.submit<WirelessEndpoint?> {
                    try {
                        Socket().use { socket ->
                            socket.connect(
                                InetSocketAddress(host, LEGACY_ADB_PORT),
                                SUBNET_CONNECT_TIMEOUT_MS,
                            )
                        }
                        WirelessEndpoint(host, LEGACY_ADB_PORT, host)
                    } catch (_: IOException) {
                        null
                    }
                }
            }
        } finally {
            scanner.shutdown()
        }
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(SUBNET_SCAN_TIMEOUT_SECONDS)
        val reachable = mutableListOf<WirelessEndpoint>()
        for (future in futures) {
            val remaining = deadline - System.nanoTime()
            if (remaining <= 0) break
            try {
                future.get(remaining, TimeUnit.NANOSECONDS)?.let(reachable::add)
            } catch (_: Exception) {
                future.cancel(true)
            }
        }
        scanner.shutdownNow()
        return reachable
    }

    private fun ipv4ToLong(address: Inet4Address): Long =
        address.address.fold(0L) { value, byte -> (value shl 8) or (byte.toLong() and 0xff) }

    private fun longToIpv4(value: Long): String =
        listOf(24, 16, 8, 0).joinToString(".") { shift ->
            ((value ushr shift) and 0xff).toString()
        }

    private fun saveWirelessEndpoint(endpoint: WirelessEndpoint) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(endpoint.serial, endpoint.label)
            .apply()
    }

    private fun findAdbInterface(device: UsbDevice): UsbInterface? =
        (0 until device.interfaceCount)
            .map(device::getInterface)
            .firstOrNull {
                AdbProtocolSpec.isAdbInterface(
                    it.interfaceClass,
                    it.interfaceSubclass,
                    it.interfaceProtocol,
                )
            }

    private fun findEndpoint(intf: UsbInterface, direction: Int): UsbEndpoint =
        (0 until intf.endpointCount)
            .map(intf::getEndpoint)
            .firstOrNull {
                it.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                    it.direction == direction
            }
            ?: throw IOException("The USB ADB interface is missing a bulk endpoint.")

    private fun requestUsbPermission(device: UsbDevice): Boolean {
        if (usbManager.hasPermission(device)) return true
        val action = "${context.packageName}.USB_PERMISSION"
        val granted = java.util.concurrent.atomic.AtomicBoolean(false)
        val latch = CountDownLatch(1)
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != action) return
                granted.set(intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false))
                latch.countDown()
            }
        }
        val filter = IntentFilter(action)
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            context.registerReceiver(receiver, filter)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            device.deviceId,
            Intent(action).setPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0,
        )
        try {
            usbManager.requestPermission(device, pendingIntent)
            if (!latch.await(30, TimeUnit.SECONDS)) {
                throw IOException("Timed out waiting for USB debugging permission.")
            }
            return granted.get()
        } finally {
            context.unregisterReceiver(receiver)
        }
    }

    @Synchronized
    private fun wirelessKeyMaterial(): WirelessKeyMaterial {
        val directory = File(context.filesDir, "adb-wireless").apply { mkdirs() }
        val privateFile = File(directory, "private.der")
        val certificateFile = File(directory, "certificate.der")
        if (privateFile.isFile && certificateFile.isFile) {
            val privateKey = java.security.KeyFactory.getInstance("RSA")
                .generatePrivate(java.security.spec.PKCS8EncodedKeySpec(privateFile.readBytes()))
            val certificate = certificateFile.inputStream().use {
                CertificateFactory.getInstance("X.509").generateCertificate(it)
            }
            return WirelessKeyMaterial(privateKey, certificate)
        }
        val provider = BouncyCastleProvider()
        if (Security.getProvider(provider.name) == null) Security.addProvider(provider)
        val keyPairGenerator = KeyPairGenerator.getInstance("RSA")
        keyPairGenerator.initialize(2048)
        val pair = keyPairGenerator.generateKeyPair()
        val start = Date()
        val subject = X500Name("CN=adb_helper")
        val builder = JcaX509v3CertificateBuilder(
            subject,
            java.math.BigInteger.valueOf(start.time.coerceAtLeast(1)),
            start,
            Date(start.time + TimeUnit.DAYS.toMillis(3650)),
            subject,
            pair.public,
        )
        val signer = JcaContentSignerBuilder("SHA256withRSA")
            .setProvider(provider)
            .build(pair.private)
        val certificate = JcaX509CertificateConverter()
            .setProvider(provider)
            .getCertificate(builder.build(signer))
        privateFile.writeBytes(pair.private.encoded)
        certificateFile.writeBytes(certificate.encoded)
        return WirelessKeyMaterial(pair.private, certificate)
    }

    private fun createSession(
        sessionId: String,
        input: InputStream,
        output: OutputStream,
        closeTransport: () -> Unit,
    ): ShellSession {
        val closed = AtomicBoolean(false)
        val session = object : ShellSession {
            override fun write(data: String) {
                check(!closed.get()) { "The ADB shell session is closed." }
                output.write(data.toByteArray(StandardCharsets.UTF_8))
                output.flush()
            }

            override fun close() {
                if (closed.compareAndSet(false, true)) {
                    runCatching(closeTransport).onFailure {
                        eventSink.emit(WireEvent(sessionId, "stderr", "ADB close failed: ${it.message}\n"))
                    }
                }
            }
        }
        Thread({
            try {
                InputStreamReader(input, StandardCharsets.UTF_8).use { reader ->
                    val buffer = CharArray(4096)
                    while (!closed.get()) {
                        val size = reader.read(buffer)
                        if (size < 0) break
                        eventSink.emit(WireEvent(sessionId, "stdout", String(buffer, 0, size)))
                    }
                }
                if (closed.compareAndSet(false, true)) {
                    runCatching(closeTransport)
                    eventSink.emit(WireEvent(sessionId, "exit", "ADB shell closed", 0))
                }
            } catch (error: Exception) {
                if (closed.compareAndSet(false, true)) {
                    runCatching(closeTransport)
                    eventSink.emit(
                        WireEvent(sessionId, "stderr", "ADB shell failed: ${error.message}\n"),
                    )
                    eventSink.emit(WireEvent(sessionId, "exit", "ADB shell failed", 1))
                }
            }
        }, "adb-stream-$sessionId").apply { isDaemon = true; start() }
        eventSink.emit(WireEvent(sessionId, "stdout", "ADB shell ready\n"))
        return session
    }

    private fun sendWorkingDirectory(stream: OutputStream, workingDir: String?) {
        if (!workingDir.isNullOrBlank()) {
            stream.write("cd ${shellQuote(workingDir)} || echo 'Unable to change directory'\n".toByteArray())
            stream.flush()
        }
    }

    private data class WirelessEndpoint(val host: String, val port: Int, val label: String) {
        val serial: String get() = "$host:$port"
    }

    private data class WirelessKeyMaterial(
        val privateKey: java.security.PrivateKey,
        val certificate: Certificate,
    )

    companion object {
        private const val SCRCPY_REMOTE_PATH = "/data/local/tmp/scrcpy-server.jar"
        private const val SCRCPY_LOCAL_DESTINATION = "localabstract:scrcpy"
        private const val PREFS = "wireless_adb"
        private const val USB_TRANSFER_TIMEOUT_MS = 1_000
        private const val LEGACY_ADB_PORT = 5555
        private const val MAX_SUBNET_SCAN_HOSTS = 1024L
        private const val SUBNET_SCAN_THREADS = 64
        private const val SUBNET_CONNECT_TIMEOUT_MS = 400
        private const val SUBNET_SCAN_TIMEOUT_SECONDS = 8L
        private const val SYNC_DATA_SIZE = 64 * 1024
        private const val MAX_SYNC_ERROR_SIZE = 64 * 1024
        private val PACKAGE_NAME = Regex("""[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+""")
        private val EXIT_CODE = Regex("""(?m)^__ADB_EXIT__(\d+)\s*$""")
        private val FILE_LIST_LINE = Regex(
            """^(\S+)\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})\s+(.+)$""",
        )
        private val COMMAND_FAILURE = Regex("""(?im)^(?:Failure|Failed|Error|Exception)\b""")
    }
}
