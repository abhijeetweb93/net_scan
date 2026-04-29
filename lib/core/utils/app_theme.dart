import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _primarySeed = Color(0xFF00D4FF); // Cyan-electric
  static const _surfaceDark = Color(0xFF0A0E1A);
  static const _surfaceCard = Color(0xFF111827);
  static const _surfaceElevated = Color(0xFF1A2235);
  static const _onlinePulse = Color(0xFF00FF88);
  static const _warningAmber = Color(0xFFFFB300);
  static const _errorRed = Color(0xFFFF4444);

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primarySeed,
      brightness: Brightness.dark,
      surface: _surfaceDark,
      onSurface: Colors.white,
      primary: _primarySeed,
      secondary: _onlinePulse,
      error: _errorRed,
    ).copyWith(
      surfaceContainer: _surfaceCard,
      surfaceContainerHigh: _surfaceElevated,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _surfaceDark,
      fontFamily: 'SF Pro Display',

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: _surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Cards
      // cardTheme: CardTheme(
      //   color: _surfaceCard,
      //   surfaceTintColor: Colors.transparent,
      //   elevation: 0,
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.circular(16),
      //     side: BorderSide(color: Colors.white.withOpacity(0.06)),
      //   ),
      //   margin: EdgeInsets.zero,
      // ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceElevated,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.white70),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),

      // List tile
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Bottom navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceCard,
        indicatorColor: _primarySeed.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                color: _primarySeed, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: Colors.white54, fontSize: 12);
        }),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primarySeed),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.08),
        thickness: 1,
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primarySeed,
        foregroundColor: _surfaceDark,
        elevation: 0,
        shape: CircleBorder(),
      ),
    );
  }

  // Color tokens
  static const Color online = _onlinePulse;
  static const Color offline = Color(0xFF4A5568);
  static const Color warning = _warningAmber;
  static const Color error = _errorRed;
  static const Color accent = _primarySeed;
  static const Color cardBg = _surfaceCard;
  static const Color elevated = _surfaceElevated;
  static const Color background = _surfaceDark;

  static Color deviceTypeColor(DeviceTypeCategory cat) {
    switch (cat) {
      case DeviceTypeCategory.network:
        return const Color(0xFF7C3AED);
      case DeviceTypeCategory.mobile:
        return const Color(0xFF0EA5E9);
      case DeviceTypeCategory.computer:
        return const Color(0xFF059669);
      case DeviceTypeCategory.media:
        return const Color(0xFFEA580C);
      case DeviceTypeCategory.iot:
        return const Color(0xFFCA8A04);
      case DeviceTypeCategory.other:
        return const Color(0xFF64748B);
    }
  }
}

enum DeviceTypeCategory { network, mobile, computer, media, iot, other }
