# NetScan — Production WiFi Network Scanner

A full-featured, production-ready Flutter WiFi network IP scanner built with Clean Architecture, BLoC pattern, and multi-engine discovery.

---

## Architecture

```
net_scan/
├── lib/
│   ├── core/
│   │   ├── concurrency/
│   │   │   └── worker_pool.dart          # Semaphore + WorkerPool + TaskQueue
│   │   ├── discovery/
│   │   │   ├── mdns_discovery.dart       # mDNS/Bonjour multicast listener
│   │   │   ├── ssdp_discovery.dart       # SSDP/UPnP M-SEARCH + response parser
│   │   │   └── upnp_discovery.dart       # UPnP XML description fetcher
│   │   ├── network/
│   │   │   ├── arp_scanner.dart          # ARP cache reader (/proc/net/arp + arp -a)
│   │   │   ├── port_scanner.dart         # TCP port scanner with banner grabbing
│   │   │   ├── tcp_ping_scanner.dart     # TCP-based host discovery (concurrent)
│   │   │   └── udp_scanner.dart          # UDP probes (NetBIOS, DNS, SNMP)
│   │   └── utils/
│   │       ├── app_logger.dart           # Logging utility
│   │       ├── app_theme.dart            # Material 3 dark theme tokens
│   │       ├── device_fingerprinter.dart # Heuristic device type detection
│   │       ├── device_icons.dart         # DeviceType → icon/color mapping
│   │       ├── failures.dart             # Typed failure hierarchy
│   │       └── ip_utils.dart             # IP math, OUI extraction, port names
│   │
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── native_scanner_datasource.dart  # Platform channel to native Android scanner
│   │   │   ├── network_info_datasource.dart    # network_info_plus + NetworkInterface
│   │   │   └── oui_datasource.dart             # Bundled OUI JSON lookup
│   │   └── repositories/
│   │       └── scanner_repository_impl.dart     # Orchestrates all engines
│   │
│   ├── domain/
│   │   ├── models/
│   │   │   ├── network_device.dart       # NetworkDevice, OpenPort, DeviceType, DeviceStatus
│   │   │   └── scan_result.dart          # ScanResult, ScanProgress, NetworkInfo, ScanResultStatus
│   │   ├── repositories/
│   │   │   └── scanner_repository.dart   # Abstract interface + ScanOptions + event types
│   │   └── usecases/
│   │       └── scanner_usecases.dart     # 7 use case classes
│   │
│   ├── presentation/
│   │   ├── bloc/
│   │   │   ├── scanner_bloc.dart         # Full BLoC with event handlers
│   │   │   ├── scanner_event.dart        # 5 public + 4 internal events
│   │   │   └── scanner_state.dart        # 8 state classes
│   │   ├── viewmodels/
│   │   │   └── scan_screen_viewmodel.dart # Transforms state → UI data
│   │   └── ui/
│   │       ├── screens/
│   │       │   ├── scan_screen.dart       # Main scanner screen with RefreshIndicator
│   │       │   └── device_detail_screen.dart # Device info + port scan
│   │       └── widgets/
│   │           ├── device_list_widget.dart
│   │           ├── device_stats_widget.dart
│   │           ├── empty_state_widget.dart
│   │           ├── network_info_card.dart
│   │           ├── port_chip_widget.dart
│   │           ├── scan_button.dart
│   │           └── scan_progress_widget.dart
│   │
│   ├── services/
│   │   └── di_container.dart             # GetIt dependency injection
│   │
│   └── main.dart
│
├── assets/
│   └── oui_database.json                 # 250+ vendor OUI prefixes
│
├── test/
│   └── unit/
│       ├── bloc/scanner_bloc_test.dart
│       ├── repository/scanner_repository_test.dart
│       └── scanner/scanner_engine_test.dart
│
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml           # INTERNET, WIFI_STATE, NEARBY_WIFI_DEVICES, etc.
│       └── res/xml/network_security_config.xml
│
└── ios/Runner/
    └── Info.plist                         # NSLocalNetworkUsageDescription, NSBonjourServices
```

---

## Scanning Pipeline

The scan runs in 5 sequential phases, with mDNS and SSDP running concurrently in the background:

```
Phase 1: ARP Cache Read     → Instant — reads OS ARP table
Phase 2: mDNS Discovery     → Multicast 224.0.0.251:5353
Phase 3: SSDP Discovery     → Multicast 239.255.255.250:1900
Phase 4: TCP Ping Scan      → 80 concurrent workers (configurable), 254 IPs
Phase 5: Port Scan (opt)    → Only if enabled in ScanOptions
```

Results from all phases are merged intelligently via `NetworkDevice.mergeWith()`.

---

## Device Model

```dart
NetworkDevice {
  String ip
  String? macAddress
  String? hostname
  String? vendor             // From OUI database
  DeviceType deviceType      // Heuristic fingerprinting (12 types)
  List<OpenPort> openPorts
  bool isGateway
  int? latency               // TCP ping round-trip (ms)
  DateTime lastSeen
  DeviceStatus status        // online / offline / unknown
  String? mdnsName           // From mDNS
  String? ssdpDescription    // From UPnP description XML
  Map<String, String> metadata
}
```

### OpenPort

