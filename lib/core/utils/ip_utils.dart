/// Utilities for IP address and network manipulation
class IpUtils {
  IpUtils._();

  /// Parse IP string to integer for comparison
  static int ipToInt(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return 0;
    return (int.tryParse(parts[0]) ?? 0) << 24 |
        (int.tryParse(parts[1]) ?? 0) << 16 |
        (int.tryParse(parts[2]) ?? 0) << 8 |
        (int.tryParse(parts[3]) ?? 0);
  }

  /// Convert integer to IP string
  static String intToIp(int ip) {
    return '${(ip >> 24) & 0xFF}.${(ip >> 16) & 0xFF}.${(ip >> 8) & 0xFF}.${ip & 0xFF}';
  }

  /// Extract subnet from IP + mask
  static String getSubnet(String ip, String mask) {
    final ipInt = ipToInt(ip);
    final maskInt = ipToInt(mask);
    final subnetInt = ipInt & maskInt;
    return intToIp(subnetInt);
  }

  /// Get all host IPs in /24 subnet
  static List<String> getSubnetHosts(String ip) {
    final parts = ip.split('.');
    if (parts.length < 3) return [];
    final base = '${parts[0]}.${parts[1]}.${parts[2]}';
    return List.generate(254, (i) => '$base.${i + 1}');
  }

  /// Guess gateway IP (usually .1 or .254)
  static String guessGateway(String ip) {
    final parts = ip.split('.');
    if (parts.length < 3) return '';
    return '${parts[0]}.${parts[1]}.${parts[2]}.1';
  }

  /// Check if IP is a valid IPv4 address
  static bool isValidIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    return parts.every((p) {
      final val = int.tryParse(p);
      return val != null && val >= 0 && val <= 255;
    });
  }

  /// Extract OUI prefix from MAC address (first 3 octets)
  static String? extractOui(String? mac) {
    if (mac == null || mac.isEmpty) return null;
    final cleaned = mac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleaned.length < 6) return null;
    return cleaned.substring(0, 6).toUpperCase();
  }

  /// Format MAC address with colons
  static String formatMac(String mac) {
    final cleaned = mac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleaned.length != 12) return mac;
    return List.generate(6, (i) => cleaned.substring(i * 2, i * 2 + 2))
        .join(':')
        .toUpperCase();
  }

  /// Get broadcast address for /24
  static String getBroadcast(String ip) {
    final parts = ip.split('.');
    if (parts.length < 3) return '';
    return '${parts[0]}.${parts[1]}.${parts[2]}.255';
  }

  /// Determine if two IPs are in the same /24 subnet
  static bool sameSubnet(String ip1, String ip2) {
    final parts1 = ip1.split('.');
    final parts2 = ip2.split('.');
    if (parts1.length < 3 || parts2.length < 3) return false;
    return parts1[0] == parts2[0] &&
        parts1[1] == parts2[1] &&
        parts1[2] == parts2[2];
  }
}

/// Well-known port to service name mapping
class PortServices {
  PortServices._();

  static const Map<int, String> _services = {
    21: 'FTP',
    22: 'SSH',
    23: 'Telnet',
    25: 'SMTP',
    53: 'DNS',
    67: 'DHCP',
    68: 'DHCP Client',
    80: 'HTTP',
    110: 'POP3',
    123: 'NTP',
    143: 'IMAP',
    161: 'SNMP',
    443: 'HTTPS',
    445: 'SMB',
    548: 'AFP',
    554: 'RTSP',
    631: 'IPP',
    993: 'IMAPS',
    995: 'POP3S',
    1194: 'OpenVPN',
    1433: 'MSSQL',
    1723: 'PPTP',
    3306: 'MySQL',
    3389: 'RDP',
    5000: 'UPnP',
    5432: 'PostgreSQL',
    5900: 'VNC',
    5985: 'WinRM',
    6379: 'Redis',
    7547: 'TR-069',
    8080: 'HTTP Alt',
    8443: 'HTTPS Alt',
    8888: 'HTTP Dev',
    9000: 'SonarQube',
    9090: 'WebAdmin',
    9100: 'Printer',
    9200: 'Elasticsearch',
    27017: 'MongoDB',
  };

  static String? getService(int port) => _services[port];

  static const List<int> commonPorts = [
    21, 22, 23, 80, 443, 445, 548, 554, 3389, 5900, 8080, 8443,
  ];

  static const List<int> extendedPorts = [
    21, 22, 23, 25, 53, 80, 110, 143, 443, 445, 548, 554,
    631, 993, 995, 1433, 3306, 3389, 5432, 5900, 7547,
    8080, 8443, 8888, 9000, 9090, 9100,
  ];
}
