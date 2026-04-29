import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:wifi_scanner/core/utils/app_logger.dart';
import 'package:wifi_scanner/core/utils/ip_utils.dart';

/// OUI (Organizationally Unique Identifier) database for MAC vendor lookup
/// Uses a bundled JSON database with API fallback
class OuiDatasource {
  static Map<String, String>? _database;
  static bool _loaded = false;

  /// Load the OUI database from assets
  Future<void> loadDatabase() async {
    if (_loaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/oui_database.json');
      final Map<String, dynamic> data = json.decode(jsonStr);
      _database = data.map((k, v) => MapEntry(k.toUpperCase(), v.toString()));
      _loaded = true;
      AppLogger.info('OUI database loaded: ${_database!.length} entries');
    } catch (e) {
      AppLogger.warning('Failed to load OUI database: $e');
      _database = _getFallbackDatabase();
      _loaded = true;
    }
  }

  /// Lookup vendor from MAC address
  Future<String?> lookupVendor(String macAddress) async {
    if (!_loaded) await loadDatabase();

    final oui = IpUtils.extractOui(macAddress);
    if (oui == null) return null;

    // Try exact match first
    if (_database!.containsKey(oui)) {
      return _database![oui];
    }

    // Try with different separators
    final formatted = '${oui.substring(0, 2)}:${oui.substring(2, 4)}:${oui.substring(4, 6)}';
    return _database![formatted.toUpperCase()];
  }

  /// Synchronous lookup (for use after database is loaded)
  String? lookupVendorSync(String macAddress) {
    if (!_loaded || _database == null) return null;
    final oui = IpUtils.extractOui(macAddress);
    if (oui == null) return null;
    return _database![oui];
  }

  /// Fallback database with common vendors
  Map<String, String> _getFallbackDatabase() {
    return {
      // Apple
      '000A27': 'Apple Inc.',
      '001451': 'Apple Inc.',
      '0017F2': 'Apple Inc.',
      '001CB3': 'Apple Inc.',
      '001D4F': 'Apple Inc.',
      '001E52': 'Apple Inc.',
      '001FF3': 'Apple Inc.',
      '002312': 'Apple Inc.',
      '002500': 'Apple Inc.',
      '0026B9': 'Apple Inc.',
      '002B67': 'Apple Inc.',
      '003065': 'Apple Inc.',
      '0050E4': 'Apple Inc.',
      // Samsung
      '001099': 'Samsung Electronics',
      '0012FB': 'Samsung Electronics',
      '001377': 'Samsung Electronics',
      '001632': 'Samsung Electronics',
      '0016DB': 'Samsung Electronics',
      '001A8A': 'Samsung Electronics',
      '001C43': 'Samsung Electronics',
      '001D25': 'Samsung Electronics',
      '001EE2': 'Samsung Electronics',
      '001F CC': 'Samsung Electronics',
      // Cisco
      '000142': 'Cisco Systems',
      '0002B9': 'Cisco Systems',
      '000CDB': 'Cisco Systems',
      '000F23': 'Cisco Systems',
      '001185': 'Cisco Systems',
      '001301': 'Cisco Systems',
      // TP-Link
      '000AEB': 'TP-Link Technologies',
      '001CF0': 'TP-Link Technologies',
      '1C87F4': 'TP-Link Technologies',
      '3C52A1': 'TP-Link Technologies',
      '50C7BF': 'TP-Link Technologies',
      'A0F3C1': 'TP-Link Technologies',
      'C025E9': 'TP-Link Technologies',
      // Netgear
      '001B2F': 'Netgear Inc.',
      '001E2A': 'Netgear Inc.',
      '002275': 'Netgear Inc.',
      '0026F2': 'Netgear Inc.',
      '20E52A': 'Netgear Inc.',
      '9C3DCF': 'Netgear Inc.',
      // Raspberry Pi
      'B827EB': 'Raspberry Pi Foundation',
      'DCA632': 'Raspberry Pi Foundation',
      'E45F01': 'Raspberry Pi Foundation',
      // Espressif (ESP8266/ESP32)
      '18FE34': 'Espressif Inc.',
      '24B2DE': 'Espressif Inc.',
      '2C3AE8': 'Espressif Inc.',
      '30AEA4': 'Espressif Inc.',
      '3C71BF': 'Espressif Inc.',
      '4C75C7': 'Espressif Inc.',
      '5CCF7F': 'Espressif Inc.',
      '60019F': 'Espressif Inc.',
      '807D3A': 'Espressif Inc.',
      '84F3EB': 'Espressif Inc.',
      'A020A6': 'Espressif Inc.',
      'A4CF12': 'Espressif Inc.',
      'B4E62D': 'Espressif Inc.',
      'BC DD C2': 'Espressif Inc.',
      'C44F33': 'Espressif Inc.',
      'CC50E3': 'Espressif Inc.',
      'D8BFC0': 'Espressif Inc.',
      'E8DB84': 'Espressif Inc.',
      'ECFABC': 'Espressif Inc.',
      'F0F5BD': 'Espressif Inc.',
      'FC F5 C4': 'Espressif Inc.',
      // Google
      '001A11': 'Google Inc.',
      '3C5AB4': 'Google Inc.',
      '54607E': 'Google Inc.',
      '94EB2C': 'Google Inc.',
      // Amazon
      '0C4785': 'Amazon Technologies',
      '34D270': 'Amazon Technologies',
      '40B4CD': 'Amazon Technologies',
      '44650D': 'Amazon Technologies',
      '747548': 'Amazon Technologies',
      'A002DC': 'Amazon Technologies',
      'AC63BE': 'Amazon Technologies',
      'B47C9C': 'Amazon Technologies',
      'F0272D': 'Amazon Technologies',
      'FC65DE': 'Amazon Technologies',
      // Microsoft
      '001DD8': 'Microsoft Corporation',
      '0025AE': 'Microsoft Corporation',
      '002248': 'Microsoft Corporation',
      '7C1E52': 'Microsoft Corporation',
      // Intel
      '001111': 'Intel Corporate',
      '001B21': 'Intel Corporate',
      '001C26': 'Intel Corporate',
      '001D92': 'Intel Corporate',
      '001EA6': 'Intel Corporate',
      '001FE1': 'Intel Corporate',
      '002170': 'Intel Corporate',
      '002269': 'Intel Corporate',
      // Sonos
      '000EFDD': 'Sonos Inc.',
      '5CAAFDB': 'Sonos Inc.',
      '78289C ': 'Sonos Inc.',
      // Ubiquiti
      '0418D6': 'Ubiquiti Networks',
      '24A43C': 'Ubiquiti Networks',
      '44D9E7': 'Ubiquiti Networks',
      '687278': 'Ubiquiti Networks',
      '78459D': 'Ubiquiti Networks',
      '80 2A A8': 'Ubiquiti Networks',
      'DC9FDB': 'Ubiquiti Networks',
      'F09FC2': 'Ubiquiti Networks',
    };
  }
}
