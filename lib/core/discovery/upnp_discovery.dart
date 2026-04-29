import 'dart:async';
import 'dart:io';
import 'package:wifi_scanner/core/utils/app_logger.dart';

class UpnpDevice {
  final String ip;
  final String? friendlyName;
  final String? manufacturer;
  final String? modelName;
  final String? modelNumber;
  final String? serialNumber;
  final String? udn;
  final String? deviceType;
  final String? presentationUrl;

  const UpnpDevice({
    required this.ip,
    this.friendlyName,
    this.manufacturer,
    this.modelName,
    this.modelNumber,
    this.serialNumber,
    this.udn,
    this.deviceType,
    this.presentationUrl,
  });
}

/// UPnP device description fetcher
/// Works alongside SSDP to enrich device information from XML descriptions
class UpnpDiscovery {
  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3)
    ..idleTimeout = const Duration(seconds: 5);

  bool _cancelled = false;

  void cancel() => _cancelled = true;
  void reset() => _cancelled = false;

  /// Fetch and parse UPnP device description XML from a location URL
  Future<UpnpDevice?> fetchDeviceDescription(
    String locationUrl,
    String ip,
  ) async {
    if (_cancelled) return null;

    try {
      final uri = Uri.parse(locationUrl);
      final request = await _httpClient
          .getUrl(uri)
          .timeout(const Duration(seconds: 3));

      request.headers.set('User-Agent', 'NetScan/1.0 UPnP/1.1');

      final response = await request.close().timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) return null;

      final body = await response
          .transform(const SystemEncoding().decoder)
          .join()
          .timeout(const Duration(seconds: 3));

      return _parseDeviceXml(body, ip);
    } catch (e) {
      AppLogger.debug('UPnP fetch error for $locationUrl: $e');
      return null;
    }
  }

  UpnpDevice? _parseDeviceXml(String xml, String ip) {
    try {
      // Strip XML namespaces for simpler parsing
      final cleaned = xml.replaceAll(RegExp(r'<[^>]+:'), '<').replaceAll(RegExp(r'</[^>]+:'), '</');

      String? extract(String tag) {
        final match = RegExp('<$tag>([^<]+)</$tag>',
                caseSensitive: false)
            .firstMatch(cleaned);
        return match?.group(1)?.trim();
      }

      final friendlyName = extract('friendlyName');
      final manufacturer = extract('manufacturer');
      final modelName = extract('modelName');
      final modelNumber = extract('modelNumber');
      final serialNumber = extract('serialNumber');
      final udn = extract('UDN');
      final deviceType = extract('deviceType');
      final presentationUrl = extract('presentationURL');

      if (friendlyName == null && manufacturer == null && modelName == null) {
        return null;
      }

      return UpnpDevice(
        ip: ip,
        friendlyName: friendlyName,
        manufacturer: manufacturer,
        modelName: modelName,
        modelNumber: modelNumber,
        serialNumber: serialNumber,
        udn: udn,
        deviceType: _normalizeDeviceType(deviceType),
        presentationUrl: presentationUrl,
      );
    } catch (e) {
      AppLogger.debug('UPnP XML parse error: $e');
      return null;
    }
  }

  String? _normalizeDeviceType(String? raw) {
    if (raw == null) return null;
    // UPnP device types look like: urn:schemas-upnp-org:device:MediaRenderer:1
    final parts = raw.split(':');
    if (parts.length >= 4) return parts[parts.length - 2];
    return raw;
  }

  /// Guess device category from UPnP device type string
  static String? friendlyDeviceType(String? upnpType) {
    if (upnpType == null) return null;
    final t = upnpType.toLowerCase();
    if (t.contains('mediarenderer')) return 'Media Renderer';
    if (t.contains('mediaserver')) return 'Media Server';
    if (t.contains('internetgateway')) return 'Internet Gateway';
    if (t.contains('wlanaccess')) return 'WiFi Access Point';
    if (t.contains('printer')) return 'Printer';
    if (t.contains('scanner')) return 'Scanner';
    if (t.contains('camera')) return 'Network Camera';
    if (t.contains('tv')) return 'Smart TV';
    if (t.contains('speaker')) return 'Smart Speaker';
    if (t.contains('switch')) return 'Network Switch';
    return upnpType;
  }
}
