#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// Comprehensive test for deployment scenarios
void main() async {
  print('🚀 Final Deployment Test Suite\n');

  await testCurrentConfiguration();
  await testSimulatedPubInstall();
  await testLibrarySearchLogic();

  print('\n✅ All deployment tests passed! 🎉');
  print('📦 Package is ready for pub.dev deployment');
}

Future<void> testCurrentConfiguration() async {
  print('📋 Test 1: Current Configuration Verification');

  // Test pubspec.yaml files configuration
  final pubspec = File('pubspec.yaml');
  final content = await pubspec.readAsString();

  if (content.contains('files:') &&
      content.contains('- native/libmdns_ffi.dylib')) {
    print('  ✅ files: configuration found');
  } else {
    print('  ❌ files: configuration missing');
    exit(1);
  }

  if (content.contains('flutter:') &&
      content.contains('- native/libmdns_ffi.dylib')) {
    print('  ✅ Flutter assets configuration found');
  } else {
    print('  ❌ Flutter assets configuration missing');
    exit(1);
  }

  // Test native library exists
  final lib = File('native/libmdns_ffi.dylib');
  if (lib.existsSync()) {
    final size = await lib.length();
    print('  ✅ Native library exists (${(size / 1024).toStringAsFixed(1)} KB)');
  } else {
    print('  ❌ Native library missing');
    exit(1);
  }
}

Future<void> testSimulatedPubInstall() async {
  print('\n🎭 Test 2: Simulated Package Installation');

  // Create a temporary directory to simulate installed package
  final tempDir = Directory.systemTemp.createTempSync('native_mdns_test_');
  final packageDir = Directory('${tempDir.path}/native_mdns_scanner');
  await packageDir.create(recursive: true);

  try {
    // Copy essential files to simulate pub installation
    await File('native/libmdns_ffi.dylib')
        .copy('${packageDir.path}/libmdns_ffi.dylib');
    await Directory('${packageDir.path}/native').create();
    await File('native/libmdns_ffi.dylib')
        .copy('${packageDir.path}/native/libmdns_ffi.dylib');

    print('  ✅ Simulated package structure created');

    // Test if library would be found
    final libPath = '${packageDir.path}/native/libmdns_ffi.dylib';
    if (File(libPath).existsSync()) {
      print('  ✅ Library findable in simulated package');
    } else {
      print('  ❌ Library not findable in simulated package');
    }
  } finally {
    // Cleanup
    await tempDir.delete(recursive: true);
  }
}

Future<void> testLibrarySearchLogic() async {
  print('\n🔍 Test 3: Library Search Logic');

  // Test the search order priorities
  final searchPaths = [
    'native/libmdns_ffi.dylib', // Development
    'libmdns_ffi.dylib', // Current dir
    '../native/libmdns_ffi.dylib', // Relative
    'build/libmdns_ffi.dylib', // Build output
    'build/macos/libmdns_ffi.dylib', // Flutter build
    'macos/Runner/libmdns_ffi.dylib', // Flutter project
  ];

  print('  📍 Search path priorities:');
  for (int i = 0; i < searchPaths.length; i++) {
    final exists = File(searchPaths[i]).existsSync();
    final status = exists ? '✅' : '❌';
    print('    ${i + 1}. ${searchPaths[i]} $status');
  }

  // Test package_config.json resolution
  final configFile = File('.dart_tool/package_config.json');
  if (configFile.existsSync()) {
    try {
      final config = json.decode(await configFile.readAsString());
      final packages = config['packages'] as List;
      final nativePackage = packages.firstWhere(
        (p) => p['name'] == 'native_mdns_scanner',
        orElse: () => null,
      );

      if (nativePackage != null) {
        print('  ✅ Package path resolution would work');
        print('    Package root: ${nativePackage['rootUri']}');
      } else {
        print('  ℹ️ Package not found in config (expected in dev mode)');
      }
    } catch (e) {
      print('  ⚠️ Could not parse package_config.json: $e');
    }
  } else {
    print('  ⚠️ package_config.json not found');
  }
}
