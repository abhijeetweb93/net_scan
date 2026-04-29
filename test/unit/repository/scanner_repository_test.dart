import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wifi_scanner/core/network/arp_scanner.dart';
import 'package:wifi_scanner/core/network/port_scanner.dart';
import 'package:wifi_scanner/core/network/tcp_ping_scanner.dart';
import 'package:wifi_scanner/core/network/udp_scanner.dart';
import 'package:wifi_scanner/core/discovery/mdns_discovery.dart';
import 'package:wifi_scanner/core/discovery/ssdp_discovery.dart';
import 'package:wifi_scanner/data/datasources/network_info_datasource.dart';
import 'package:wifi_scanner/data/datasources/oui_datasource.dart';
import 'package:wifi_scanner/data/repositories/scanner_repository_impl.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/domain/models/scan_result.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockTcpPingScanner extends Mock implements TcpPingScanner {}
class MockArpScanner extends Mock implements ArpScanner {}
class MockUdpScanner extends Mock implements UdpScanner {}
class MockPortScanner extends Mock implements PortScanner {}
class MockMdnsDiscovery extends Mock implements MdnsDiscovery {}
class MockSsdpDiscovery extends Mock implements SsdpDiscovery {}
class MockOuiDatasource extends Mock implements OuiDatasource {}
class MockNetworkInfoDatasource extends Mock implements NetworkInfoDatasource {}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late ScannerRepositoryImpl repository;
  late MockTcpPingScanner mockTcp;
  late MockArpScanner mockArp;
  late MockUdpScanner mockUdp;
  late MockPortScanner mockPort;
  late MockMdnsDiscovery mockMdns;
  late MockSsdpDiscovery mockSsdp;
  late MockOuiDatasource mockOui;
  late MockNetworkInfoDatasource mockNetInfo;

  final testNetworkInfo = NetworkInfo(
    localIp: '192.168.1.100',
    subnetMask: '255.255.255.0',
    gateway: '192.168.1.1',
    subnet: '192.168.1.0',
    ssid: 'TestNet',
  );

  setUp(() {
    mockTcp = MockTcpPingScanner();
    mockArp = MockArpScanner();
    mockUdp = MockUdpScanner();
    mockPort = MockPortScanner();
    mockMdns = MockMdnsDiscovery();
    mockSsdp = MockSsdpDiscovery();
    mockOui = MockOuiDatasource();
    mockNetInfo = MockNetworkInfoDatasource();

    repository = ScannerRepositoryImpl(
      tcpScanner: mockTcp,
      arpScanner: mockArp,
      udpScanner: mockUdp,
      portScanner: mockPort,
      mdnsDiscovery: mockMdns,
      ssdpDiscovery: mockSsdp,
      ouiDatasource: mockOui,
      networkInfoDatasource: mockNetInfo,
    );
  });

  group('ScannerRepository — getNetworkInfo', () {
    test('returns Right(NetworkInfo) on success', () async {
      when(() => mockNetInfo.getNetworkInfo())
          .thenAnswer((_) async => testNetworkInfo);

      final result = await repository.getNetworkInfo();

      expect(result, isA<Right>());
      result.fold(
        (_) => fail('Expected Right'),
        (info) {
          expect(info.localIp, '192.168.1.100');
          expect(info.gateway, '192.168.1.1');
          expect(info.ssid, 'TestNet');
        },
      );
    });

    test('returns Left(Failure) on exception', () async {
      when(() => mockNetInfo.getNetworkInfo())
          .thenThrow(Exception('Network unavailable'));

      final result = await repository.getNetworkInfo();

      expect(result, isA<Left>());
    });
  });

  group('ScannerRepository — lookupVendor', () {
    test('returns vendor string for known OUI', () async {
      when(() => mockOui.lookupVendor('AA:BB:CC:DD:EE:FF'))
          .thenAnswer((_) async => 'Apple Inc.');

      final result = await repository.lookupVendor('AA:BB:CC:DD:EE:FF');

      expect(result, 'Apple Inc.');
    });

    test('returns null for unknown OUI', () async {
      when(() => mockOui.lookupVendor(any()))
          .thenAnswer((_) async => null);

      final result = await repository.lookupVendor('FF:FF:FF:FF:FF:FF');

      expect(result, isNull);
    });
  });

  group('ScannerRepository — startScan', () {
    test('emits DeviceDiscoveredEvent when ARP finds devices', () async {
      when(() => mockArp.readArpCache()).thenAnswer((_) async => [
            const ArpResult(
                ip: '192.168.1.1', macAddress: 'AA:BB:CC:DD:EE:FF', isReachable: true),
          ]);
      when(() => mockOui.lookupVendor(any())).thenAnswer((_) async => 'TP-Link');
      when(() => mockNetInfo.resolveHostname(any())).thenAnswer((_) async => 'router.local');
      when(() => mockTcp.reset()).thenReturn(null);
      when(() => mockTcp.scanSubnet(
            ips: any(named: 'ips'),
            timeout: any(named: 'timeout'),
            concurrency: any(named: 'concurrency'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) => const Stream.empty());
      when(() => mockMdns.discover()).thenAnswer((_) => const Stream.empty());
      when(() => mockSsdp.discover()).thenAnswer((_) => const Stream.empty());

      final events = <ScanEvent>[];
      await for (final either in repository.startScan(
          networkInfo: testNetworkInfo,
          options: const ScanOptions(
              enableArp: true,
              enableTcpPing: true,
              enableMdns: true,
              enableSsdp: true,
              enablePortScan: false))) {
        either.fold((_) {}, events.add);
      }

      final deviceEvents = events.whereType<DeviceDiscoveredEvent>().toList();
      expect(deviceEvents, isNotEmpty);
      expect(deviceEvents.first.device.ip, '192.168.1.1');
      expect(deviceEvents.first.device.vendor, 'TP-Link');
    });
  });
}
