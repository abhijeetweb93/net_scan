import 'package:flutter/material.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/core/utils/app_theme.dart';
import 'package:wifi_scanner/core/utils/ip_utils.dart';

class PortChipWidget extends StatelessWidget {
  final OpenPort port;

  const PortChipWidget({super.key, required this.port});

  @override
  Widget build(BuildContext context) {
    final service = PortServices.getService(port.port);
    final isHttp = port.port == 80 || port.port == 8080;
    final isHttps = port.port == 443 || port.port == 8443;
    final isSsh = port.port == 22;
    final isRdp = port.port == 3389;
    final isVnc = port.port == 5900;

    Color chipColor = AppTheme.accent;
    IconData? chipIcon;

    if (isHttp) {
      chipColor = const Color(0xFF0EA5E9);
      chipIcon = Icons.http_rounded;
    } else if (isHttps) {
      chipColor = const Color(0xFF059669);
      chipIcon = Icons.lock_rounded;
    } else if (isSsh) {
      chipColor = const Color(0xFFCA8A04);
      chipIcon = Icons.terminal_rounded;
    } else if (isRdp) {
      chipColor = const Color(0xFF7C3AED);
      chipIcon = Icons.desktop_windows_rounded;
    } else if (isVnc) {
      chipColor = const Color(0xFFEA580C);
      chipIcon = Icons.computer_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chipIcon != null) ...[
            Icon(chipIcon, color: chipColor, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            service != null ? '$service (${port.port})' : '${port.port}',
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }
}
