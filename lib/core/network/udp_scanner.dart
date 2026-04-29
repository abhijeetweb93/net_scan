import 'dart:async';
import 'dart:io';
import 'package:wifi_scanner/core/utils/app_logger.dart';

class UdpDiscoveryResult {
  final String ip;
  final int port;
  final List<int> responseData;
  final String? serviceHint;

  const UdpDiscoveryResult({
    required this.ip,
    required this.port,
    required this.responseData,
    this.serviceHint,
  });
}

/// UDP-based device discovery
/// Probes well-known UDP ports to detect device presence
class UdpScanner {
  bool _cancelled = false;
  final List<RawDatagramSocket> _sockets = [];

  void cancel() {
    _cancelled = true;
    for (final s in _sockets) {
      try { s.close(); } catch (_) {}
    }
  }

  void reset() => _cancelled = false;

  /// Probe a single IP on a UDP port
  Future<UdpDiscoveryResult?> probePort(
    String ip,
    int port,
    List<int> payload, {
    Duration timeout = const Duration(milliseconds: 200),
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
          .timeout(timeout);
      _sockets.add(socket);

      socket.send(payload, InternetAddress(ip), port);

      final completer = Completer<UdpDiscoveryResult?>();
      Timer? timer;

      timer = Timer(timeout, () {
        if (!completer.isCompleted) completer.complete(null);
      });

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket!.receive();
          if (datagram != null && !completer.isCompleted) {
            timer?.cancel();
            completer.complete(UdpDiscoveryResult(
              ip: ip,
              port: port,
              responseData: datagram.data,
              serviceHint: _guessService(port),
            ));
          }
        }
      }, onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      });

      return await completer.future;
    } catch (e) {
      AppLogger.debug('UDP probe $ip:$port error: $e');
      return null;
    } finally {
      try {
        socket?.close();
        _sockets.remove(socket);
      } catch (_) {}
    }
  }

  /// Scan a list of IPs using common UDP discovery probes
  Stream<UdpDiscoveryResult> discoverDevices(
    List<String> ips, {
    int concurrency = 30,
  }) async* {
    _cancelled = false;
    final probes = _getDiscoveryProbes();

    for (final ip in ips) {
      if (_cancelled) break;

      for (final probe in probes) {
        if (_cancelled) break;
        final result = await probePort(
          ip,
          probe.port,
          probe.payload,
          timeout: const Duration(milliseconds: 150),
        );
        if (result != null) {
          yield result;
          break; // IP is alive, no need to probe more
        }
      }
    }
  }

  /// Probes common NetBIOS, NTP, DNS ports
  List<_UdpProbe> _getDiscoveryProbes() {
    return [
      // NetBIOS Name Service
      _UdpProbe(
        port: 137,
        payload: _buildNetbiosProbe(),
        hint: 'NetBIOS',
      ),
      // DNS
      _UdpProbe(
        port: 53,
        payload: _buildDnsProbe(),
        hint: 'DNS',
      ),
      // SNMP get-request
      _UdpProbe(
        port: 161,
        payload: _buildSnmpProbe(),
        hint: 'SNMP',
      ),
    ];
  }

  List<int> _buildNetbiosProbe() {
    return [
      0x82, 0x28, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x20, 0x43, 0x4b, 0x41,
      0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
      0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
      0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
      0x41, 0x41, 0x41, 0x41, 0x41, 0x00, 0x00, 0x21,
      0x00, 0x01,
    ];
  }

  List<int> _buildDnsProbe() {
    return [
      0xAB, 0xCD, // Transaction ID
      0x01, 0x00, // Standard query
      0x00, 0x01, // 1 question
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x01, 0x61, // query for 'a'
      0x0D, 0x72, 0x6F, 0x6F, 0x74, 0x2D, 0x73, 0x65,
      0x72, 0x76, 0x65, 0x72, 0x73, 0x02, 0x6E, 0x65,
      0x74, 0x00,
      0x00, 0x01, 0x00, 0x01,
    ];
  }

  List<int> _buildSnmpProbe() {
    // SNMP v1 get-request for sysDescr
    return [
      0x30, 0x26, 0x02, 0x01, 0x00, 0x04, 0x06, 0x70,
      0x75, 0x62, 0x6C, 0x69, 0x63, 0xA0, 0x19, 0x02,
      0x04, 0x71, 0xB4, 0xF4, 0x5C, 0x02, 0x01, 0x00,
      0x02, 0x01, 0x00, 0x30, 0x0B, 0x30, 0x09, 0x06,
      0x05, 0x2B, 0x06, 0x01, 0x02, 0x01, 0x05, 0x00,
    ];
  }

  String? _guessService(int port) {
    const services = {
      53: 'DNS',
      67: 'DHCP',
      68: 'DHCP Client',
      69: 'TFTP',
      123: 'NTP',
      137: 'NetBIOS-NS',
      138: 'NetBIOS-DGM',
      161: 'SNMP',
      162: 'SNMP Trap',
      514: 'Syslog',
      1900: 'SSDP/UPnP',
      5353: 'mDNS',
      5355: 'LLMNR',
    };
    return services[port];
  }
}

class _UdpProbe {
  final int port;
  final List<int> payload;
  final String? hint;

  const _UdpProbe({required this.port, required this.payload, this.hint});
}
