import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wifi_scanner/core/utils/app_theme.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_bloc.dart';
import 'package:wifi_scanner/presentation/ui/screens/scan_screen.dart';
import 'package:wifi_scanner/services/di_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await setupDependencies();

  runApp(const NetScanApp());
}

class NetScanApp extends StatelessWidget {
  const NetScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ScannerBloc>(
      create: (_) => getIt<ScannerBloc>(),
      child: MaterialApp(
        title: 'NetScan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const ScanScreen(),
      ),
    );
  }
}
