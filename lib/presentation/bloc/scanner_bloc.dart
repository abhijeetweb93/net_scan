import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/domain/models/scan_result.dart';
import 'package:wifi_scanner/domain/repositories/scanner_repository.dart';
import 'package:wifi_scanner/domain/usecases/scanner_usecases.dart';
import 'package:wifi_scanner/core/utils/app_logger.dart';
import 'package:wifi_scanner/core/utils/failures.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_event.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final StartNetworkScanUseCase _startNetworkScan;
  final StopNetworkScanUseCase _stopNetworkScan;
  final GetNetworkInfoUseCase _getNetworkInfo;
  final ScanDevicePortsUseCase _scanDevicePorts;
  final GetLastScanResultUseCase _getLastScanResult;

  StreamSubscription? _scanSubscription;
  NetworkInfo? _currentNetworkInfo;

  // Accumulate devices here so they survive state transitions
  final Map<String, NetworkDevice> _devices = {};

  ScannerBloc({
    required StartNetworkScanUseCase startNetworkScan,
    required StopNetworkScanUseCase stopNetworkScan,
    required GetNetworkInfoUseCase getNetworkInfo,
    required ScanDevicePortsUseCase scanDevicePorts,
    required GetLastScanResultUseCase getLastScanResult,
  })  : _startNetworkScan = startNetworkScan,
        _stopNetworkScan = stopNetworkScan,
        _getNetworkInfo = getNetworkInfo,
        _scanDevicePorts = scanDevicePorts,
        _getLastScanResult = getLastScanResult,
        super(const ScannerInitial()) {
    on<InitializeScanner>(_onInitialize);
    on<StartScan>(_onStartScan);
    on<StopScan>(_onStopScan);
    on<RefreshNetwork>(_onRefreshNetwork);
    on<ScanPorts>(_onScanPorts);
    on<ScanProgressReceived>(_onProgress);
    on<DeviceDiscoveredEvent>(_onDeviceDiscovered);
    on<ScanCompletedEvent>(_onScanCompleted);
    on<ScanFailedEvent>(_onScanFailed);
  }

  Future<void> _onInitialize(
    InitializeScanner event,
    Emitter<ScannerState> emit,
  ) async {
    emit(const ScannerLoading());
    final result = await _getNetworkInfo();
    await result.fold(
      (failure) async => emit(ScannerError(message: failure.message)),
      (networkInfo) async {
        _currentNetworkInfo = networkInfo;
        final cached = await _getLastScanResult();
        emit(ScannerReady(
          networkInfo: networkInfo,
          cachedResult: cached.fold((_) => null, (r) => r),
        ));
      },
    );
  }

  Future<void> _onStartScan(
    StartScan event,
    Emitter<ScannerState> emit,
  ) async {
    // Get network info if we don't have it
    if (_currentNetworkInfo == null) {
      final result = await _getNetworkInfo();
      result.fold(
        (f) => emit(ScannerError(message: f.message)),
        (info) => _currentNetworkInfo = info,
      );
      if (_currentNetworkInfo == null) return;
    }

    // Cancel any previous scan
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _devices.clear();

    emit(ScannerScanning(
      progress: const ScanProgress(
        scannedCount: 0,
        totalCount: 254,
        devicesFound: 0,
        currentIp: 'Starting scan...',
        elapsed: Duration.zero,
      ),
      discoveredDevices: const [],
      networkInfo: _currentNetworkInfo!,
    ));

    AppLogger.info('ScannerBloc: scan started');

    // Use emit.forEach to properly handle the stream within the BLoC
    // This is the correct BLoC pattern for streams
    final stream = _startNetworkScan(
      networkInfo: _currentNetworkInfo!,
      options: event.options,
    );

    _scanSubscription = stream.listen(
      (either) {
        if (isClosed) return;
        either.fold(
          (failure) {
            AppLogger.warning('Scan stream failure: ${failure.message}');
            if (failure is ScanCancelledFailure) {
              add(const StopScan());
            } else {
              add(ScanFailedEvent(failure.message));
            }
          },
          (scanEvent) {
            if (scanEvent is ScanProgressEvent) {
              add(ScanProgressReceived(scanEvent.progress));
            } else if (scanEvent is DeviceDiscoveredScanEvent) {
              add(DeviceDiscoveredEvent(scanEvent.device));
            } else if (scanEvent is ScanCompletedScanEvent) {
              add(ScanCompletedEvent(scanEvent.result));
            }
          },
        );
      },
      onError: (e) {
        if (!isClosed) add(ScanFailedEvent(e.toString()));
      },
      onDone: () {
        AppLogger.info('ScannerBloc: stream done');
      },
    );
  }

  Future<void> _onStopScan(
    StopScan event,
    Emitter<ScannerState> emit,
  ) async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _stopNetworkScan();
    emit(ScannerCancelled(
      partialDevices: _devices.values.toList(),
      networkInfo: _currentNetworkInfo,
    ));
  }

  Future<void> _onRefreshNetwork(
    RefreshNetwork event,
    Emitter<ScannerState> emit,
  ) async {
    final result = await _getNetworkInfo();
    result.fold(
      (f) => emit(ScannerError(message: f.message)),
      (info) => _currentNetworkInfo = info,
    );
    add(StartScan(options: event.options));
  }

  void _onProgress(
    ScanProgressReceived event,
    Emitter<ScannerState> emit,
  ) {
    if (state is ScannerScanning) {
      emit((state as ScannerScanning).copyWith(
        progress: event.progress,
        discoveredDevices: _sortedDevices(),
      ));
    }
  }

  void _onDeviceDiscovered(
    DeviceDiscoveredEvent event,
    Emitter<ScannerState> emit,
  ) {
    _devices[event.device.ip] = event.device;
    AppLogger.debug(
        'Device discovered: ${event.device.ip} — total: ${_devices.length}');

    // Always emit new state regardless of current state type
    // This ensures devices appear even if progress events are missed
    if (state is ScannerScanning) {
      emit((state as ScannerScanning).copyWith(
        discoveredDevices: _sortedDevices(),
      ));
    } else if (state is ScannerCompleted) {
      // Update completed state with enriched device data
      final current = state as ScannerCompleted;
      final updatedDevices = List<NetworkDevice>.from(current.result.devices);
      final idx = updatedDevices.indexWhere((d) => d.ip == event.device.ip);
      if (idx >= 0) {
        updatedDevices[idx] = event.device;
      } else {
        updatedDevices.add(event.device);
      }
      emit(ScannerCompleted(
        result: ScanResult(
          devices: updatedDevices,
          networkInfo: current.result.networkInfo,
          scanDuration: current.result.scanDuration,
          completedAt: current.result.completedAt,
          status: current.result.status,
        ),
      ));
    }
  }

  void _onScanCompleted(
    ScanCompletedEvent event,
    Emitter<ScannerState> emit,
  ) {
    AppLogger.info(
        'ScannerBloc: completed — ${event.result.devices.length} devices');
    // Merge accumulated devices with result in case any arrived late
    final merged = <String, NetworkDevice>{};
    for (final d in event.result.devices) {
      merged[d.ip] = d;
    }
    for (final d in _devices.values) {
      merged[d.ip] = merged[d.ip]?.mergeWith(d) ?? d;
    }
    final finalDevices = merged.values.toList()
      ..sort((a, b) => _ipLastOctet(a.ip).compareTo(_ipLastOctet(b.ip)));

    emit(ScannerCompleted(
      result: ScanResult(
        devices: finalDevices,
        networkInfo: event.result.networkInfo,
        scanDuration: event.result.scanDuration,
        completedAt: event.result.completedAt,
        status: event.result.status,
      ),
    ));
  }

  void _onScanFailed(
    ScanFailedEvent event,
    Emitter<ScannerState> emit,
  ) {
    AppLogger.error('ScannerBloc: failed — ${event.message}');
    // If we already found some devices, show them rather than an error
    if (_devices.isNotEmpty) {
      emit(ScannerCancelled(
        partialDevices: _sortedDevices(),
        networkInfo: _currentNetworkInfo,
      ));
    } else {
      emit(ScannerError(
        message: event.message,
        networkInfo: _currentNetworkInfo,
      ));
    }
  }

  Future<void> _onScanPorts(
    ScanPorts event,
    Emitter<ScannerState> emit,
  ) async {
    final openPorts = <OpenPort>[];
    emit(PortScanningState(
        targetIp: event.ip, openPorts: const []));

    await emit.forEach<Either<Failure, OpenPort>>(
      _scanDevicePorts(ip: event.ip, ports: event.ports),
      onData: (either) {
        return either.fold(
          (_) => PortScanningState(
              targetIp: event.ip, openPorts: openPorts, isComplete: true),
          (port) {
            openPorts.add(port);
            return PortScanningState(
                targetIp: event.ip,
                openPorts: List.from(openPorts));
          },
        );
      },
      onError: (_, __) => PortScanningState(
          targetIp: event.ip, openPorts: openPorts, isComplete: true),
    );

    emit(PortScanningState(
        targetIp: event.ip, openPorts: openPorts, isComplete: true));
  }

  List<NetworkDevice> _sortedDevices() {
    return _devices.values.toList()
      ..sort((a, b) => _ipLastOctet(a.ip).compareTo(_ipLastOctet(b.ip)));
  }

  int _ipLastOctet(String ip) {
    final parts = ip.split('.');
    return parts.length == 4 ? (int.tryParse(parts[3]) ?? 0) : 0;
  }

  @override
  Future<void> close() async {
    await _scanSubscription?.cancel();
    await _stopNetworkScan();
    return super.close();
  }
}
