import 'dart:ffi';
import 'dart:io';
import 'dart:async';
import 'package:ffi/ffi.dart';
import 'dart:convert';

import 'device_info.dart';

// FFI type definitions
typedef DeviceFoundCallbackNative = Void Function(
  Pointer<Utf8> ip,
  Int32 port,
  Pointer<Utf8> name,
  Pointer<Utf8> txt,
);
typedef DeviceFoundCallbackDart = void Function(
  Pointer<Utf8> ip,
  int port,
  Pointer<Utf8> name,
  Pointer<Utf8> txt,
);

typedef StartMdnsScanNative = Void Function(
  Pointer<Utf8> serviceType,
  Pointer<NativeFunction<DeviceFoundCallbackNative>> cb,
);
typedef StartMdnsScanDart = void Function(
  Pointer<Utf8> serviceType,
  Pointer<NativeFunction<DeviceFoundCallbackNative>> cb,
);

typedef StartMdnsPeriodicScanNative = Void Function(
  Pointer<Utf8> serviceType,
  Int32 queryIntervalMs,
  Int32 totalDurationMs,
  Pointer<NativeFunction<DeviceFoundCallbackNative>> cb,
);
typedef StartMdnsPeriodicScanDart = void Function(
  Pointer<Utf8> serviceType,
  int queryIntervalMs,
  int totalDurationMs,
  Pointer<NativeFunction<DeviceFoundCallbackNative>> cb,
);

typedef StopMdnsScanNative = Void Function();
typedef StopMdnsScanDart = void Function();

typedef ProcessMdnsEventsNative = Void Function();
typedef ProcessMdnsEventsDart = void Function();

typedef IsMdnsScanningNative = Int32 Function();
typedef IsMdnsScanningDart = int Function();

typedef GetFoundServicesCountNative = Int32 Function();
typedef GetFoundServicesCountDart = int Function();

// 新增 JSON callback FFI type definitions
typedef DeviceFoundJsonCallbackNative = Void Function(Pointer<Utf8> jsonStr);
typedef DeviceFoundJsonCallbackDart = void Function(Pointer<Utf8> jsonStr);

typedef StartMdnsScanJsonNative = Void Function(
  Pointer<Utf8> serviceType,
  Pointer<NativeFunction<DeviceFoundJsonCallbackNative>> cb,
  Int32 debugMode,
);
typedef StartMdnsScanJsonDart = void Function(
  Pointer<Utf8> serviceType,
  Pointer<NativeFunction<DeviceFoundJsonCallbackNative>> cb,
  int debugMode,
);

typedef StartMdnsPeriodicScanJsonNative = Void Function(
  Pointer<Utf8> serviceType,
  Int32 queryIntervalMs,
  Int32 totalDurationMs,
  Pointer<NativeFunction<DeviceFoundJsonCallbackNative>> cb,
  Int32 debugMode,
);
typedef StartMdnsPeriodicScanJsonDart = void Function(
  Pointer<Utf8> serviceType,
  int queryIntervalMs,
  int totalDurationMs,
  Pointer<NativeFunction<DeviceFoundJsonCallbackNative>> cb,
  int debugMode,
);

typedef SetMdnsSilentModeNative = Void Function(Int32 silent);
typedef SetMdnsSilentModeDart = void Function(int silent);

// Global callback holder
DeviceFoundCallbackDart? _dartDeviceFoundCallback;

void _ffiDeviceFoundCallback(
  Pointer<Utf8> ip,
  int port,
  Pointer<Utf8> name,
  Pointer<Utf8> txt,
) {
  if (_dartDeviceFoundCallback != null) {
    _dartDeviceFoundCallback!(ip, port, name, txt);
  }
}

/// Main class for mDNS scanning functionality
class MdnsFfi {
  static bool silentLibraryPrint = false;

