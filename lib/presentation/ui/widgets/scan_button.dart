import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_state.dart';
import 'package:wifi_scanner/core/utils/app_theme.dart';

class ScanButton extends StatelessWidget {
  final ScannerState state;
  final VoidCallback onScan;
  final VoidCallback onRefresh;

  const ScanButton({
    super.key,
    required this.state,
    required this.onScan,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = state is ScannerCompleted;
    final isCancelled = state is ScannerCancelled;

    return GestureDetector(
      onTap: isCompleted || isCancelled ? onRefresh : onScan,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCompleted
                ? [const Color(0xFF059669), const Color(0xFF047857)]
                : [AppTheme.accent, const Color(0xFF0088FF)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isCompleted ? const Color(0xFF059669) : AppTheme.accent)
                  .withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCompleted
                  ? Icons.refresh_rounded
                  : Icons.radar_rounded,
              color: AppTheme.background,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              isCompleted
                  ? 'Rescan Network'
                  : isCancelled
                      ? 'Resume Scan'
                      : 'Start Network Scan',
              style: const TextStyle(
                color: AppTheme.background,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.96, 0.96));
  }
}
