import 'package:flutter/material.dart';
import 'package:wifi_scanner/core/utils/app_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accent.withOpacity(0.15)),
              ),
              child: const Icon(
                Icons.radar_rounded,
                color: AppTheme.accent,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Devices Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a scan to discover\ndevices on your network',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