  late final DynamicLibrary _lib;
  late final StartMdnsScanDart _startScan;
  late final StartMdnsPeriodicScanDart _startPeriodicScan;
  late final StopMdnsScanDart _stopScan;
  late final ProcessMdnsEventsDart _processEvents;
  late final IsMdnsScanningDart _isScanning;
  late final GetFoundServicesCountDart _getFoundServicesCount;
  late final StartMdnsScanJsonDart _startScanJson;
  late final StartMdnsPeriodicScanJsonDart _startPeriodicScanJson;
  late final SetMdnsSilentModeDart _setSilentMode;
  DeviceFoundJsonCallbackDart? _dartDeviceFoundJsonCallback;
  final List<DeviceInfo> _foundDevices = [];
  Timer? _eventProcessingTimer;

  static void _ffiDeviceFoundJsonCallback(Pointer<Utf8> jsonStrPtr) {
    // 這裡假設只有一個 MdnsFfi instance
    _singleton?._dartDeviceFoundJsonCallback?.call(jsonStrPtr);
  }

  static MdnsFfi? _singleton;

  int debugLevel;

  MdnsFfi({String? libraryPath, this.debugLevel = 1}) {
    if (!Platform.isMacOS) {
      throw UnsupportedError('Only macOS supported');
    }

    final path = libraryPath ?? _findLibraryPath();
    _lib = DynamicLibrary.open(path);

    _startScan = _lib
        .lookup<NativeFunction<StartMdnsScanNative>>('start_mdns_scan')
        .asFunction();

    _startPeriodicScan = _lib
        .lookup<NativeFunction<StartMdnsPeriodicScanNative>>(
            'start_mdns_periodic_scan')
        .asFunction();

    _stopScan = _lib
        .lookup<NativeFunction<StopMdnsScanNative>>('stop_mdns_scan')
        .asFunction();

    _processEvents = _lib
        .lookup<NativeFunction<ProcessMdnsEventsNative>>('process_mdns_events')
        .asFunction();

    _isScanning = _lib
        .lookup<NativeFunction<IsMdnsScanningNative>>('is_mdns_scanning')
        .asFunction();

    _getFoundServicesCount = _lib
        .lookup<NativeFunction<GetFoundServicesCountNative>>(
            'get_found_services_count')
        .asFunction();

    _startScanJson = _lib
        .lookup<NativeFunction<StartMdnsScanJsonNative>>('start_mdns_scan_json')
        .asFunction();
    _startPeriodicScanJson = _lib
        .lookup<NativeFunction<StartMdnsPeriodicScanJsonNative>>(
            'start_mdns_periodic_scan_json')
        .asFunction();
    _setSilentMode = _lib
        .lookup<NativeFunction<SetMdnsSilentModeNative>>('set_mdns_silent_mode')
        .asFunction();
  }

  /// Find the library in common locations
  static String _findLibraryPath() {
    const libraryName = 'libmdns_ffi.dylib';

    // Common search paths (in order of preference)
    final searchPaths = [
      // 1. Development environment (current package)
      'native/$libraryName',

      // 2. Current directory
      libraryName,

      // 3. Relative to Dart script location
      '../native/$libraryName',

      // 4. System-wide locations
      '/usr/local/lib/$libraryName',
      '/opt/homebrew/lib/$libraryName',

      // 5. Common build output directories
      'build/$libraryName',
      'build/macos/$libraryName',

      // 6. Flutter project structure
      'macos/Runner/$libraryName',

      // 7. Package installation location (when used as dependency)
      '.dart_tool/package_config.json', // We'll handle this specially
    ];

    // Check direct paths first
    for (final path in searchPaths) {
      if (path.endsWith('.json')) continue; // Skip the special case

      final file = File(path);
      if (file.existsSync()) {
        if (!silentLibraryPrint) {
          print('📚 Found library at: $path');
        }
        return path;
      }
    }

    // Try to find via package dependency path
    final packagePath = _findPackagePath();
    if (packagePath != null) {
      final packageLibPath = '$packagePath/native/$libraryName';
      final file = File(packageLibPath);
      if (file.existsSync()) {
        if (!silentLibraryPrint) {
          print('📚 Found library in package at: $packageLibPath');
        }
        return packageLibPath;
      }
    }

    // If nothing found, provide helpful error message
    final searchedPaths =
        searchPaths.where((p) => !p.endsWith('.json')).join('\n  ');
    throw FileSystemException(
        'Could not find $libraryName. Searched in:\n  $searchedPaths\n\n'
        'Please ensure the library is built and available, or specify a custom path:\n'
        '  MdnsFfi(libraryPath: "path/to/$libraryName")\n\n'
        'To build the library, run: cd native && ./build.sh');
  }

