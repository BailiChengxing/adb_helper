package com.example.adb_helper.gateway

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdbProtocolSpecTest {
    @Test
    fun recognizesOnlyAndroidDebugBridgeUsbInterfaces() {
        assertTrue(AdbProtocolSpec.isAdbInterface(0xff, 0x42, 0x01))
        assertFalse(AdbProtocolSpec.isAdbInterface(0xff, 0x42, 0x02))
        assertFalse(AdbProtocolSpec.isAdbInterface(0x08, 0x42, 0x01))
    }

    @Test
    fun wirelessPairingValidatesEndpointAndSixDigitCode() {
        AdbProtocolSpec.validatePairing("192.168.1.50", 37123, "012345")
    }

    @Test
    fun wirelessPairingRejectsInvalidInput() {
        val invalidInputs = listOf(
            Triple("", 37123, "012345"),
            Triple("192.168.1.50", 0, "012345"),
            Triple("192.168.1.50", 65536, "012345"),
            Triple("192.168.1.50", 37123, "12345"),
            Triple("192.168.1.50", 37123, "12a456"),
        )

        invalidInputs.forEach { (host, port, code) ->
            try {
                AdbProtocolSpec.validatePairing(host, port, code)
                throw AssertionError("Expected invalid wireless pairing input to be rejected.")
            } catch (expected: IllegalArgumentException) {
                assertTrue(expected.message!!.isNotBlank())
            }
        }
    }

    @Test
    fun validatesDirectWirelessEndpoints() {
        AdbProtocolSpec.validateEndpoint("192.168.1.50", 5555)
        AdbProtocolSpec.validateEndpoint("fe80::a1b2", 37123)
    }

    @Test
    fun rejectsInvalidDirectWirelessEndpoints() {
        val invalidEndpoints = listOf(
            "" to 5555,
            "192.168.1.50" to 0,
            "192.168.1.50" to 65536,
        )
        invalidEndpoints.forEach { (host, port) ->
            try {
                AdbProtocolSpec.validateEndpoint(host, port)
                throw AssertionError("Expected an invalid wireless endpoint to be rejected.")
            } catch (expected: IllegalArgumentException) {
                assertTrue(expected.message!!.isNotBlank())
            }
        }
    }

    @Test
    fun shellServiceUsesTheAdbShellTransport() {
        assertEquals("shell:", AdbProtocolSpec.shellDestination())
    }

    @Test
    fun parsesWirelessIpv4AndIpv6Endpoints() {
        assertEquals("192.168.1.50" to 5555, AdbProtocolSpec.parseWirelessEndpoint("192.168.1.50:5555"))
        assertEquals("fe80::a1b2" to 37123, AdbProtocolSpec.parseWirelessEndpoint("fe80::a1b2:37123"))
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsInvalidWirelessEndpointPort() {
        AdbProtocolSpec.parseWirelessEndpoint("192.168.1.50:65536")
    }
}
