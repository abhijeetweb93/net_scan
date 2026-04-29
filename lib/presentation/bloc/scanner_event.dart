import 'package:equatable/equatable.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/domain/models/scan_result.dart';
import 'package:wifi_scanner/domain/repositories/scanner_repository.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();
  @override
  List<Object?> get props => [];
}

class InitializeScanner extends ScannerEvent {
  const InitializeScanner();
}

class StartScan extends ScannerEvent {
  final ScanOptions? options;
  const StartScan({this.options});
  @override
  List<Object?> get props => [options];
}

class StopScan extends ScannerEvent {
  const StopScan();
}

class RefreshNetwork extends ScannerEvent {
  final ScanOptions? options;
  const RefreshNetwork({this.options});
  @override
  List<Object?> get props => [options];
}

class ScanPorts extends ScannerEvent {
  final String ip;
  final List<int>? ports;
  const ScanPorts({required this.ip, this.ports});
  @override
  List<Object?> get props => [ip, ports];
}

// Internal events — public so add() works across async boundaries
class ScanProgressReceived extends ScannerEvent {
  final ScanProgress progress;
  const ScanProgressReceived(this.progress);
  @override
  List<Object?> get props => [progress];
}

class DeviceDiscoveredEvent extends ScannerEvent {
  final NetworkDevice device;
  const DeviceDiscoveredEvent(this.device);
  @override
  List<Object?> get props => [device];
}

class ScanCompletedEvent extends ScannerEvent {
  final ScanResult result;
  const ScanCompletedEvent(this.result);
  @override
  List<Object?> get props => [result];
}

class ScanFailedEvent extends ScannerEvent {
  final String message;
  const ScanFailedEvent(this.message);
  @override
  List<Object?> get props => [message];
}
