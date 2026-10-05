package com.example.adb_helper.gateway

import com.topjohnwu.superuser.Shell
import rikka.shizuku.Shizuku
import java.io.ByteArrayOutputStream
import java.io.BufferedReader
import java.io.InputStreamReader
import java.nio.charset.StandardCharsets
import java.util.concurrent.atomic.AtomicBoolean

fun interface ShellEventSink {
    fun emit(event: WireEvent)
}

data class WireEvent(
    val sessionId: String,
    val stream: String,
    val data: String,
    val exitCode: Int? = null,
)

data class TransportMode(val wireName: String, val executable: String) {
    companion object {
        val LOCAL = TransportMode("local", "/system/bin/sh")
        val SHIZUKU = TransportMode("shizuku", "/system/bin/sh")
        val ROOT = TransportMode("root", "su")

        fun fromWire(value: String?): TransportMode? = when (value) {
            LOCAL.wireName -> LOCAL
            SHIZUKU.wireName -> SHIZUKU
            ROOT.wireName -> ROOT
            else -> null
        }
    }
}

interface ShellSession {
    fun write(data: String)
    fun close()
}

class AndroidShellBackend(
    private val eventSink: ShellEventSink,
) {
    fun open(sessionId: String, mode: TransportMode, workingDir: String?): ShellSession {
        val process = startShell(mode, workingDir)
        val closed = AtomicBoolean(false)
        Thread({ forward(sessionId, "stdout", process.inputStream, closed) }, "adb-stdout-$sessionId")
            .apply { isDaemon = true; start() }
        Thread({ forward(sessionId, "stderr", process.errorStream, closed) }, "adb-stderr-$sessionId")
            .apply { isDaemon = true; start() }
        Thread({
            val exitCode = process.waitFor()
            if (closed.compareAndSet(false, true)) {
                eventSink.emit(WireEvent(sessionId, "exit", "Shell process exited", exitCode))
            }
        }, "adb-exit-$sessionId").apply { isDaemon = true; start() }
        return object : ShellSession {
            override fun write(data: String) {
                process.outputStream.apply {
                    write(data.toByteArray(StandardCharsets.UTF_8))
                    flush()
                }
            }

            override fun close() {
                if (closed.compareAndSet(false, true)) {
                    process.destroy()
                    eventSink.emit(WireEvent(sessionId, "exit", "Session closed", process.waitFor()))
                }
            }
        }.also {
            eventSink.emit(WireEvent(sessionId, "stdout", "Shell ready\n"))
        }
    }

    fun execOnce(mode: TransportMode, command: String, workingDir: String?): Int {
        if (mode == TransportMode.ROOT && !Shell.getShell().isRoot) {
            throw IllegalStateException("Root access is not available on this device.")
        }
        val process = when (mode) {
            TransportMode.LOCAL -> ProcessBuilder(mode.executable, "-c", command)
                .directory(workingDirectory(workingDir))
                .redirectErrorStream(true)
                .start()
            TransportMode.SHIZUKU -> Shizuku.newProcess(
                arrayOf(mode.executable, "-c", command),
                emptyArray(),
                workingDir,
            )
            TransportMode.ROOT -> ProcessBuilder(mode.executable, "-c", command)
                .directory(workingDirectory(workingDir))
                .redirectErrorStream(true)
                .start()
            else -> error("Unsupported transport.")
        }
        val drainStderr = Thread {
            process.errorStream.use { input ->
                val buffer = ByteArray(8192)
                while (input.read(buffer) >= 0) {
                    // Drain stderr concurrently so a full pipe cannot block the command.
                }
            }
        }.apply { isDaemon = true; start() }
        process.inputStream.use { input ->
            val buffer = ByteArray(8192)
            while (input.read(buffer) >= 0) {
                // execOnce exposes only an exit code; drain output to avoid blocking the process.
            }
        }
        val exitCode = process.waitFor()
        drainStderr.join()
        return exitCode
    }

    fun runCaptured(
        mode: TransportMode,
        command: String,
        workingDir: String?,
        input: ByteArray? = null,
    ): CapturedCommand {
        if (mode == TransportMode.ROOT && !Shell.getShell().isRoot) {
            throw IllegalStateException("Root access is not available on this device.")
        }
        val process = when (mode) {
            TransportMode.LOCAL -> ProcessBuilder(mode.executable, "-c", command)
                .directory(workingDirectory(workingDir))
                .start()
            TransportMode.SHIZUKU -> Shizuku.newProcess(
                arrayOf(mode.executable, "-c", command),
                emptyArray(),
                workingDir,
            )
            TransportMode.ROOT -> ProcessBuilder(mode.executable, "-c", command)
                .directory(workingDirectory(workingDir))
                .start()
            else -> error("Unsupported transport.")
        }

        if (input != null) {
            Thread {
                try {
                    process.outputStream.use { it.write(input) }
                } catch (_: Exception) {
                }
            }.apply { isDaemon = true; start() }
        } else {
            try {
                process.outputStream.close()
            } catch (_: Exception) {
            }
        }

        val stderr = ByteArrayOutputStream()
        val stderrThread = Thread {
            try {
                process.errorStream.use { it.copyTo(stderr) }
            } catch (_: Exception) {
            }
        }.apply { isDaemon = true; start() }

        val stdout = process.inputStream.readBytes()
        val exitCode = process.waitFor()
        stderrThread.join(1_000)
        return CapturedCommand(exitCode, stdout + stderr.toByteArray())
    }

    fun shellQuote(value: String): String =
        "'" + value.replace("'", "'\\''") + "'"

    data class CapturedCommand(
        val exitCode: Int,
        val output: ByteArray,
    )
    private fun startShell(mode: TransportMode, workingDir: String?): Process {
        if (mode == TransportMode.ROOT && !Shell.getShell().isRoot) {
            throw IllegalStateException("Root access is not available on this device.")
        }
        return when (mode) {
        TransportMode.LOCAL -> ProcessBuilder(mode.executable)
            .directory(workingDirectory(workingDir))
            .start()
        TransportMode.SHIZUKU -> Shizuku.newProcess(
            arrayOf(mode.executable),
            emptyArray(),
            workingDir,
        )
        TransportMode.ROOT -> ProcessBuilder(mode.executable)
            .directory(workingDirectory(workingDir))
            .start()
        else -> error("Unsupported transport.")
        }
    }

    private fun workingDirectory(path: String?) =
        path?.let { java.io.File(it) }?.takeIf { it.isDirectory }

    private fun forward(
        sessionId: String,
        stream: String,
        input: java.io.InputStream,
        closed: AtomicBoolean,
    ) {
        try {
            BufferedReader(InputStreamReader(input, StandardCharsets.UTF_8)).use { reader ->
                val buffer = CharArray(4096)
                while (!closed.get()) {
                    val length = reader.read(buffer)
                    if (length < 0) break
                    eventSink.emit(WireEvent(sessionId, stream, String(buffer, 0, length)))
                }
            }
        } catch (error: Exception) {
            if (!closed.get()) {
                eventSink.emit(
                    WireEvent(sessionId, "stderr", "Shell output stream failed: ${error.message}\n"),
                )
            }
        }
    }
}
