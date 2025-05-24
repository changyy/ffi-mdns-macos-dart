#!/usr/bin/env dart

import 'dart:io';
import 'package:native_mdns_scanner/native_mdns_scanner.dart';

void printUsage() {
  print('''
mDNS CLI Tool

Usage:
  dart run bin/mdns_cli.dart <command> [options]

Commands:
  scan <service_type>                    - Simple scan for a service type
  multi <service1> <service2> ...        - Scan multiple services simultaneously  
  periodic <service_type>                - Periodic scan with custom intervals
  timing <service1> <service2> ...       - Run timing analysis on multiple services

Examples:
  dart run bin/mdns_cli.dart scan _googlecast._tcp
  dart run bin/mdns_cli.dart multi _googlecast._tcp _airplay._tcp _raop._tcp
  dart run bin/mdns_cli.dart periodic _googlecast._tcp --interval 5 --duration 30
  dart run bin/mdns_cli.dart timing _googlecast._tcp _airplay._tcp
  dart run bin/mdns_cli.dart scan _googlecast._tcp --debug=2

Options:
  --timeout <seconds>     Scan timeout (default: 15)
  --interval <seconds>    Query interval for periodic scan (default: 5)
  --duration <seconds>    Total duration for periodic scan (default: 30)
  --debug[=<level>]       Show debug messages (0=quiet, 1=error/result, 2=normal, 3=verbose; default: 0)
  --help, -h              Show this help message
''');
}

Future<void> runSimpleScan(String serviceType,
    {int timeoutSeconds = 15, int debugLevel = 1}) async {
  final mdnsFfi = NativeMdnsScanner(debugLevel: debugLevel);
  final foundDevices = <DeviceInfo>[];
  try {
    print('🔍 Starting simple scan for: $serviceType');
    print('⏱️ Timeout: \\${timeoutSeconds}s\n');
    mdnsFfi.startScanJson(serviceType, (json) {
      if (json['type'] == 'device') {
        foundDevices.add(DeviceInfo(
          name: json['name'] ?? '',
          ip: json['ip'] ?? '',
          port: json['port'] ?? 0,
          serviceType: json['type_name'] ?? '',
          txtRecords: Map<String, String>.from(json['txt'] ?? {}),
        ));
      } else if (json['type'] == 'error') {
        print('❌ Native error: \\${json['message']}');
      }
    }, debug: debugLevel);
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime).inSeconds < timeoutSeconds) {
      await Future.delayed(Duration(seconds: 1));
      if (!mdnsFfi.isScanning()) break;
    }
    mdnsFfi.stopScan();
    print('\n📋 Scan Results:');
    print('Found \\${foundDevices.length} devices');
    for (final device in foundDevices) {
      print('  • \\${device.name} (\\${device.ip}:\\${device.port})');
      if (device.txtRecords.isNotEmpty) {
        print('    TXT: \\${device.txtRecords}');
      }
    }
  } finally {
    mdnsFfi.dispose();
  }
}

Future<void> runMultiScan(List<String> serviceTypes,
    {int timeoutSeconds = 15, int debugLevel = 1}) async {
  final mdnsFfi = NativeMdnsScanner(debugLevel: debugLevel);
  final foundDevices = <DeviceInfo>[];
  try {
    print(
        '🎯 Starting simultaneous scan for \\${serviceTypes.length} services:');
    for (final service in serviceTypes) {
      print('  • \\${service}');
    }
    print('⏱️ Timeout: \\${timeoutSeconds}s\n');
    for (final serviceType in serviceTypes) {
      mdnsFfi.startScanJson(serviceType, (json) {
        if (json['type'] == 'device') {
          foundDevices.add(DeviceInfo(
            name: json['name'] ?? '',
            ip: json['ip'] ?? '',
            port: json['port'] ?? 0,
            serviceType: json['type_name'] ?? '',
            txtRecords: Map<String, String>.from(json['txt'] ?? {}),
          ));
        } else if (json['type'] == 'error') {
          print('❌ Native error: \\${json['message']}');
        }
      }, debug: debugLevel);
      await Future.delayed(Duration(milliseconds: 200));
    }
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime).inSeconds < timeoutSeconds) {
      await Future.delayed(Duration(seconds: 1));
      if (!mdnsFfi.isScanning()) break;
    }
    mdnsFfi.stopScan();
    print('\n📋 Multi-Scan Results:');
    print('Total devices found: \\${foundDevices.length}');
    final devicesByType = <String, List<DeviceInfo>>{};
    for (final device in foundDevices) {
      devicesByType.putIfAbsent(device.serviceType, () => []).add(device);
    }
    for (String serviceType in devicesByType.keys) {
      final typeDevices = devicesByType[serviceType]!;
      print('\n\\${serviceType} (\\${typeDevices.length} devices):');
      for (final device in typeDevices) {
        print('  • \\${device.name} (\\${device.ip}:\\${device.port})');
      }
    }
  } finally {
    mdnsFfi.dispose();
  }
}

