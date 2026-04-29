import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_scanner/core/utils/ip_utils.dart';
import 'package:wifi_scanner/core/utils/device_fingerprinter.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';

void main() {
  group('IpUtils', () {
    test('ipToInt converts correctly', () {
      expect(IpUtils.ipToInt('192.168.1.1'), equals(0xC0A80101));
      expect(IpUtils.ipToInt('10.0.0.1'), equals(0x0A000001));
    });

    test('intToIp converts correctly', () {
      expect(IpUtils.intToIp(0xC0A80101), equals('192.168.1.1'));
      expect(IpUtils.intToIp(0x0A000001), equals('10.0.0.1'));
    });

    test('getSubnetHosts returns 254 IPs', () {
      final hosts = IpUtils.getSubnetHosts('192.168.1.100');
      expect(hosts.length, equals(254));
      expect(hosts.first, equals('192.168.1.1'));
      expect(hosts.last, equals('192.168.1.254'));
    });

    test('guessGateway returns .1 address', () {
      expect(IpUtils.guessGateway('192.168.1.100'), equals('192.168.1.1'));
      expect(IpUtils.guessGateway('10.0.0.55'), equals('10.0.0.1'));
    });

    test('isValidIpv4 validates correctly', () {
      expect(IpUtils.isValidIpv4('192.168.1.1'), isTrue);
      expect(IpUtils.isValidIpv4('256.0.0.1'), isFalse);
      expect(IpUtils.isValidIpv4('not.an.ip'), isFalse);
      expect(IpUtils.isValidIpv4('10.0.0.1'), isTrue);
    });

    test('extractOui returns correct prefix', () {
      expect(IpUtils.extractOui('AA:BB:CC:DD:EE:FF'), equals('AABBCC'));
      expect(IpUtils.extractOui('aa-bb-cc-dd-ee-ff'), equals('AABBCC'));
      expect(IpUtils.extractOui(null), isNull);
      expect(IpUtils.extractOui(''), isNull);
    });

    test('formatMac returns uppercase colon-separated MAC', () {
      expect(IpUtils.formatMac('aabbccddeeff'), equals('AA:BB:CC:DD:EE:FF'));
      expect(IpUtils.formatMac('AABBCCDDEEFF'), equals('AA:BB:CC:DD:EE:FF'));
    });

    test('sameSubnet detects /24 match', () {
      expect(IpUtils.sameSubnet('192.168.1.1', '192.168.1.100'), isTrue);
      expect(IpUtils.sameSubnet('192.168.1.1', '192.168.2.1'), isFalse);
      expect(IpUtils.sameSubnet('10.0.0.1', '10.0.0.100'), isTrue);
    });

    test('getBroadcast returns .255 address', () {
      expect(IpUtils.getBroadcast('192.168.1.1'), equals('192.168.1.255'));
    });
  });

  group('PortServices', () {
    test('returns service name for well-known ports', () {
      expect(PortServices.getService(80), equals('HTTP'));
      expect(PortServices.getService(443), equals('HTTPS'));
      expect(PortServices.getService(22), equals('SSH'));
      expect(PortServices.getService(3389), equals('RDP'));
    });

    test('returns null for unknown ports', () {
      expect(PortServices.getService(12345), isNull);
    });
  });

  group('DeviceFingerprinter', () {
    test('identifies router from vendor string', () {
      final type = DeviceFingerprinter.fingerprint(vendor: 'TP-Link Technologies');
      expect(type, equals(DeviceType.router));
    });

    test('identifies gateway flag as router', () {
      final type = DeviceFingerprinter.fingerprint(isGateway: true);
      expect(type, equals(DeviceType.router));
    });

    test('identifies printer from port 9100', () {
      final type = DeviceFingerprinter.fingerprint(openPorts: [9100]);
      expect(type, equals(DeviceType.printer));
    });

    test('identifies smart TV from mDNS name', () {
      final type =
          DeviceFingerprinter.fingerprint(mdnsName: 'Samsung Smart TV');
      expect(type, equals(DeviceType.smartTv));
    });

    test('identifies IoT from vendor Espressif', () {
      final type = DeviceFingerprinter.fingerprint(vendor: 'Espressif Inc.');
      expect(type, equals(DeviceType.iotDevice));
    });

    test('returns unknown for unrecognized device', () {
      final type = DeviceFingerprinter.fingerprint(
        vendor: 'Unknown Corp XYZ',
        hostname: 'device-xyz',
      );
      expect(type, equals(DeviceType.unknown));
    });
  });

  group('NetworkDevice', () {
    final device1 = NetworkDevice(
      ip: '192.168.1.1',
      macAddress: 'AA:BB:CC:DD:EE:FF',
      hostname: null,
      vendor: 'TP-Link',
      lastSeen: DateTime(2024, 1, 1),
      status: DeviceStatus.online,
    );

    final device2 = NetworkDevice(
      ip: '192.168.1.1',
      macAddress: null,
      hostname: 'router.local',
      vendor: null,
      latency: 5,
      lastSeen: DateTime(2024, 1, 2), // later
      status: DeviceStatus.online,
    );

    test('mergeWith combines non-null fields correctly', () {
      final merged = device1.mergeWith(device2);

      expect(merged.ip, equals('192.168.1.1'));
      expect(merged.macAddress, equals('AA:BB:CC:DD:EE:FF')); // from device1
      expect(merged.hostname, equals('router.local')); // from device2
      expect(merged.vendor, equals('TP-Link')); // from device1
      expect(merged.latency, equals(5)); // from device2
      expect(merged.lastSeen, equals(DateTime(2024, 1, 2))); // most recent
    });

    test('displayName prefers hostname over IP', () {
      expect(device2.displayName, equals('router.local'));
      final noName = NetworkDevice(
        ip: '192.168.1.50',
        lastSeen: DateTime.now(),
        status: DeviceStatus.unknown,
      );
      expect(noName.displayName, equals('192.168.1.50'));
    });
  });
}
