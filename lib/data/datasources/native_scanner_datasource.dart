import 'dart:async';
import 'package:flutter/services.dart';
import 'package:wifi_scanner/core/utils/app_logger.dart';

/// Platform channel to native Android scanner.
/// All heavy network work runs in a native ExecutorService (background threads).
class NativeScannerDatasource {
  static const _channel = MethodChannel('com.abhijeet.netscan/network');

  Future<Map<String, dynamic>?> getNetworkInfo() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getNetworkInfo');
      return result;
    } catch (e) {
      AppLogger.warning('Native getNetworkInfo failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> scanNetwork({
    required String subnet,
    required String gateway,
  }) async {
    try {
      final result = await _channel.invokeListMethod<dynamic>(
        'scanNetwork',
        {'subnet': subnet, 'gateway': gateway},
      ).timeout(const Duration(seconds: 60));

      return (result ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      AppLogger.error('Native scanNetwork failed: $e');
      return [];
    }
  }

  Future<void> stopScan() async {
    try {
      await _channel.invokeMethod('stopScan');
    } catch (_) {}
  }
}