```dart
OpenPort {
  int port
  String? service
  String? protocol
  bool isOpen
}
```

### DeviceType Enum

`router` · `smartphone` · `tablet` · `laptop` · `desktop` · `smartTv` · `iotDevice` · `printer` · `gamingConsole` · `networkCamera` · `smartSpeaker` · `unknown`

---

## BLoC Events & States

### Public Events

| Event               | Description                              |
|---------------------|------------------------------------------|
| `InitializeScanner` | Load network info + last cached result   |
| `StartScan`         | Begin full network scan (with optional `ScanOptions`) |
| `StopScan`          | Cancel scan, emit partial results        |
| `RefreshNetwork`    | Re-fetch network info then re-scan (with optional `ScanOptions`) |
| `ScanPorts`         | Port scan a specific device              |

### Internal Events

| Event                  | Description                              |
|------------------------|------------------------------------------|
| `ScanProgressReceived` | Scan progress update from repository     |
| `DeviceDiscoveredEvent`| New device found during scan             |
| `ScanCompletedEvent`   | Scan finished with result               |
| `ScanFailedEvent`      | Scan encountered an error               |

### States

| State               | Description                              |
|---------------------|------------------------------------------|
| `ScannerInitial`    | App just launched                        |
| `ScannerLoading`    | Fetching network info                    |
| `ScannerReady`      | Ready to scan, may have cached result    |
| `ScannerScanning`   | Scan in progress with live progress      |
| `ScannerCompleted`  | Scan done, full result available         |
| `ScannerCancelled`  | User stopped scan, partial devices       |
| `ScannerError`      | Something failed                         |
| `PortScanningState` | Port scan running on a device            |

---

## Use Cases

| Use Case                  | Description                                  |
|---------------------------|----------------------------------------------|
| `StartNetworkScanUseCase` | Start a full network scan (returns Stream)   |
| `StopNetworkScanUseCase`  | Stop an ongoing scan                         |
| `GetNetworkInfoUseCase`   | Get current network information               |
| `ScanDevicePortsUseCase`  | Scan ports on a specific device (Stream)     |
| `LookupVendorUseCase`     | Lookup vendor name from MAC address          |
| `GetLastScanResultUseCase`| Retrieve cached scan result                  |
| `MonitorNetworkUseCase`   | Monitor network for device join/leave events |

---

## ScanOptions

```dart
ScanOptions {
  bool enableArp = true
  bool enableTcpPing = true
  bool enableUdp = true
  bool enableMdns = true
  bool enableSsdp = true
  bool enablePortScan = false
  List<int> portsToScan = [21, 22, 23, 80, 443, 8080, 8443]
  Duration timeout = 1500ms
  int workerCount = 80
}
```

---

## Platform Permissions

### Android (`AndroidManifest.xml`)
- `INTERNET`
- `ACCESS_WIFI_STATE`
- `CHANGE_WIFI_STATE`
- `ACCESS_NETWORK_STATE`
- `ACCESS_FINE_LOCATION` (WiFi SSID on Android 10+)
- `ACCESS_COARSE_LOCATION`
- `CHANGE_MULTICAST_STATE` (mDNS/SSDP multicast)
- `NEARBY_WIFI_DEVICES` (Android 12+, neverForLocation)

### iOS (`Info.plist`)
- `NSLocalNetworkUsageDescription`
- `NSBonjourServices` (16 service types registered)
- `NSLocationWhenInUseUsageDescription`

---

## Dependencies

| Package              | Purpose                          |
|----------------------|----------------------------------|
| `flutter_bloc`       | BLoC state management            |
| `equatable`          | Value equality for models/states |
| `network_info_plus`  | WiFi/network information         |
| `get_it`             | Dependency injection             |
| `dartz`              | Functional programming (Either)  |
| `logger`             | Structured logging               |
| `flutter_animate`    | UI animations                    |

### Dev Dependencies

| Package              | Purpose                          |
|----------------------|----------------------------------|
| `flutter_test`       | Testing framework                |
| `flutter_lints`      | Lint rules                       |
| `bloc_test`          | BLoC testing utilities           |
| `mocktail`           | Mocking for tests                |

---

## Setup

```bash
# Install dependencies
flutter pub get

# Run on device
flutter run

# Run tests
flutter test

# Build APK
flutter build apk --release

```

---

## Performance

- **Concurrency**: 80 parallel TCP workers by default (configurable via `ScanOptions.workerCount`)
- **Target**: Scan 254 IPs in < 3 seconds on a typical home network
- **Timeout**: 1500ms per connection attempt (configurable via `ScanOptions.timeout`)
- **ARP cache**: Zero-latency initial device load
- **mDNS/SSDP**: Run in background parallel to TCP ping
- **Native Scanner**: Platform channel to Android ExecutorService for heavy network work

---

<img width="1440" height="3120" alt="Home" src="https://github.com/user-attachments/assets/0ac4dc5e-abab-42a9-8baa-81431c0c29d0" />

<img width="1440" height="3120" alt="Settings" src="https://github.com/user-attachments/assets/060da9e2-62ec-46c8-a37c-2a4a4165910e" />

<img width="1440" height="3120" alt="Ip_details" src="https://github.com/user-attachments/assets/47c69da7-7b5a-4b6d-aaab-e04058485566" />



