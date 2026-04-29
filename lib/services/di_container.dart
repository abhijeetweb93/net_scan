import 'package:get_it/get_it.dart';
import 'package:wifi_scanner/core/network/tcp_ping_scanner.dart';
import 'package:wifi_scanner/core/network/arp_scanner.dart';
import 'package:wifi_scanner/core/network/port_scanner.dart';
import 'package:wifi_scanner/core/discovery/mdns_discovery.dart';
import 'package:wifi_scanner/core/discovery/ssdp_discovery.dart';
import 'package:wifi_scanner/data/datasources/network_info_datasource.dart';
import 'package:wifi_scanner/data/datasources/native_scanner_datasource.dart';
import 'package:wifi_scanner/data/datasources/oui_datasource.dart';
import 'package:wifi_scanner/data/repositories/scanner_repository_impl.dart';
import 'package:wifi_scanner/domain/repositories/scanner_repository.dart';
import 'package:wifi_scanner/domain/usecases/scanner_usecases.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_bloc.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  getIt.registerLazySingleton<TcpPingScanner>(() => TcpPingScanner());
  getIt.registerLazySingleton<ArpScanner>(() => ArpScanner());
  getIt.registerLazySingleton<PortScanner>(() => PortScanner());
  getIt.registerLazySingleton<MdnsDiscovery>(() => MdnsDiscovery());
  getIt.registerLazySingleton<SsdpDiscovery>(() => SsdpDiscovery());
  getIt.registerLazySingleton<OuiDatasource>(() => OuiDatasource());
  getIt.registerLazySingleton<NetworkInfoDatasource>(() => NetworkInfoDatasource());
  getIt.registerLazySingleton<NativeScannerDatasource>(() => NativeScannerDatasource());

  await getIt<OuiDatasource>().loadDatabase();

  getIt.registerLazySingleton<ScannerRepository>(
    () => ScannerRepositoryImpl(
      tcpScanner: getIt<TcpPingScanner>(),
      arpScanner: getIt<ArpScanner>(),
      portScanner: getIt<PortScanner>(),
      mdnsDiscovery: getIt<MdnsDiscovery>(),
      ssdpDiscovery: getIt<SsdpDiscovery>(),
      ouiDatasource: getIt<OuiDatasource>(),
      networkInfoDatasource: getIt<NetworkInfoDatasource>(),
      nativeScanner: getIt<NativeScannerDatasource>(),
    ),
  );

  getIt.registerLazySingleton(() => StartNetworkScanUseCase(getIt<ScannerRepository>()));
  getIt.registerLazySingleton(() => StopNetworkScanUseCase(getIt<ScannerRepository>()));
  getIt.registerLazySingleton(() => GetNetworkInfoUseCase(getIt<ScannerRepository>()));
  getIt.registerLazySingleton(() => ScanDevicePortsUseCase(getIt<ScannerRepository>()));
  getIt.registerLazySingleton(() => LookupVendorUseCase(getIt<ScannerRepository>()));
  getIt.registerLazySingleton(() => GetLastScanResultUseCase(getIt<ScannerRepository>()));

  getIt.registerFactory<ScannerBloc>(() => ScannerBloc(
    startNetworkScan: getIt<StartNetworkScanUseCase>(),
    stopNetworkScan: getIt<StopNetworkScanUseCase>(),
    getNetworkInfo: getIt<GetNetworkInfoUseCase>(),
    scanDevicePorts: getIt<ScanDevicePortsUseCase>(),
    getLastScanResult: getIt<GetLastScanResultUseCase>(),
  ));
}
