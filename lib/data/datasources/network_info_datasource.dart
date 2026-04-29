import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart' as nip;
import 'package:wifi_scanner/domain/models/scan_result.dart';
import 'package:wifi_scanner/core/utils/ip_utils.dart';
import 'package:wifi_scanner/core/utils/app_logger.dart';

class NetworkInfoDatasource {
  final nip.NetworkInfo _networkInfo = nip.NetworkInfo();

  // Cache hostname lookups to avoid redundant DNS calls
  final Map<String, String?> _hostnameCache = {};

  Future<NetworkInfo> getNetworkInfo() async {
    try {
      final localIp = await _getLocalIp();
      final gateway = await _getGateway(localIp);
      final ssid = await _getSsid();
      final bssid = await _getBssid();

      if (localIp == null || localIp.isEmpty) {
        throw Exception('Could not determine local IP address');
      }

      final subnet = IpUtils.getSubnet(localIp, '255.255.255.0');
      AppLogger.info('Network: IP=$localIp GW=$gateway SSID=$ssid');

      return NetworkInfo(
        localIp: localIp,
        subnetMask: '255.255.255.0',
        gateway: gateway ?? IpUtils.guessGateway(localIp),
        subnet: subnet,
        ssid: ssid?.replaceAll('"', ''),
        bssid: bssid,
      );
    } catch (e) {
      AppLogger.error('Failed to get network info: $e');
      rethrow;
    }
  }

  Future<String?> _getLocalIp() async {
    try {
      final ip = await _networkInfo.getWifiIP();
      if (ip != null && ip.isNotEmpty) return ip;
    } catch (_) {}
    return _getLocalIpFallback();
  }

  Future<String?> _getGateway(String? localIp) async {
    try {
      final gw = await _networkInfo.getWifiGatewayIP();
      if (gw != null && gw.isNotEmpty) return gw;
    } catch (_) {}
    if (localIp != null) return IpUtils.guessGateway(localIp);
    return null;
  }

  Future<String?> _getSsid() async {
    try { return await _networkInfo.getWifiName(); } catch (_) { return null; }
  }

  Future<String?> _getBssid() async {
    try { return await _networkInfo.getWifiBSSID(); } catch (_) { return null; }
  }

  Future<String?> _getLocalIpFallback() async {
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('en0') ||
            name.contains('wifi') || name.contains('wlp')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) return addr.address;
          }
        }
      }
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      AppLogger.error('IP fallback: $e');
    }
    return null;
  }

  /// Resolve hostname using multiple strategies:
  /// 1. Reverse DNS (PTR record)
  /// 2. NetBIOS name query
  /// Returns the best name found, or null
  Future<String?> resolveHostname(String ip) async {
    if (_hostnameCache.containsKey(ip)) {
      return _hostnameCache[ip];
    }

    String? name;

    // Strategy 1: Reverse DNS
    name ??= await _reverseDns(ip);

    // Strategy 2: NetBIOS (for Windows machines)
    name ??= await _netbiosLookup(ip);

    // Clean up the name
    if (name != null) {
      // Remove trailing dots (DNS artifact)
      name = name.replaceAll(RegExp(r'\.+$'), '');
      // If reverse DNS returns the IP itself, discard it
      if (name == ip) name = null;
      // Remove .local suffix for cleaner display
      if (name != null && name.endsWith('.local')) {
        name = name.replaceAll('.local', '');
      }
    }

    _hostnameCache[ip] = name;
    return name;
  }

  Future<String?> _reverseDns(String ip) async {
    try {
      final result = await InternetAddress(ip)
          .reverse()
          .timeout(const Duration(seconds: 2));
      final host = result.host;
      if (host.isEmpty || host == ip) return null;
      return host;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _netbiosLookup(String ip) async {
    // NetBIOS Name Service — port 137 UDP
    // Send a NAME QUERY REQUEST and parse the response
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
          .timeout(const Duration(milliseconds: 500));

      // NetBIOS name query packet
      final query = [
        0x82, 0x28, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x20, 0x43, 0x4b, 0x41,
        0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
        0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
        0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
        0x41, 0x41, 0x41, 0x41, 0x41, 0x00, 0x00, 0x21,
        0x00, 0x01,
      ];

      socket.send(query, InternetAddress(ip), 137);

      final completer = Completer<String?>();
      Timer(const Duration(milliseconds: 800), () {
        if (!completer.isCompleted) completer.complete(null);
      });

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket!.receive();
          if (datagram != null && datagram.data.length > 56) {
            final name = _parseNetbiosName(datagram.data);
            if (!completer.isCompleted) completer.complete(name);
          }
        }
      });

      return await completer.future;
    } catch (_) {
      return null;
    } finally {
      socket?.close();
    }
  }

  String? _parseNetbiosName(List<int> data) {
    try {
      // NetBIOS response: names start at offset 57
      if (data.length < 57) return null;
      final numNames = data[56];
      if (numNames == 0) return null;

      // Each name entry is 18 bytes: 15 chars + type + flags(2)
      final nameBytes = data.skip(57).take(15).toList();
      final name = String.fromCharCodes(nameBytes)
          .replaceAll('\x00', '')
          .trim();

      return name.isNotEmpty ? name : null;
    } catch (_) {
      return null;
    }
  }
}