  /// Try to find the package installation path when used as a dependency
  static String? _findPackagePath() {
    try {
      final configFile = File('.dart_tool/package_config.json');
      if (!configFile.existsSync()) return null;

      // This is a simplified approach - in a real implementation,
      // you might want to parse the JSON to find the exact package path
      final cwd = Directory.current.path;
      final possiblePaths = [
        '$cwd/.dart_tool/package_resolver/packages/native_mdns_scanner',
        '$cwd/packages/native_mdns_scanner',
      ];

      for (final path in possiblePaths) {
        if (Directory(path).existsSync()) {
          return path;
        }
      }
    } catch (e) {
      // Ignore errors in package path resolution
    }
    return null;
  }

  /// Internal callback handler for device discovery
  void _onDeviceFound(
    Pointer<Utf8> ip,
    int port,
    Pointer<Utf8> name,
    Pointer<Utf8> txt,
  ) {
    final ipStr = ip.toDartString();
    final nameStr = name.toDartString();
    final txtStr = txt.toDartString();
    final foundTime = DateTime.now();

    // 解析 TXT 記錄
    final txtRecords = <String, String>{};
    final pairs = txtStr.split(',');
    for (String pair in pairs) {
      final parts = pair.split('=');
      if (parts.length >= 2) {
        txtRecords[parts[0]] = parts.sublist(1).join('=');
      }
    }

    final serviceType = txtRecords['service_type'] ?? 'unknown';
    final queryNumberStr = txtRecords['query_num'] ?? '0';
    final queryNumber = int.tryParse(queryNumberStr) ?? 0;

    // 移除我們加入的標記
    txtRecords.remove('service_type');
    txtRecords.remove('query_num');

    final device = DeviceInfo(
      name: nameStr,
      ip: ipStr,
      port: port,
      serviceType: serviceType,
      txtRecords: txtRecords,
      foundAt: foundTime,
      queryNumber: queryNumber,
    );

    _foundDevices.add(device);

    if (debugLevel >= 2) {
      final timeStr =
          '${foundTime.hour.toString().padLeft(2, '0')}:${foundTime.minute.toString().padLeft(2, '0')}:${foundTime.second.toString().padLeft(2, '0')}.${foundTime.millisecond.toString().padLeft(3, '0')}';

      print(
          '⏰ [$timeStr] Found: $nameStr ($serviceType) at $ipStr:$port [Query #$queryNumber]');
    }
  }

  /// Start scanning for a specific service type
  ///
  /// [serviceType] should be in the format '_service._tcp' (e.g., '_googlecast._tcp')
  void startScan(String serviceType) {
    final serviceTypePtr = serviceType.toNativeUtf8();
    _dartDeviceFoundCallback = _onDeviceFound;
    final cbPtr = Pointer.fromFunction<DeviceFoundCallbackNative>(
      _ffiDeviceFoundCallback,
    );

    if (debugLevel >= 2) {
      print('🚀 Starting scan for: $serviceType');
    }
    _startScan(serviceTypePtr, cbPtr);

    // 啟動事件處理定時器（如果還沒啟动）
    _startEventProcessing();

    calloc.free(serviceTypePtr);
  }

  void startScanJson(
      String serviceType, void Function(Map<String, dynamic>) onJson,
      {int debug = 1}) {
    _singleton = this;
    final serviceTypePtr = serviceType.toNativeUtf8();
    _dartDeviceFoundJsonCallback = (Pointer<Utf8> jsonStrPtr) {
      final jsonStr = jsonStrPtr.toDartString();
      try {
        final map = jsonStr.isNotEmpty
            ? Map<String, dynamic>.from(json.decode(jsonStr) as Map)
            : <String, dynamic>{};
        onJson(map);
      } catch (e) {
        if (debugLevel >= 1) {
          print('❌ JSON parse error: $e, raw: $jsonStr');
        }
      }
    };
    final cbPtr = Pointer.fromFunction<DeviceFoundJsonCallbackNative>(
        _ffiDeviceFoundJsonCallback);
    _startScanJson(serviceTypePtr, cbPtr, debug);
    if (debugLevel >= 3) {
      print('🔄 Starting event processing timer');
    }
    _startEventProcessing();
    calloc.free(serviceTypePtr);
  }

