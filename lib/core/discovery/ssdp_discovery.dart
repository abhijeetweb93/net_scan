import 'dart:async';
import 'dart:io';
import 'package:wifi_scanner/core/utils/app_logger.dart';

class SsdpDevice {
  final String ip;
  final String? location;
  final String? server;
  final String? usn;
  final String? st;
  final String? friendlyName;
  final String? manufacturer;
  final String? modelName;

  const SsdpDevice({
    required this.ip,
    this.location,
    this.server,
    this.usn,
    this.st,
    this.friendlyName,
    this.manufacturer,
    this.modelName,
  });
}

/// SSDP (Simple Service Discovery Protocol) / UPnP device discovery
class SsdpDiscovery {
  static const _ssdpAddress = '239.255.255.250';
  static const _ssdpPort = 1900;
  static const Duration _defaultTimeout = Duration(seconds: 5);

  bool _cancelled = false;
  RawDatagramSocket? _socket;

  void cancel() {
    _cancelled = true;
    _socket?.close();
  }

  void reset() => _cancelled = false;

  static const String _msearchAll = 'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 3\r\n'
      'ST: ssdp:all\r\n'
      '\r\n';

  static const String _msearchRootDevice = 'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 3\r\n'
      'ST: upnp:rootdevice\r\n'
      '\r\n';

  /// Discover SSDP/UPnP devices on the local network
  Stream<SsdpDevice> discover({
    Duration timeout = _defaultTimeout,
  }) async* {
    _cancelled = false;
    final controller = StreamController<SsdpDevice>.broadcast();
    final discovered = <String>{};

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      ).timeout(const Duration(seconds: 3));

      AppLogger.info('SSDP discovery started');

      final msearchBytes = _msearchAll.codeUnits;
      final msearchRootBytes = _msearchRootDevice.codeUnits;

      _socket!.send(
        msearchBytes,
        InternetAddress(_ssdpAddress),
        _ssdpPort,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      _socket!.send(
        msearchRootBytes,
        InternetAddress(_ssdpAddress),
        _ssdpPort,
      );

      _socket!.listen((event) {
        if (event == RawSocketEvent.read && !_cancelled) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            try {
              final response = String.fromCharCodes(datagram.data);
              final ip = datagram.address.address;
              final device = _parseSsdpResponse(response, ip);
              if (device != null) {
                final key = '${device.ip}-${device.usn ?? device.location}';
                if (!discovered.contains(key)) {
                  discovered.add(key);
                  if (!controller.isClosed) controller.add(device);
                }
              }
            } catch (e) {
              AppLogger.debug('SSDP parse error: $e');
            }
          }
        }
      });

      Timer(timeout, () {
        if (!controller.isClosed) controller.close();
        _socket?.close();
      });
    } catch (e) {
      AppLogger.warning('SSDP discovery setup error: $e');
      if (!controller.isClosed) controller.close();
    }

    yield* controller.stream;
  }

  SsdpDevice? _parseSsdpResponse(String response, String ip) {
    if (!response.startsWith('HTTP') && !response.startsWith('NOTIFY')) {
      return null;
    }

    final headers = <String, String>{};
    for (final line in response.split('\r\n')) {
      final idx = line.indexOf(':');
      if (idx > 0) {
        final key = line.substring(0, idx).trim().toLowerCase();
        final value = line.substring(idx + 1).trim();
        headers[key] = value;
      }
    }

    return SsdpDevice(
      ip: ip,
      location: headers['location'],
      server: headers['server'],
      usn: headers['usn'],
      st: headers['st'],
    );
  }

  /// Fetch UPnP device description XML for more details
  Future<SsdpDevice?> enrichDevice(SsdpDevice device) async {
    if (device.location == null) return device;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      
      final request = await client
          .getUrl(Uri.parse(device.location!))
          .timeout(const Duration(seconds: 3));
      
      final response = await request.close().timeout(const Duration(seconds: 3));
      final body = await response.transform(const SystemEncoding().decoder).join()
          .timeout(const Duration(seconds: 3));
      
      client.close();

      final friendlyName = _extractXmlTag(body, 'friendlyName');
      final manufacturer = _extractXmlTag(body, 'manufacturer');
      final modelName = _extractXmlTag(body, 'modelName');

      return SsdpDevice(
        ip: device.ip,
        location: device.location,
        server: device.server,
        usn: device.usn,
        st: device.st,
        friendlyName: friendlyName,
        manufacturer: manufacturer,
        modelName: modelName,
      );
    } catch (e) {
      AppLogger.debug('UPnP enrichment error for ${device.ip}: $e');
      return device;
    }
  }

  String? _extractXmlTag(String xml, String tag) {
    final match = RegExp('<$tag>([^<]+)</$tag>').firstMatch(xml);
    return match?.group(1)?.trim();
  }
}
