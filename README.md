# native_mdns_scanner

[![Pub Version](https://img.shields.io/pub/v/native_mdns_scanner)](https://pub.dev/packages/native_mdns_scanner)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Dart FFI bindings for macOS mDNS/Bonjour services. This library provides native access to multicast DNS functionality on macOS through FFI bindings to Objective-C code.

## Features

- 🔍 **Simple mDNS scanning** - Discover devices by service type
- 🎯 **Simultaneous multi-service scanning** - Scan multiple service types at once
- 🔄 **Periodic scanning** - Run queries at regular intervals
- ⏱️ **Timing analysis** - Analyze discovery patterns and performance
- 🖥️ **CLI tool** - Command-line interface for quick testing
- 📊 **Rich device information** - IP, port, TXT records, and discovery metadata

## Platform Support

- ✅ macOS (arm64 + x86_64)
- ❌ iOS (not tested)
- ❌ Windows (not supported)
- ❌ Linux (not supported)

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  native_mdns_scanner: ^1.4.0
```

Or install directly from GitHub:

```yaml
dependencies:
  native_mdns_scanner:
    git:
      url: https://github.com/changyy/ffi-mdns-macos-dart.git
```

### Library Distribution & Portable Deployment

This package uses a **comprehensive portable deployment strategy** where the native library (`libmdns_ffi.dylib`) is bundled with the Dart package using multiple complementary approaches:

**📦 Deployment Methods:**
1. **`files:` Configuration**: Explicitly includes the library in the published package
2. **Flutter Assets**: For Flutter projects, library included as asset  
3. **Intelligent Path Resolution**: Automatic discovery across project types

```yaml
# In pubspec.yaml - ensures library is always included
files:
  - native/libmdns_ffi.dylib

flutter:
  assets:
    - native/libmdns_ffi.dylib
```

**✅ Supported Project Types:**
- **Flutter Projects**: Library included as asset, automatically found
- **Pure Dart Projects**: Library bundled with package via `files:` configuration
- **Command-line Tools**: Full portable deployment support
- **Development**: Local `native/` directory takes priority

**Key Benefits:**
- 🎯 **Portable**: Library travels with your application
- 🔧 **Zero Setup**: No manual library installation needed
- 📦 **Bundled**: Everything needed is in the package
- 🔍 **Auto-Discovery**: Intelligent library path resolution
- 🛡️ **Redundant**: Multiple deployment methods for maximum compatibility

**For Package Users:** 
```bash
# No additional setup needed - just add to pubspec.yaml and run:
dart pub get

# The library will be automatically located in your .dart_tool/ cache
```

**For Development:**
```bash
# If working with source code, ensure library is built:
cd native && ./build.sh
```

**How It Works:**
1. **Flutter Projects**: Library included as asset in `pubspec.yaml`
2. **Pure Dart**: Library found via package dependency resolution
3. **Development**: Local `native/` directory takes priority

The library search order:
1. Package dependency path (highest priority for published packages)  
2. Local development path (`native/libmdns_ffi.dylib`)
3. Current directory and common build locations
4. System-wide locations (fallback)
flutter:
  assets:
    - native/libmdns_ffi.dylib
```

## Quick Start

### Basic Usage

```dart
import 'package:native_mdns_scanner/native_mdns_scanner.dart';

void main() async {
  final scanner = NativeMdnsScanner();
  try {
    // Scan for Chromecast devices
    scanner.startScan('_googlecast._tcp');
    // Wait for 10 seconds
    await Future.delayed(Duration(seconds: 10));
    scanner.stopScan();
    // Get results
    final devices = scanner.foundDevices;
    for (final device in devices) {
      print('Found: \\${device.name} at \\${device.ip}:\\${device.port}');
    }
  } finally {
    scanner.dispose();
  }
}
```

### Simultaneous Multi-Service Scanning

```dart
final scanner = NativeMdnsScanner();

try {
  final devices = await scanner.scanMultipleServices([
    '_googlecast._tcp',  // Chromecast
    '_airplay._tcp',     // AirPlay
    '_raop._tcp',        // Remote Audio Output Protocol
  ], timeout: Duration(seconds: 15));
  print('Found \\${devices.length} devices');
  // Group by service type
  final devicesByType = scanner.getDevicesByServiceType();
  for (final serviceType in devicesByType.keys) {
    final typeDevices = devicesByType[serviceType]!;
    print('\\${serviceType}: \\${typeDevices.length} devices');
  }
} finally {
  scanner.dispose();
}
```

### Periodic Scanning

```dart
final scanner = NativeMdnsScanner();

try {
  final devices = await scanner.scanMultipleServicesWithPeriodic([
    '_googlecast._tcp',
  ],
    timeout: Duration(seconds: 30),      // Total scan time
    queryInterval: Duration(seconds: 5), // Query every 5 seconds
  );
  // Analyze timing patterns
  TimingAnalyzer.analyzeTimings(devices);
} finally {
  scanner.dispose();
}
```

## Event Callback & Custom Scan Duration

You can receive device events in real time using the JSON callback interface. This is useful for UI updates or streaming results as they arrive.

### Using startScanJson

```dart
final scanner = NativeMdnsScanner();
final foundDevices = <DeviceInfo>[];
scanner.startScanJson('_googlecast._tcp', (json) {
  if (json['type'] == 'device') {
    foundDevices.add(DeviceInfo(
      name: json['name'] ?? '',
      ip: json['ip'] ?? '',
      port: json['port'] ?? 0,
      serviceType: json['type_name'] ?? '',
      txtRecords: Map<String, String>.from(json['txt'] ?? {}),
    ));
    print('Found device: \\${json['name']} at \\${json['ip']}:\\${json['port']}');
  } else if (json['type'] == 'error') {
    print('Error: \\${json['message']}');
  }
}, debug: 2);
// Wait for 10 seconds
await Future.delayed(Duration(seconds: 10));
scanner.stopScan();
```

### Using startPeriodicScanJsonWithDone (recommended new usage)

```dart
final scanner = NativeMdnsScanner();
final foundDevices = <DeviceInfo>[];
await scanner.startPeriodicScanJsonWithDone(
  '_googlecast._tcp',
  (json) {
    if (json['type'] == 'device') {
      foundDevices.add(DeviceInfo(
        name: json['name'] ?? '',
        ip: json['ip'] ?? '',
        port: json['port'] ?? 0,
        serviceType: json['type_name'] ?? '',
        txtRecords: Map<String, String>.from(json['txt'] ?? {}),
        queryNumber: json['queryNumber'] ?? 0,
      ));
      print('Found device: \\${json['name']} (query #\\${json['queryNumber']})');
    } else if (json['type'] == 'error') {
      print('Error: \\${json['message']}');
    }
  },
  queryIntervalMs: 3000, // Query every 3 seconds
  totalDurationMs: 12000, // Run for 12 seconds
  debug: 2,
);
```

## CLI Tool

The package includes a command-line tool for quick testing and debugging:

```bash
# Install globally
dart pub global activate native_mdns_scanner

# Or run directly
dart run bin/mdns_cli.dart
```

### CLI Examples

```bash
# Simple scan
dart run bin/mdns_cli.dart scan _googlecast._tcp

# Scan multiple services
dart run bin/mdns_cli.dart multi _googlecast._tcp _airplay._tcp _raop._tcp

# Periodic scanning
dart run bin/mdns_cli.dart periodic _googlecast._tcp --interval 5 --duration 30

# Timing analysis
dart run bin/mdns_cli.dart timing _googlecast._tcp _airplay._tcp --timeout 20
```

### CLI Options

- `--timeout <seconds>`: Scan timeout (default: 15)
- `--interval <seconds>`: Query interval for periodic scan (default: 5)
- `--duration <seconds>`: Total duration for periodic scan (default: 30)
- `--help`, `-h`: Show help message

### Command-Line Interface (CLI)

The CLI tool supports scanning and timing analysis from the command line:

```
dart run bin/mdns_cli.dart scan _googlecast._tcp
```

#### JSON Output & Silent Mode

- Use `--json` to output only valid JSON (one object per line). All non-JSON output is suppressed.
- When `--json` is enabled, native log output is also fully suppressed (silent mode) for clean machine-readable output.

## Common Service Types

| Service Type | Description | Example Devices |
|--------------|-------------|-----------------|
| `_googlecast._tcp` | Google Cast | Chromecast, Google Home |
| `_airplay._tcp` | Apple AirPlay | Apple TV, AirPort Express |
| `_raop._tcp` | Remote Audio Output | AirPort Express, HomePod |
| `_http._tcp` | HTTP services | Web servers, cameras |
| `_ssh._tcp` | SSH servers | Raspberry Pi, servers |
| `_printer._tcp` | Network printers | HP, Canon printers |
| `_ipp._tcp` | Internet Printing | Modern network printers |

## API Reference

### MdnsFfi Class

The main class for mDNS operations is now recommended to be used as `NativeMdnsScanner` (a type alias for `MdnsFfi`).

#### Methods

- `startScan(String serviceType)` - Start scanning for a service type
- `startPeriodicScan(String serviceType, {int queryIntervalMs, int totalDurationMs})` - Start periodic scanning
- `stopScan()` - Stop all active scans
- `scanMultipleServices(List<String> serviceTypes, {Duration timeout})` - Scan multiple services simultaneously
- `scanMultipleServicesWithPeriodic(List<String> serviceTypes, {Duration timeout, Duration queryInterval})` - Periodic multi-service scanning
- `isScanning()` - Check if any scan is active
- `foundDevices` - Get list of discovered devices
- `getDevicesByServiceType()` - Get devices grouped by service type
- `dispose()` - Clean up resources

### DeviceInfo Class

Represents a discovered mDNS service.

#### Properties

- `String name` - Service name
- `String ip` - IP address
- `int port` - Port number
- `String serviceType` - Service type (e.g., '_googlecast._tcp')
- `Map<String, String> txtRecords` - TXT record key-value pairs
- `DateTime foundAt` - Discovery timestamp
- `int queryNumber` - Which query discovered this device

### TimingAnalyzer Class

Utility for analyzing discovery timing patterns.

#### Methods

- `static void analyzeTimings(List<DeviceInfo> devices)` - Print detailed timing analysis
- `static Map<String, dynamic> getStatistics(List<DeviceInfo> devices)` - Get timing statistics
- `static String formatTime(DateTime time)` - Format time as HH:mm:ss.SSS

## Building from Source

### Prerequisites

- macOS (for building the native library)
- Xcode command line tools
- Dart SDK 3.0+

### Build Steps

1. Clone the repository:
```bash
git clone https://github.com/changyy/ffi-mdns-macos-dart.git
cd ffi-mdns-macos-dart
```

2. Build the native library:
```bash
cd native
./build.sh
```

3. Install Dart dependencies:
```bash
dart pub get
```

4. Run examples:
```bash
dart run example/native_mdns_scanner_example.dart
dart run example/timing_test_example.dart
```

### Project Structure

```
ffi-mdns-macos-dart/
├── lib/
│   ├── native_mdns_scanner.dart           # Main export
│   └── src/
│       ├── mdns_bindings.dart             # FFI bindings
│       ├── device_info.dart               # Device model
│       └── timing_analyzer.dart           # Timing utilities
├── native/
│   ├── mdns_ffi.h                         # C header
│   ├── mdns_ffi.m                         # Objective-C implementation
│   ├── build.sh                           # Build script
│   └── libmdns_ffi.dylib                  # Compiled library
├── example/
│   ├── native_mdns_scanner_example.dart   # Basic usage example
│   └── timing_test_example.dart           # Timing analysis example
├── bin/
│   └── mdns_cli.dart                      # CLI tool
└── test/
    └── mdns_test.dart                     # Unit tests
```

## Performance Notes

- **Simultaneous scanning**: This library can scan multiple service types simultaneously, unlike many other mDNS libraries that scan sequentially
- **Event processing**: Uses a timer-based approach to process mDNS events efficiently
- **Memory management**: Properly manages native resources and prevents memory leaks

## Troubleshooting

### Common Issues

1. **Library not found**: Make sure `libmdns_ffi.dylib` is in the `native/` directory
2. **Permission denied**: On macOS, you might need to allow network access in System Preferences
3. **No devices found**: Some devices may not respond immediately; try increasing the timeout

### Debug Mode

Enable verbose logging by setting debug flags in your code:

```dart
// This will print detailed discovery information
final scanner = NativeMdnsScanner(debugLevel: 2); // 0=quiet, 1=error/result, 2=normal, 3=verbose
// Logs are automatically printed to console
```

## Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built using Dart FFI for native interoperability
- Uses macOS Bonjour/mDNS APIs through Objective-C
- Inspired by the need for simultaneous multi-service mDNS scanning

## Related Projects

- [multicast_dns](https://pub.dev/packages/multicast_dns) - Pure Dart mDNS implementation
- [bonsoir](https://pub.dev/packages/bonsoir) - Cross-platform service discovery
- [nsd](https://pub.dev/packages/nsd) - Network Service Discovery plugin
