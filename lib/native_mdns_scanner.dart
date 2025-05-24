/// Native mDNS/Bonjour service scanner for macOS.
///
/// This library provides high-performance access to multicast DNS functionality
/// on macOS through FFI bindings to native Objective-C code.
///
/// ## Features
///
/// - 🔍 Native mDNS/Bonjour service discovery
/// - 🎯 Simultaneous multi-service scanning
/// - 🔄 Periodic scanning with custom intervals
/// - ⏱️ Timing analysis and performance metrics
/// - 🖥️ Command-line interface included
///
/// ## Quick Start
///
/// ```dart
/// import 'package:native_mdns_scanner/native_mdns_scanner.dart';
///
/// final scanner = MdnsFfi();
/// final devices = await scanner.scanMultipleServices([
///   '_googlecast._tcp',
///   '_airplay._tcp',
/// ]);
/// ```
library native_mdns_scanner;

export 'src/mdns_bindings.dart';
export 'src/device_info.dart';
export 'src/timing_analyzer.dart';

/// 別名，讓用戶可用 NativeMdnsScanner 這個名稱
import 'src/mdns_bindings.dart' show MdnsFfi;

typedef NativeMdnsScanner = MdnsFfi;
