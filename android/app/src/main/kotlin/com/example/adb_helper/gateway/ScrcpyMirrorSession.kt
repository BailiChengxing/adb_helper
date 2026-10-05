package com.example.adb_helper.gateway

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.util.Log
import android.view.Surface
import java.io.EOFException
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicBoolean

class ScrcpyMirrorSession(
    private val videoInput: InputStream,
    private val surface: Surface,
    private val onClose: () -> Unit,
) {
    private val running = AtomicBoolean(true)
    private val sizeReady = CountDownLatch(1)
    private var worker: Thread? = null
    private var decoder: MediaCodec? = null
    private var pendingConfig: ByteArray? = null

    @Volatile
    var width: Int = 0
        private set

    @Volatile
    var height: Int = 0
        private set

    fun start() {
        worker = Thread(::run, "scrcpy-video").apply {
            isDaemon = true
            start()
        }
    }

    fun stop() {
        if (!running.compareAndSet(true, false)) return
        try {
            videoInput.close()
        } catch (_: Exception) {
        }
        worker?.interrupt()
        releaseDecoder()
        try {
            onClose()
        } catch (_: Exception) {
        }
    }

    fun awaitSize(timeoutMillis: Long): Boolean {
        return sizeReady.await(timeoutMillis, java.util.concurrent.TimeUnit.MILLISECONDS)
    }
    private fun run() {
        try {
            readFully(1) // scrcpy dummy byte
            readFully(64) // device metadata
            val codecId = readInt()
            var currentDecoder: MediaCodec? = null

            while (running.get()) {
                val first = readInt()
                if ((first and 0x80000000.toInt()) != 0) {
                    width = readInt()
                    height = readInt()
                    sizeReady.countDown()
                    currentDecoder?.release()
                    currentDecoder = createDecoder(codecId, width, height)
                    decoder = currentDecoder
                    pendingConfig?.let { config ->
                        queuePacket(currentDecoder, config, true, 0)
                        pendingConfig = null
                    }
                    continue
                }

                val rest = readFully(8)
                val packetSize = ByteBuffer.wrap(rest)
                    .order(ByteOrder.BIG_ENDIAN)
                    .getInt(4)
                if (packetSize <= 0 || packetSize > MAX_PACKET_SIZE) {
                    throw IllegalStateException("Invalid scrcpy packet size: $packetSize")
                }

                val header = ByteBuffer.allocate(12)
                    .order(ByteOrder.BIG_ENDIAN)
                    .putInt(first)
                    .put(rest)
                    .array()
                val packet = readFully(packetSize)
                val packetHeader = ByteBuffer.wrap(header).order(ByteOrder.BIG_ENDIAN)
                val packetBits = packetHeader.long
                val isConfig = (packetBits and CONFIG_FLAG) != 0L
                val isKeyFrame = (packetBits and KEY_FRAME_FLAG) != 0L

                if (currentDecoder == null) {
                    if (isConfig) pendingConfig = packet
                    continue
                }
                queuePacket(
                    currentDecoder,
                    packet,
                    isConfig,
                    if (isKeyFrame) 100_000L else 0L,
                )
                drainDecoder(currentDecoder)
            }
        } catch (error: Exception) {
            if (running.get()) {
                Log.w(TAG, "scrcpy video stream ended", error)
            }
        } finally {
            releaseDecoder()
            try {
                videoInput.close()
            } catch (_: Exception) {
            }
            running.set(false)
        }
    }

    private fun createDecoder(codecId: Int, width: Int, height: Int): MediaCodec {
        val mime = when (codecId) {
            CODEC_H264 -> MediaFormat.MIMETYPE_VIDEO_AVC
            CODEC_H265 -> MediaFormat.MIMETYPE_VIDEO_HEVC
            CODEC_AV1 -> MediaFormat.MIMETYPE_VIDEO_AV1
            CODEC_VP8 -> MediaFormat.MIMETYPE_VIDEO_VP8
            CODEC_VP9 -> MediaFormat.MIMETYPE_VIDEO_VP9
            else -> throw IllegalStateException("Unsupported scrcpy video codec: $codecId")
        }
        val format = MediaFormat.createVideoFormat(mime, width, height)
        format.setInteger(
            MediaFormat.KEY_MAX_INPUT_SIZE,
            (width * height).coerceAtLeast(1024 * 1024),
        )
        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(format, surface, null, 0)
        codec.start()
        return codec
    }

    private fun queuePacket(
        codec: MediaCodec,
        payload: ByteArray,
        config: Boolean,
        presentationTimeUs: Long,
    ) {
        val inputIndex = codec.dequeueInputBuffer(TIMEOUT_US)
        if (inputIndex < 0) return
        val buffer = codec.getInputBuffer(inputIndex) ?: return
        buffer.clear()
        buffer.put(payload)
        codec.queueInputBuffer(
            inputIndex,
            0,
            payload.size,
            presentationTimeUs,
            if (config) MediaCodec.BUFFER_FLAG_CODEC_CONFIG else 0,
        )
    }

    private fun drainDecoder(codec: MediaCodec) {
        val info = MediaCodec.BufferInfo()
        while (true) {
            val outputIndex = codec.dequeueOutputBuffer(info, 0)
            if (outputIndex < 0) break
            codec.releaseOutputBuffer(outputIndex, true)
        }
    }

    private fun releaseDecoder() {
        val codec = decoder ?: return
        decoder = null
        try {
            codec.stop()
        } catch (_: Exception) {
        }
        try {
            codec.release()
        } catch (_: Exception) {
        }
    }

    private fun readInt(): Int {
        val bytes = readFully(4)
        return ByteBuffer.wrap(bytes).order(ByteOrder.BIG_ENDIAN).int
    }

    private fun readFully(length: Int): ByteArray {
        val result = ByteArray(length)
        var offset = 0
        while (offset < length) {
            val read = videoInput.read(result, offset, length - offset)
            if (read < 0) throw EOFException("scrcpy stream closed")
            offset += read
        }
        return result
    }

    companion object {
        private const val TAG = "ScrcpyMirror"
        private const val TIMEOUT_US = 10_000L
        private const val MAX_PACKET_SIZE = 32 * 1024 * 1024
        private const val CONFIG_FLAG = 0x4000000000000000L
        private const val KEY_FRAME_FLAG = 0x2000000000000000L
        private const val CODEC_H264 = 0x68323634
        private const val CODEC_H265 = 0x68323635
        private const val CODEC_AV1 = 0x617631
        private const val CODEC_VP8 = 0x767038
        private const val CODEC_VP9 = 0x767039
    }
}