  /// 新版：支援 onDone callback 的 periodic scan (JSON callback)
  Future<void> startPeriodicScanJsonWithDone(
    String serviceType,
    void Function(Map<String, dynamic>) onJson, {
    int queryIntervalMs = 0,
    int totalDurationMs = 0,
    int debug = 1,
    void Function()? onDone,
  }) async {
    _singleton = this;
    final serviceTypePtr = serviceType.toNativeUtf8();
    _dartDeviceFoundJsonCallback = (Pointer<Utf8> jsonStrPtr) {
      final jsonStr = jsonStrPtr.toDartString();
      try {
        final map = jsonStr.isNotEmpty
            ? Map<String, dynamic>.from(json.decode(jsonStr) as Map)
            : <String, dynamic>{};
        onJson(map);
      } catch (e) {
        if (debugLevel >= 1) {
          print('❌ JSON parse error: $e, raw: $jsonStr');
        }
      }
    };
    final cbPtr = Pointer.fromFunction<DeviceFoundJsonCallbackNative>(
        _ffiDeviceFoundJsonCallback);
    _startPeriodicScanJson(
        serviceTypePtr, queryIntervalMs, totalDurationMs, cbPtr, debug);
    if (debugLevel >= 3) {
      print('🔄 Starting event processing timer');
    }
    _startEventProcessing();
    calloc.free(serviceTypePtr);
    if (totalDurationMs > 0) {
      await Future.delayed(Duration(milliseconds: totalDurationMs));
      stopScan();
      if (onDone != null) onDone();
    }
  }

  /// 新版：支援 onDone callback 的 periodic scan (native callback)
  Future<void> startPeriodicScanWithDone(
    String serviceType, {
    int queryIntervalMs = 0,
    int totalDurationMs = 0,
    void Function()? onDone,
  }) async {
    final serviceTypePtr = serviceType.toNativeUtf8();
    _dartDeviceFoundCallback = _onDeviceFound;
    final cbPtr = Pointer.fromFunction<DeviceFoundCallbackNative>(
      _ffiDeviceFoundCallback,
    );
    if (debugLevel >= 2) {
      print(
          '🚀 Starting periodic scan for: $serviceType (interval: \\${queryIntervalMs}ms, duration: \\${totalDurationMs}ms)');
    }
    _startPeriodicScan(serviceTypePtr, queryIntervalMs, totalDurationMs, cbPtr);
    _startEventProcessing();
    calloc.free(serviceTypePtr);
    if (totalDurationMs > 0) {
      await Future.delayed(Duration(milliseconds: totalDurationMs));
      stopScan();
      if (onDone != null) onDone();
    }
  }

  /// Stop all active scans
  void stopScan() {
    if (debugLevel >= 2) {
      print('🛑 Stopping all scans');
    }
    _stopScan();
    _stopEventProcessing();
    _dartDeviceFoundCallback = null;
  }

  /// Check if any scan is currently active
  bool isScanning() {
    return _isScanning() > 0;
  }

  /// Get the number of services found in the native library
  int getFoundServicesCount() {
    return _getFoundServicesCount();
  }

  /// Set native silent mode (suppresses native logs)
  void setSilentMode(bool silent) {
    _setSilentMode(silent ? 1 : 0);
  }

  /// Start the event processing timer
  void _startEventProcessing() {
    if (_eventProcessingTimer?.isActive == true) return;
    if (debugLevel >= 3) {
      print('🔄 Starting event processing timer');
    }
    _eventProcessingTimer = Timer.periodic(
      Duration(milliseconds: 50),
      (timer) {
        _processEvents();
      },
    );
  }

