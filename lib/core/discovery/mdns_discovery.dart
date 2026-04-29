import 'dart:async';
import 'dart:io';
import 'package:wifi_scanner/core/utils/app_logger.dart';

class MdnsDevice {
  final String ip;
  final String name;
  final String serviceType;
  final int? port;
  final Map<String, String> attributes;

  const MdnsDevice({
    required this.ip,
    required this.name,
    required this.serviceType,
    this.port,
    this.attributes = const {},
  });
}

/// mDNS/Bonjour device discovery
/// Listens on 224.0.0.251:5353 for mDNS announcements
class MdnsDiscovery {
  static const _mdnsAddress = '224.0.0.251';
  static const _mdnsPort = 5353;
  static const Duration _defaultTimeout = Duration(seconds: 5);

  bool _cancelled = false;
  RawDatagramSocket? _socket;

  void cancel() {
    _cancelled = true;
    _socket?.close();
  }

  void reset() => _cancelled = false;

  /// Discover mDNS services on the local network
  Stream<MdnsDevice> discover({
    Duration timeout = _defaultTimeout,
    List<String> serviceTypes = const [
      '_http._tcp.local',
      '_https._tcp.local',
      '_ssh._tcp.local',
      '_sftp-ssh._tcp.local',
      '_ftp._tcp.local',
      '_smb._tcp.local',
      '_afp._tcp.local',
      '_printer._tcp.local',
      '_ipp._tcp.local',
      '_ipps._tcp.local',
      '_scanner._tcp.local',
      '_airplay._tcp.local',
      '_raop._tcp.local',
      '_googlecast._tcp.local',
      '_spotify-connect._tcp.local',
      '_hap._tcp.local',
      '_homekit._tcp.local',
      '_matter._tcp.local',
      '_nvstream_dbd._tcp.local',
      '_workstation._tcp.local',
    ],
  }) async* {
    _cancelled = false;
    final controller = StreamController<MdnsDevice>.broadcast();
    final discovered = <String>{};

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _mdnsPort,
        reusePort: true,
      ).timeout(const Duration(seconds: 3));

      _socket!.joinMulticast(InternetAddress(_mdnsAddress));
      _socket!.broadcastEnabled = true;

      AppLogger.info('mDNS discovery started');

      // Send queries for each service type
      for (final serviceType in serviceTypes) {
        if (_cancelled) break;
        final query = _buildMdnsQuery(serviceType);
        _socket!.send(
          query,
          InternetAddress(_mdnsAddress),
          _mdnsPort,
        );
      }

      // Also send PTR query for all services
      _socket!.send(
        _buildMdnsQuery('_services._dns-sd._udp.local'),
        InternetAddress(_mdnsAddress),
        _mdnsPort,
      );

      _socket!.listen((event) {
        if (event == RawSocketEvent.read && !_cancelled) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            try {
              final devices = _parseMdnsResponse(datagram.data);
              for (final device in devices) {
                final key = '${device.ip}-${device.name}';
                if (!discovered.contains(key)) {
                  discovered.add(key);
                  if (!controller.isClosed) controller.add(device);
                }
              }
            } catch (e) {
              AppLogger.debug('mDNS parse error: $e');
            }
          }
        }
      });

      Timer(timeout, () {
        if (!controller.isClosed) controller.close();
        _socket?.close();
      });
    } catch (e) {
      AppLogger.warning('mDNS discovery setup error: $e');
      if (!controller.isClosed) controller.close();
    }

    yield* controller.stream;
  }

  List<int> _buildMdnsQuery(String serviceName) {
    final labels = serviceName.split('.');
    final buffer = <int>[];

    // Header: transaction ID, flags, questions
    buffer.addAll([0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);

    // Question: service name
    for (final label in labels) {
      final bytes = label.codeUnits;
      buffer.add(bytes.length);
      buffer.addAll(bytes);
    }
    buffer.add(0x00); // end of name

    // Type PTR (0x000C), Class IN (0x0001)
    buffer.addAll([0x00, 0x0C, 0x00, 0x01]);

    return buffer;
  }

  List<MdnsDevice> _parseMdnsResponse(List<int> data) {
    final devices = <MdnsDevice>[];
    // Simple mDNS response parser
    // In production, use the multicast_dns package for full parsing
    try {
      if (data.length < 12) return [];

      final questionCount = (data[4] << 8) | data[5];
      final answerCount = (data[6] << 8) | data[7];

      if (answerCount == 0) return [];

      // Extract IP from Additional Records section
      // This is a simplified parser — real apps use the multicast_dns package
      final ipMatches = RegExp(r'(\d+\.\d+\.\d+\.\d+)')
          .allMatches(String.fromCharCodes(data.where((b) => b >= 32 && b < 127).toList()));

      String? extractedIp;
      for (final match in ipMatches) {
        final ip = match.group(1)!;
        if (_isValidLocalIp(ip)) {
          extractedIp = ip;
          break;
        }
      }

      // Extract hostname from readable bytes
      final readable = String.fromCharCodes(
        data.where((b) => b >= 32 && b < 127).toList(),
      );

      final hostMatch = RegExp(r'([a-zA-Z0-9\-]+)\.local').firstMatch(readable);
      final name = hostMatch?.group(0) ?? '';

      if (extractedIp != null && name.isNotEmpty) {
        devices.add(MdnsDevice(
          ip: extractedIp,
          name: name,
          serviceType: 'mDNS',
          attributes: {},
        ));
      }
    } catch (e) {
      AppLogger.debug('mDNS parse error: $e');
    }
    return devices;
  }

  bool _isValidLocalIp(String ip) {
    if (!RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(ip)) return false;
    final parts = ip.split('.');
    final first = int.tryParse(parts[0]) ?? 0;
    return first == 192 || first == 10 || first == 172;
  }
}
