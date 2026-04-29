import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wifi_scanner/core/utils/failures.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/domain/models/scan_result.dart';
import 'package:wifi_scanner/domain/repositories/scanner_repository.dart';
import 'package:wifi_scanner/domain/usecases/scanner_usecases.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_bloc.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_event.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_state.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockStartNetworkScanUseCase extends Mock
    implements StartNetworkScanUseCase {}

class MockStopNetworkScanUseCase extends Mock
    implements StopNetworkScanUseCase {}

class MockGetNetworkInfoUseCase extends Mock implements GetNetworkInfoUseCase {}

class MockScanDevicePortsUseCase extends Mock
    implements ScanDevicePortsUseCase {}

class MockGetLastScanResultUseCase extends Mock
    implements GetLastScanResultUseCase {}

// ── Fixtures ─────────────────────────────────────────────────────────────────

final _testNetworkInfo = NetworkInfo(
  localIp: '192.168.1.100',
  subnetMask: '255.255.255.0',
  gateway: '192.168.1.1',
  subnet: '192.168.1.0',
  ssid: 'TestNet',
);

final _testDevice = NetworkDevice(
  ip: '192.168.1.1',
  hostname: 'router.local',
  vendor: 'TP-Link Technologies',
  isGateway: true,
  lastSeen: DateTime.now(),
  status: DeviceStatus.online,
  deviceType: DeviceType.router,
);

final _testScanResult = ScanResult(
  devices: [_testDevice],
  networkInfo: _testNetworkInfo,
  scanDuration: const Duration(seconds: 2),
  completedAt: DateTime.now(),
  status: ScanResultStatus.success,
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockStartNetworkScanUseCase mockStartScan;
  late MockStopNetworkScanUseCase mockStopScan;
  late MockGetNetworkInfoUseCase mockGetNetworkInfo;
  late MockScanDevicePortsUseCase mockScanPorts;
  late MockGetLastScanResultUseCase mockGetLastResult;

  setUp(() {
    mockStartScan = MockStartNetworkScanUseCase();
    mockStopScan = MockStopNetworkScanUseCase();
    mockGetNetworkInfo = MockGetNetworkInfoUseCase();
    mockScanPorts = MockScanDevicePortsUseCase();
    mockGetLastResult = MockGetLastScanResultUseCase();

    registerFallbackValue(_testNetworkInfo);
    registerFallbackValue(const ScanOptions());
  });

  ScannerBloc buildBloc() => ScannerBloc(
        startNetworkScan: mockStartScan,
        stopNetworkScan: mockStopScan,
        getNetworkInfo: mockGetNetworkInfo,
        scanDevicePorts: mockScanPorts,
        getLastScanResult: mockGetLastResult,
      );

  group('ScannerBloc — InitializeScanner', () {
    blocTest<ScannerBloc, ScannerState>(
      'emits [Loading, Ready] when network info loads successfully',
      build: buildBloc,
      setUp: () {
        when(() => mockGetNetworkInfo())
            .thenAnswer((_) async => Right(_testNetworkInfo));
        when(() => mockGetLastResult())
            .thenAnswer((_) async => const Right(null));
      },
      act: (bloc) => bloc.add(const InitializeScanner()),
      expect: () => [
        const ScannerLoading(),
        ScannerReady(networkInfo: _testNetworkInfo, cachedResult: null),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'emits [Loading, Error] when network info fails',
      build: buildBloc,
      setUp: () {
        when(() => mockGetNetworkInfo()).thenAnswer(
            (_) async => const Left(NoNetworkFailure()));
      },
      act: (bloc) => bloc.add(const InitializeScanner()),
      expect: () => [
        const ScannerLoading(),
        isA<ScannerError>(),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'emits [Loading, Ready] with cached result when available',
      build: buildBloc,
      setUp: () {
        when(() => mockGetNetworkInfo())
            .thenAnswer((_) async => Right(_testNetworkInfo));
        when(() => mockGetLastResult())
            .thenAnswer((_) async => Right(_testScanResult));
      },
      act: (bloc) => bloc.add(const InitializeScanner()),
      expect: () => [
        const ScannerLoading(),
        ScannerReady(
            networkInfo: _testNetworkInfo, cachedResult: _testScanResult),
      ],
    );
  });

  group('ScannerBloc — StartScan', () {
    blocTest<ScannerBloc, ScannerState>(
      'emits Scanning then Completed on successful scan stream',
      build: buildBloc,
      setUp: () {
        when(() => mockGetNetworkInfo())
            .thenAnswer((_) async => Right(_testNetworkInfo));
        when(() => mockGetLastResult())
            .thenAnswer((_) async => const Right(null));

        when(() => mockStartScan(
              networkInfo: any(named: 'networkInfo'),
              options: any(named: 'options'),
            )).thenAnswer((_) => Stream.fromIterable([
              Right<Failure, ScanEvent>(ScanProgressEvent(ScanProgress(
                scannedCount: 100,
                totalCount: 254,
                devicesFound: 1,
                currentIp: '192.168.1.50',
                elapsed: const Duration(seconds: 1),
              ))),
              Right<Failure, ScanEvent>(DeviceDiscoveredEvent(_testDevice)),
              Right<Failure, ScanEvent>(ScanCompletedEvent(_testScanResult)),
            ]));
      },
      act: (bloc) async {
        bloc.add(const InitializeScanner());
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(const StartScan());
      },
      expect: () => [
        const ScannerLoading(),
        isA<ScannerReady>(),
        isA<ScannerScanning>(), // initial scanning state
        isA<ScannerScanning>(), // progress update
        isA<ScannerScanning>(), // device discovered
        isA<ScannerCompleted>(), // done
      ],
    );
  });

  group('ScannerBloc — StopScan', () {
    blocTest<ScannerBloc, ScannerState>(
      'emits Cancelled state and calls stopNetworkScan',
      build: buildBloc,
      setUp: () {
        when(() => mockGetNetworkInfo())
            .thenAnswer((_) async => Right(_testNetworkInfo));
        when(() => mockGetLastResult())
            .thenAnswer((_) async => const Right(null));
        when(() => mockStartScan(
              networkInfo: any(named: 'networkInfo'),
              options: any(named: 'options'),
            )).thenAnswer((_) async* {
          await Future.delayed(const Duration(seconds: 5));
        });
        when(() => mockStopScan()).thenAnswer((_) async {});
      },
      act: (bloc) async {
        bloc.add(const InitializeScanner());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const StartScan());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const StopScan());
      },
      expect: () => [
        const ScannerLoading(),
        isA<ScannerReady>(),
        isA<ScannerScanning>(),
        isA<ScannerCancelled>(),
      ],
      verify: (_) => verify(() => mockStopScan()).called(1),
    );
  });

  group('ScannerBloc — ScanPorts', () {
    blocTest<ScannerBloc, ScannerState>(
      'emits PortScanningState with open ports',
      build: buildBloc,
      setUp: () {
        when(() => mockScanPorts(
              ip: any(named: 'ip'),
              ports: any(named: 'ports'),
            )).thenAnswer((_) => Stream.fromIterable([
              Right<Failure, OpenPort>(const OpenPort(
                port: 80,
                service: 'HTTP',
                isOpen: true,
              )),
              Right<Failure, OpenPort>(const OpenPort(
                port: 443,
                service: 'HTTPS',
                isOpen: true,
              )),
            ]));
      },
      act: (bloc) => bloc.add(const ScanPorts(ip: '192.168.1.1')),
      expect: () => [
        isA<PortScanningState>(),
        isA<PortScanningState>(),
        isA<PortScanningState>(),
      ],
    );
  });
}
