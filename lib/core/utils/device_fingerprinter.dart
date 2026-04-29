import 'package:wifi_scanner/domain/models/network_device.dart';

/// Heuristic device type detection based on available signals
class DeviceFingerprinter {
  DeviceFingerprinter._();

  static DeviceType fingerprint({
    String? vendor,
    String? hostname,
    String? mdnsName,
    String? ssdpDescription,
    List<int>? openPorts,
    bool isGateway = false,
  }) {
    if (isGateway) return DeviceType.router;

    final signals = [
      vendor?.toLowerCase() ?? '',
      hostname?.toLowerCase() ?? '',
      mdnsName?.toLowerCase() ?? '',
      ssdpDescription?.toLowerCase() ?? '',
    ].join(' ');

    final ports = openPorts ?? [];

    // Router / Network gear
    if (_matchesAny(signals, [
      'router', 'gateway', 'netgear', 'asus rt', 'tp-link', 'linksys',
      'cisco', 'd-link', 'mikrotik', 'ubiquiti', 'unifi', 'openwrt',
      'ddwrt', 'pfsense', 'fritzbox', 'zyxel', 'huawei', 'technicolor',
    ])) {
      return DeviceType.router;
    }

    // Smart TV
    if (_matchesAny(signals, [
      'samsung smart tv', 'lg smart tv', 'sony bravia', 'vizio smart',
      'roku', 'firetv', 'chromecast', 'apple tv', 'shield', 'smarttv',
      'androidtv', 'webos', 'tizen', 'youtube tv',
    ])) {
      return DeviceType.smartTv;
    }

    // Printer
    if (_matchesAny(signals, [
      'printer', 'hp laserjet', 'hp deskjet', 'epson', 'canon pixma',
      'brother', 'xerox', 'kyocera', 'lexmark', 'ricoh',
    ]) || ports.contains(9100) || ports.contains(631)) {
      return DeviceType.printer;
    }

    // Gaming console
    if (_matchesAny(signals, [
      'playstation', 'ps4', 'ps5', 'xbox', 'nintendo', 'switch',
      'steam deck', 'gaming',
    ])) {
      return DeviceType.gamingConsole;
    }

    // Network camera
    if (_matchesAny(signals, [
      'camera', 'ipcam', 'hikvision', 'dahua', 'axis', 'foscam',
      'reolink', 'ring', 'nest cam', 'arlo', 'wyze',
    ]) || ports.contains(554)) {
      return DeviceType.networkCamera;
    }

    // Smart speaker / assistant
    if (_matchesAny(signals, [
      'echo', 'alexa', 'google home', 'nest audio', 'homepod',
      'sonos', 'bose soundtouch', 'smart speaker',
    ])) {
      return DeviceType.smartSpeaker;
    }

    // IoT / Smart home
    if (_matchesAny(signals, [
      'esp', 'arduino', 'raspberry pi', 'tasmota', 'shelly',
      'philips hue', 'lifx', 'wemo', 'smartthings', 'zigbee',
      'zwave', 'homekit', 'tuya', 'sonoff',
    ])) {
      return DeviceType.iotDevice;
    }

    // Apple devices
    if (_matchesAny(signals, ['apple', 'iphone', 'ipad'])) {
      if (signals.contains('ipad')) return DeviceType.tablet;
      if (signals.contains('iphone')) return DeviceType.smartphone;
      // macbook
      if (signals.contains('macbook') || signals.contains('mac pro') ||
          signals.contains('imac')) {
        return DeviceType.laptop;
      }
    }

    // Android phones
    if (_matchesAny(signals, [
      'android', 'samsung galaxy', 'pixel', 'oneplus', 'xiaomi',
      'huawei p', 'oppo', 'vivo', 'motorola',
    ])) {
      return DeviceType.smartphone;
    }

    // Laptops / Desktops by hostname patterns
    if (_matchesAny(signals, [
      'macbook', 'thinkpad', 'latitude', 'inspiron', 'elitebook',
      'surface', 'xps', 'chromebook', 'laptop', 'notebook',
    ])) {
      return DeviceType.laptop;
    }

    if (_matchesAny(signals, [
      'desktop', 'workstation', 'pc-', '-pc', 'imac',
      'dell optiplex', 'hp pavilion', 'lenovo ideacentre',
    ])) {
      return DeviceType.desktop;
    }

    // Open ports heuristics
    if (ports.contains(3389)) return DeviceType.desktop; // RDP = Windows
    if (ports.contains(5900)) return DeviceType.desktop; // VNC
    if (ports.contains(22) && !ports.contains(80)) return DeviceType.laptop;

    return DeviceType.unknown;
  }

  static bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }
}

/// Known vendor prefixes for common manufacturers
class VendorHints {
  VendorHints._();

  static const Map<String, DeviceType> vendorDeviceHints = {
    'apple': DeviceType.smartphone,
    'samsung electronics': DeviceType.smartphone,
    'intel corporate': DeviceType.laptop,
    'tp-link': DeviceType.router,
    'netgear': DeviceType.router,
    'cisco': DeviceType.router,
    'ubiquiti': DeviceType.router,
    'sonos': DeviceType.smartSpeaker,
    'amazon technologies': DeviceType.smartSpeaker,
    'google': DeviceType.iotDevice,
    'espressif': DeviceType.iotDevice,
    'raspberry pi': DeviceType.iotDevice,
    'canon': DeviceType.printer,
    'epson': DeviceType.printer,
    'hp inc': DeviceType.printer,
    'sony': DeviceType.gamingConsole,
    'microsoft': DeviceType.gamingConsole,
    'nintendo': DeviceType.gamingConsole,
  };

  static DeviceType? hintFromVendor(String? vendor) {
    if (vendor == null) return null;
    final lower = vendor.toLowerCase();
    for (final entry in vendorDeviceHints.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }
}