  /// Stop the event processing timer
  void _stopEventProcessing() {
    if (_eventProcessingTimer?.isActive == true) {
      if (debugLevel >= 3) {
        print('⏹️ Stopping event processing timer');
      }
      _eventProcessingTimer?.cancel();
      _eventProcessingTimer = null;
    }
  }

  /// Scan multiple service types simultaneously
  /// Returns a list of all discovered devices
  Future<List<DeviceInfo>> scanMultipleServices(
    List<String> serviceTypes, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (debugLevel >= 2) {
      print(
          '🎯 Starting simultaneous scan for \\${serviceTypes.length} services...');
    }
    _foundDevices.clear();
    for (String serviceType in serviceTypes) {
      startScan(serviceType);
      await Future.delayed(Duration(milliseconds: 200));
    }
    if (debugLevel >= 2) {
      print('⏱️ Waiting \\${timeout.inSeconds} seconds for results...');
    }
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(Duration(milliseconds: 1000));
      if (debugLevel >= 3) {
        print(
            '📊 Status: \\${isScanning() ? "Scanning" : "Stopped"}, Found: \\${_foundDevices.length} devices, C++ count: \\${getFoundServicesCount()}');
      }
    }
    stopScan();
    if (debugLevel >= 2) {
      print(
          '✅ Simultaneous scan completed. Found \\${_foundDevices.length} devices');
    }
    return List.from(_foundDevices);
  }

  /// Scan multiple service types with periodic queries
  /// Returns a list of all discovered devices
  Future<List<DeviceInfo>> scanMultipleServicesWithPeriodic(
    List<String> serviceTypes, {
    Duration timeout = const Duration(seconds: 30),
    Duration queryInterval = const Duration(seconds: 5),
  }) async {
    if (debugLevel >= 2) {
      print(
          '🎯 Starting periodic simultaneous scan for \\${serviceTypes.length} services...');
      print(
          '📅 Query interval: \\${queryInterval.inSeconds}s, Total duration: \\${timeout.inSeconds}s');
    }
    _foundDevices.clear();
    final queryIntervalMs = queryInterval.inMilliseconds;
    final totalDurationMs = timeout.inMilliseconds;
    for (String serviceType in serviceTypes) {
      await startPeriodicScanWithDone(
        serviceType,
        queryIntervalMs: queryIntervalMs,
        totalDurationMs: totalDurationMs,
      );
      await Future.delayed(Duration(milliseconds: 300));
    }
    if (debugLevel >= 2) {
      print(
          '⏱️ Monitoring periodic scans for \\${timeout.inSeconds} seconds...');
    }
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime) < timeout && isScanning()) {
      await Future.delayed(Duration(milliseconds: 2000));
      final elapsed = DateTime.now().difference(startTime);
      if (debugLevel >= 3) {
        print(
            '📊 [\\${elapsed.inSeconds}s] Status: \\${isScanning() ? "Scanning" : "Stopped"}, Found: \\${_foundDevices.length} devices');
      }
    }
    if (isScanning()) {
      if (debugLevel >= 2) {
        print('⏰ Timeout reached, stopping scans...');
      }
      stopScan();
    } else {
      if (debugLevel >= 2) {
        print('✅ All scans completed naturally');
      }
    }
    _stopEventProcessing();
    if (debugLevel >= 2) {
      print(
          '✅ Periodic scan completed. Found \\${_foundDevices.length} devices');
    }
    return List.from(_foundDevices);
  }

  /// Get devices grouped by service type
  Map<String, List<DeviceInfo>> getDevicesByServiceType() {
    final Map<String, List<DeviceInfo>> result = {};
    for (DeviceInfo device in _foundDevices) {
      result.putIfAbsent(device.serviceType, () => []).add(device);
    }
    return result;
  }

  /// Get a copy of all found devices
  List<DeviceInfo> get foundDevices => List.from(_foundDevices);

  /// Clear the found devices list
  void clearFoundDevices() {
    _foundDevices.clear();
  }

  /// Dispose of resources
  void dispose() {
    stopScan();
    _foundDevices.clear();
  }
}
