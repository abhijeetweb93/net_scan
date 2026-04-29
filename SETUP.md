# NetScan — Setup Instructions

## Step 1: Add local.properties

Create `android/local.properties` with your paths:

```
sdk.dir=/Users/YOUR_USERNAME/Library/Android/sdk
flutter.sdk=/Users/YOUR_USERNAME/Library/Android/flutter
```

Replace `YOUR_USERNAME` with your macOS username.

## Step 2: Build and run

```bash
flutter clean
flutter pub get
flutter run
```

## Step 3: Install via Android Studio

Open the `android/` folder in Android Studio, sync Gradle, then Run.

## Gradle Version Matrix

| Tool     | Version  |
|----------|----------|
| AGP      | 8.3.0    |
| Kotlin   | 2.0.0    |
| Gradle   | 8.4      |
| compileSdk | 35    |
| minSdk   | 21       |
| Java     | 17       |

## Permissions granted

- INTERNET, ACCESS_WIFI_STATE — network scanning
- ACCESS_FINE_LOCATION — WiFi SSID (Android 8+)
- FOREGROUND_SERVICE + FOREGROUND_SERVICE_DATA_SYNC — background monitor
- POST_NOTIFICATIONS — device join/leave alerts

## ANR Fix

All network operations run on a dedicated ExecutorService (120 threads),
never on the main thread. The background service uses a HandlerThread +
separate probe thread pool.
