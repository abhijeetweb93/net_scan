import 'package:flutter/foundation.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_state.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/domain/models/scan_result.dart';

/// ViewModel that transforms BLoC states into UI-friendly data structures
/// Sits between the BLoC and UI — contains only presentation logic
class ScanScreenViewModel {
  final ScannerState state;

  const ScanScreenViewModel(this.state);

  // ── Derived booleans ───────────────────────────────────────────────────────

  bool get isInitializing => state is ScannerLoading || state is ScannerInitial;
  bool get isScanning => state is ScannerScanning;
  bool get isComplete => state is ScannerCompleted;
  bool get hasError => state is ScannerError;
  bool get isCancelled => state is ScannerCancelled;
  bool get isReady => state is ScannerReady;
  bool get canScan => !isScanning && !isInitializing;

  // ── Network info ───────────────────────────────────────────────────────────

  NetworkInfo? get networkInfo {
    if (state is ScannerScanning) return (state as ScannerScanning).networkInfo;
    if (state is ScannerCompleted) return (state as ScannerCompleted).result.networkInfo;
    if (state is ScannerReady) return (state as ScannerReady).networkInfo;
    if (state is ScannerCancelled) return (state as ScannerCancelled).networkInfo;
    if (state is ScannerError) return (state as ScannerError).networkInfo;
    return null;
  }

  String get networkDisplayName => networkInfo?.ssid ?? 'WiFi Network';
  String get localIp => networkInfo?.localIp ?? '—';
  String get gatewayIp => networkInfo?.gateway ?? '—';
  String get subnetCidr => '${networkInfo?.subnet ?? "—"}/24';

  // ── Devices ────────────────────────────────────────────────────────────────

  List<NetworkDevice> get devices {
    if (state is ScannerScanning) {
      return (state as ScannerScanning).discoveredDevices;
    }
    if (state is ScannerCompleted) {
      return (state as ScannerCompleted).result.devices;
    }
    if (state is ScannerCancelled) {
      return (state as ScannerCancelled).partialDevices;
    }
    if (state is ScannerReady) {
      return (state as ScannerReady).cachedResult?.devices ?? [];
    }
    return [];
  }

  int get totalDevices => devices.length;

  int get onlineDevices =>
      devices.where((d) => d.status == DeviceStatus.online).length;

  int get devicesWithOpenPorts =>
      devices.where((d) => d.openPorts.isNotEmpty).length;

  NetworkDevice? get gatewayDevice =>
      devices.where((d) => d.isGateway).firstOrNull;

  List<NetworkDevice> get sortedDevices {
    final list = List<NetworkDevice>.from(devices);
    list.sort((a, b) {
      // Gateway first
      if (a.isGateway) return -1;
      if (b.isGateway) return 1;
      // Then by last octet
      final aLast = int.tryParse(a.ip.split('.').last) ?? 0;
      final bLast = int.tryParse(b.ip.split('.').last) ?? 0;
      return aLast.compareTo(bLast);
    });
    return list;
  }

  Map<DeviceType, List<NetworkDevice>> get devicesByType {
    final map = <DeviceType, List<NetworkDevice>>{};
    for (final device in devices) {
      map.putIfAbsent(device.deviceType, () => []).add(device);
    }
    return map;
  }

  // ── Progress ───────────────────────────────────────────────────────────────

  ScanProgress? get progress =>
      state is ScannerScanning ? (state as ScannerScanning).progress : null;

  double get scanPercentage => progress?.percentage ?? 0.0;
  int get scannedIpCount => progress?.scannedCount ?? 0;
  int get totalIpCount => progress?.totalCount ?? 254;
  String get currentScanIp => progress?.currentIp ?? '';
  Duration get elapsed => progress?.elapsed ?? Duration.zero;

  String get progressLabel {
    if (isScanning) return '${scanPercentage.toStringAsFixed(0)}%';
    if (isComplete) return 'Complete';
    if (isCancelled) return 'Cancelled';
    if (hasError) return 'Error';
    return 'Ready';
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  ScanResult? get lastResult =>
      state is ScannerCompleted ? (state as ScannerCompleted).result : null;

  String get scanDurationLabel {
    final result = lastResult;
    if (result == null) return '—';
    final s = result.scanDuration.inSeconds;
    final ms = result.scanDuration.inMilliseconds;
    return s > 0 ? '${s}s' : '${ms}ms';
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  String? get errorMessage =>
      state is ScannerError ? (state as ScannerError).message : null;

  String get statusMessage {
    if (isInitializing) return 'Detecting network…';
    if (isScanning) return 'Scanning $totalIpCount hosts…';
    if (isComplete) return '$onlineDevices devices online';
    if (isCancelled) return 'Scan cancelled — ${devices.length} found';
    if (hasError) return errorMessage ?? 'An error occurred';
    if (isReady && devices.isNotEmpty) return 'Cached: ${devices.length} devices';
    return 'Ready to scan';
  }
}
