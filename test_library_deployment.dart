#!/usr/bin/env dart

import 'dart:io';
import 'package:native_mdns_scanner/native_mdns_scanner.dart';

void main() {
  print('🧪 Testing library path resolution...');

  try {
    // 測試預設的 library 搜尋
    final scanner = NativeMdnsScanner();
    print('✅ Library loaded successfully!');

    // 測試基本功能
    print('🔍 Testing basic functionality...');
    scanner.startScan('_test._tcp'); // 開始一個測試掃描
    print('✅ Scan started successfully!');

    // 停止掃描
    scanner.stopScan();
    print('✅ Scan stopped successfully!');

    scanner.dispose();
    print('✅ Scanner disposed successfully!');

    print('\n🎉 All tests passed! Library deployment is working correctly.');
  } catch (e) {
    print('❌ Test failed: $e');

    // 提供詳細的診斷資訊
    print('\n🔍 Diagnostic information:');
    print('Current working directory: ${Directory.current.path}');

    // 檢查常見的 library 位置
    final commonPaths = [
      'native/libmdns_ffi.dylib',
      'libmdns_ffi.dylib',
      '../native/libmdns_ffi.dylib',
    ];

    for (final path in commonPaths) {
      final file = File(path);
      print('  $path: ${file.existsSync() ? "✅ Found" : "❌ Not found"}');
    }

    // 檢查 package_config.json
    final configFile = File('.dart_tool/package_config.json');
    print(
        '  .dart_tool/package_config.json: ${configFile.existsSync() ? "✅ Found" : "❌ Not found"}');

    exit(1);
  }
}
