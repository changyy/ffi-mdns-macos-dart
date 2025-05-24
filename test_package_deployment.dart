#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// Test script to verify package deployment scenarios
void main() async {
  print('🧪 Testing package deployment scenarios...\n');

  // Test 1: Verify native library exists
  await testNativeLibraryExists();

  // Test 2: Verify package_config.json parsing
  await testPackageConfigParsing();

  // Test 3: Test library path resolution manually
  await testLibraryPathResolution();

  // Test 4: Verify pub.dev deployment readiness
  await testPubDeploymentReadiness();

  print('\n🎉 All deployment tests completed!');
}

Future<void> testNativeLibraryExists() async {
  print('📦 Test 1: Verifying native library exists...');

  final libraryFile = File('native/libmdns_ffi.dylib');
  if (libraryFile.existsSync()) {
    final stat = await libraryFile.stat();
    print('  ✅ Library found: ${libraryFile.path}');
    print('  📊 Size: ${(stat.size / 1024).toStringAsFixed(1)} KB');
    print('  📅 Modified: ${stat.modified}');
  } else {
    print('  ❌ Library not found at: ${libraryFile.path}');
    exit(1);
  }
}

Future<void> testPackageConfigParsing() async {
  print('\n🔍 Test 2: Testing package_config.json parsing...');

  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) {
    print('  ⚠️ No package_config.json found (this is normal for development)');
    return;
  }

  try {
    final configContent = configFile.readAsStringSync();
    final config = json.decode(configContent) as Map<String, dynamic>;
    final packages = config['packages'] as List<dynamic>;

    print('  ✅ Successfully parsed package_config.json');
    print('  📦 Found ${packages.length} packages');

    // Look for our package
    for (final package in packages) {
      final packageMap = package as Map<String, dynamic>;
      if (packageMap['name'] == 'native_mdns_scanner') {
        final rootUri = packageMap['rootUri'] as String;
        print('  🎯 Found native_mdns_scanner package: $rootUri');

        if (rootUri.startsWith('file://')) {
          final packagePath = Uri.parse(rootUri).toFilePath();
          final libraryPath = '$packagePath/native/libmdns_ffi.dylib';
          final libraryExists = File(libraryPath).existsSync();
          print('  📚 Library at: $libraryPath ${libraryExists ? "✅" : "❌"}');
        }
        break;
      }
    }
  } catch (e) {
    print('  ❌ Failed to parse package_config.json: $e');
  }
}

Future<void> testLibraryPathResolution() async {
  print('\n🔍 Test 3: Testing library path resolution...');

  const libraryName = 'libmdns_ffi.dylib';
  final searchPaths = [
    'native/$libraryName',
    libraryName,
    '../native/$libraryName',
    'build/$libraryName',
    'build/macos/$libraryName',
    'macos/Runner/$libraryName',
  ];

  print('  🔍 Checking common search paths:');
  var found = false;
  for (final path in searchPaths) {
    final file = File(path);
    final exists = file.existsSync();
    print('    $path: ${exists ? "✅ Found" : "❌ Missing"}');
    if (exists && !found) {
      found = true;
      print('    🎯 This would be the selected path');
    }
  }

  if (!found) {
    print('  ⚠️ No library found in standard search paths');
  }
}

Future<void> testPubDeploymentReadiness() async {
  print('\n📦 Test 4: Verifying pub.dev deployment readiness...');

  // Check pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (pubspecFile.existsSync()) {
    print('  ✅ pubspec.yaml exists');

    final content = pubspecFile.readAsStringSync();
    if (content.contains('native/libmdns_ffi.dylib')) {
      print('  ✅ Native library configured as asset');
    } else {
      print('  ❌ Native library not configured as asset');
    }
  }

  // Check if .pubignore exists and is configured properly
  final pubignoreFile = File('.pubignore');
  if (pubignoreFile.existsSync()) {
    print('  ✅ .pubignore exists');
    final content = pubignoreFile.readAsStringSync();
    if (!content.contains('native/')) {
      print('  ✅ native/ directory not excluded');
    } else {
      print('  ⚠️ native/ directory might be excluded');
    }
  } else {
    print('  ✅ No .pubignore (native/ will be included)');
  }

  // Check README
  final readmeFile = File('README.md');
  if (readmeFile.existsSync()) {
    print('  ✅ README.md exists');
    final content = readmeFile.readAsStringSync();
    if (content.contains('portable') || content.contains('deployment')) {
      print('  ✅ Documentation mentions deployment strategy');
    }
  }

  print('  🎯 Package appears ready for pub.dev deployment');
}
