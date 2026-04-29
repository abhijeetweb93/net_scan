import 'package:equatable/equatable.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/domain/models/scan_result.dart';

abstract class ScannerState extends Equatable {
  const ScannerState();
  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {
  const ScannerInitial();
}

class ScannerLoading extends ScannerState {
  const ScannerLoading();
}

class ScannerReady extends ScannerState {
  final NetworkInfo networkInfo;
  final ScanResult? cachedResult;
  const ScannerReady({required this.networkInfo, this.cachedResult});
  @override
  List<Object?> get props => [networkInfo, cachedResult];
}

class ScannerScanning extends ScannerState {
  final ScanProgress progress;
  final List<NetworkDevice> discoveredDevices;
  final NetworkInfo networkInfo;

  const ScannerScanning({
    required this.progress,
    required this.discoveredDevices,
    required this.networkInfo,
  });

  ScannerScanning copyWith({
    ScanProgress? progress,
    List<NetworkDevice>? discoveredDevices,
    NetworkInfo? networkInfo,
  }) {
    return ScannerScanning(
      progress: progress ?? this.progress,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      networkInfo: networkInfo ?? this.networkInfo,
    );
  }

  @override
  List<Object?> get props => [progress, discoveredDevices, networkInfo];
}

class ScannerCompleted extends ScannerState {
  final ScanResult result;
  const ScannerCompleted({required this.result});
  @override
  List<Object?> get props => [result];
}

class ScannerCancelled extends ScannerState {
  final List<NetworkDevice> partialDevices;
  final NetworkInfo? networkInfo;
  const ScannerCancelled({this.partialDevices = const [], this.networkInfo});
  @override
  List<Object?> get props => [partialDevices, networkInfo];
}

class ScannerError extends ScannerState {
  final String message;
  final NetworkInfo? networkInfo;
  const ScannerError({required this.message, this.networkInfo});
  @override
  List<Object?> get props => [message, networkInfo];
}

class PortScanningState extends ScannerState {
  final String targetIp;
  final List<OpenPort> openPorts;
  final bool isComplete;

  const PortScanningState({
    required this.targetIp,
    required this.openPorts,
    this.isComplete = false,
  });

  PortScanningState copyWith({
    String? targetIp,
    List<OpenPort>? openPorts,
    bool? isComplete,
  }) {
    return PortScanningState(
      targetIp: targetIp ?? this.targetIp,
      openPorts: openPorts ?? this.openPorts,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  @override
  List<Object?> get props => [targetIp, openPorts, isComplete];
}
