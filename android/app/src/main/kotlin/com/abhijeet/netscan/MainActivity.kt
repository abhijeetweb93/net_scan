package com.abhijeet.netscan

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.FileReader
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.util.Collections
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.abhijeet.netscan/network"
    private val executor: ExecutorService = Executors.newFixedThreadPool(120)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "getNetworkInfo" -> executor.submit {
                        try {
                            runOnUiThread { result.success(getNetworkInfo()) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("ERROR", e.message, null) }
                        }
                    }

                    "scanNetwork" -> {
                        val subnet  = call.argument<String>("subnet")  ?: ""
                        val gateway = call.argument<String>("gateway") ?: ""
                        executor.submit {
                            try {
                                val devices = scanNetwork(subnet, gateway)
                                runOnUiThread { result.success(devices) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("SCAN_ERROR", e.message, null) }
                            }
                        }
                    }

                    "stopScan" -> result.success(null)

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun getNetworkInfo(): Map<String, Any?> {
        val wm   = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val dhcp = wm.dhcpInfo
        val wifi = wm.connectionInfo
        fun i2ip(i: Int) =
            "${i and 0xFF}.${(i shr 8) and 0xFF}.${(i shr 16) and 0xFF}.${(i shr 24) and 0xFF}"
        var ssid = wifi.ssid?.removePrefix("\"")?.removeSuffix("\"") ?: ""
        if (ssid == "<unknown ssid>") ssid = ""
        return mapOf(
            "localIp" to i2ip(dhcp.ipAddress),
            "gateway" to i2ip(dhcp.gateway),
            "ssid"    to ssid,
            "bssid"   to (wifi.bssid ?: ""),
        )
    }

    private fun scanNetwork(subnet: String, gateway: String): List<Map<String, Any?>> {
        val found  = Collections.synchronizedSet(LinkedHashSet<String>())
        val macMap = Collections.synchronizedMap(HashMap<String, String>())
        fun reg(ip: String, mac: String = "") {
            found.add(ip)
            if (mac.isNotEmpty()) macMap[ip] = mac
        }

        // Step 1: existing ARP entries
        for ((ip, mac) in readArp()) {
            if (ip.startsWith("$subnet.")) reg(ip, mac)
        }

        // Step 2: UDP blast — forces kernel ARP for every IP
        val udpJobs = (1..254).map { i ->
            executor.submit {
                try {
                    DatagramSocket().use { s ->
                        s.soTimeout = 1
                        s.send(DatagramPacket(ByteArray(1), 1,
                            InetAddress.getByName("$subnet.$i"), 9))
                    }
                } catch (_: Exception) {}
            }
        }
        udpJobs.forEach { runCatching { it.get() } }
        Thread.sleep(1500) // safe — background thread

        // Step 3: re-read ARP
        for ((ip, mac) in readArp()) {
            if (ip.startsWith("$subnet.")) reg(ip, mac)
        }

        // Step 4: TCP probe remaining
        val remaining: List<String>
        synchronized(found) {
            remaining = (1..254).map { "$subnet.$it" }.filter { it !in found }
        }
        val tcpJobs = remaining.map { ip ->
            executor.submit { if (tcpProbe(ip)) reg(ip) }
        }
        tcpJobs.forEach { runCatching { it.get() } }

        // Step 5: final ARP
        for ((ip, mac) in readArp()) {
            if (ip.startsWith("$subnet.")) reg(ip, mac)
        }

        val snapshot: List<String>
        synchronized(found) {
            snapshot = found.sortedBy { it.split(".").lastOrNull()?.toIntOrNull() ?: 0 }
        }
        return snapshot.map { ip ->
            val mac: String
            synchronized(macMap) { mac = macMap[ip] ?: "" }
            mapOf("ip" to ip, "macAddress" to mac,
                  "isGateway" to (ip == gateway), "reachable" to true)
        }
    }

    private fun readArp(): Map<String, String> {
        val out = mutableMapOf<String, String>()
        try {
            BufferedReader(FileReader("/proc/net/arp")).use { br ->
                br.readLine()
                var line = br.readLine()
                while (line != null) {
                    val p = line.trim().split(Regex("\\s+"))
                    if (p.size >= 4) {
                        val flags = p[2].removePrefix("0x").toIntOrNull(16) ?: 0
                        val mac   = p[3]
                        if (flags > 0 && mac != "00:00:00:00:00:00" && mac.contains(":"))
                            out[p[0]] = mac.uppercase()
                    }
                    line = br.readLine()
                }
            }
        } catch (_: Exception) {}
        return out
    }

    private fun tcpProbe(ip: String): Boolean {
        for (port in listOf(80, 443, 22, 53, 8080, 445, 7000, 62078)) {
            try {
                Socket().use { s ->
                    s.connect(InetSocketAddress(ip, port), 600)
                    return true
                }
            } catch (e: Exception) {
                if (e.message?.lowercase()?.contains("refused") == true) return true
            }
        }
        return false
    }
}