Future<void> runPeriodicScan(
  String serviceType, {
  int intervalSeconds = 5,
  int durationSeconds = 30,
  int debugLevel = 1,
}) async {
  final mdnsFfi = NativeMdnsScanner(debugLevel: debugLevel);
  final foundDevices = <DeviceInfo>[];
  try {
    print('🔄 Starting periodic scan for: \\${serviceType}');
    print(
        '📅 Query interval: \\${intervalSeconds}s, Total duration: \\${durationSeconds}s\n');
    mdnsFfi.startPeriodicScanJson(serviceType, (json) {
      if (json['type'] == 'device') {
        foundDevices.add(DeviceInfo(
          name: json['name'] ?? '',
          ip: json['ip'] ?? '',
          port: json['port'] ?? 0,
          serviceType: json['type_name'] ?? '',
          txtRecords: Map<String, String>.from(json['txt'] ?? {}),
        ));
      } else if (json['type'] == 'error') {
        print('❌ Native error: \\${json['message']}');
      }
    },
        queryIntervalMs: intervalSeconds * 1000,
        totalDurationMs: durationSeconds * 1000,
        debug: debugLevel);
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime).inSeconds < durationSeconds) {
      await Future.delayed(Duration(seconds: 1));
      if (!mdnsFfi.isScanning()) break;
    }
    mdnsFfi.stopScan();
    print('\n📋 Periodic Scan Results:');
    print('Found \\${foundDevices.length} devices');
    for (final device in foundDevices) {
      print(
          '  • \\${device.name} (\\${device.ip}:\\${device.port}) [Query #\\${device.queryNumber}]');
    }
  } finally {
    mdnsFfi.dispose();
  }
}

Future<void> runTimingAnalysis(List<String> serviceTypes,
    {int timeoutSeconds = 15}) async {
  final mdnsFfi = NativeMdnsScanner();

  try {
    print('📊 Starting timing analysis for ${serviceTypes.length} services:');
    for (final service in serviceTypes) {
      print('  • $service');
    }
    print('⏱️ Timeout: ${timeoutSeconds}s\n');

    final devices = await mdnsFfi.scanMultipleServices(
      serviceTypes,
      timeout: Duration(seconds: timeoutSeconds),
    );

    print('\n📋 Timing Analysis Results:');
    TimingAnalyzer.analyzeTimings(devices);

    final stats = TimingAnalyzer.getStatistics(devices);
    print('\n📈 Summary Statistics:');
    print('  Total devices: ${stats['totalDevices']}');
    print('  Service types: ${stats['serviceTypes']}');
    print('  Discovery span: ${stats['discoverySpanMs']}ms');
    print('  Simultaneous discoveries: ${stats['simultaneousDiscoveries']}');
  } finally {
    mdnsFfi.dispose();
  }
}

void main(List<String> arguments) async {
  if (arguments.isEmpty ||
      arguments.contains('--help') ||
      arguments.contains('-h')) {
    printUsage();
    return;
  }

  if (!Platform.isMacOS) {
    print('❌ This tool only works on macOS');
    exit(1);
  }

  final command = arguments[0];

  // Parse common options
  int timeoutSeconds = 15;
  int intervalSeconds = 5;
  int durationSeconds = 30;
  int debugLevel = 0;
  final debugArg = arguments.firstWhere(
    (arg) => arg.startsWith('--debug'),
    orElse: () => '',
  );
  if (debugArg == '--debug') {
    debugLevel = 2;
  } else if (debugArg.startsWith('--debug=')) {
    final val = debugArg.split('=')[1];
    debugLevel = int.tryParse(val) ?? 0;
  }

  for (int i = 0; i < arguments.length - 1; i++) {
    switch (arguments[i]) {
      case '--timeout':
        timeoutSeconds = int.tryParse(arguments[i + 1]) ?? timeoutSeconds;
        break;
      case '--interval':
        intervalSeconds = int.tryParse(arguments[i + 1]) ?? intervalSeconds;
        break;
      case '--duration':
        durationSeconds = int.tryParse(arguments[i + 1]) ?? durationSeconds;
        break;
    }
  }

  try {
    switch (command) {
      case 'scan':
        if (arguments.length < 2) {
          print('❌ Service type required for scan command');
          printUsage();
          exit(1);
        }
        await runSimpleScan(arguments[1],
            timeoutSeconds: timeoutSeconds, debugLevel: debugLevel);
        break;

      case 'multi':
        if (arguments.length < 2) {
          print('❌ At least one service type required for multi command');
          printUsage();
          exit(1);
        }
        final services =
            arguments.skip(1).where((arg) => !arg.startsWith('--')).toList();
        await runMultiScan(services,
            timeoutSeconds: timeoutSeconds, debugLevel: debugLevel);
        break;

      case 'periodic':
        if (arguments.length < 2) {
          print('❌ Service type required for periodic command');
          printUsage();
          exit(1);
        }
        await runPeriodicScan(
          arguments[1],
          intervalSeconds: intervalSeconds,
          durationSeconds: durationSeconds,
          debugLevel: debugLevel,
        );
        break;

      case 'timing':
        if (arguments.length < 2) {
          print('❌ At least one service type required for timing command');
          printUsage();
          exit(1);
        }
        final services =
            arguments.skip(1).where((arg) => !arg.startsWith('--')).toList();
        await runTimingAnalysis(services, timeoutSeconds: timeoutSeconds);
        break;

      default:
        print('❌ Unknown command: $command');
        printUsage();
        exit(1);
    }
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
