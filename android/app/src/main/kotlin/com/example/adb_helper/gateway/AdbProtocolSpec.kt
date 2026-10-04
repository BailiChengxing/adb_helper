package com.example.adb_helper.gateway

internal object AdbProtocolSpec {
    const val ADB_INTERFACE_CLASS = 0xff
    const val ADB_INTERFACE_SUBCLASS = 0x42
    const val ADB_INTERFACE_PROTOCOL = 0x01
    const val WIRELESS_SERVICE_TYPE = "_adb-tls-connect._tcp."

    fun isAdbInterface(interfaceClass: Int, subclass: Int, protocol: Int): Boolean =
        interfaceClass == ADB_INTERFACE_CLASS &&
            subclass == ADB_INTERFACE_SUBCLASS &&
            protocol == ADB_INTERFACE_PROTOCOL

    fun validatePairing(host: String, port: Int, code: String) {
        require(host.isNotBlank()) { "A pairing host is required." }
        require(port in 1..65535) { "The pairing port must be between 1 and 65535." }
        require(code.length == 6 && code.all(Char::isDigit)) {
            "The pairing code must contain exactly six digits."
        }
    }

    fun validateEndpoint(host: String, port: Int) {
        require(host.isNotBlank()) { "A wireless device IP address is required." }
        require(port in 1..65535) { "The ADB port must be between 1 and 65535." }
    }

    fun shellDestination(): String = "shell:"

    fun parseWirelessEndpoint(serial: String): Pair<String, Int> {
        val separator = serial.lastIndexOf(':')
        require(separator > 0) { "Invalid wireless ADB address." }
        val host = serial.substring(0, separator)
        val port = serial.substring(separator + 1).toIntOrNull()
            ?: throw IllegalArgumentException("Invalid wireless ADB port.")
        require(port in 1..65535) { "Invalid wireless ADB port." }
        return host to port
    }
}
