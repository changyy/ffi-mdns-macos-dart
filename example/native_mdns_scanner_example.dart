import 'package:native_mdns_scanner/native_mdns_scanner.dart';

void main() async {
  final mdnsFfi = NativeMdnsScanner();
  final foundDevices = <DeviceInfo>[];
  try {
    print('🔍 Basic mDNS scanning example\n');
    print('📱 Scanning for Chromecast devices...');
    mdnsFfi.startScanJson('_googlecast._tcp', (json) {
      if (json['type'] == 'device') {
        foundDevices.add(DeviceInfo(
          name: json['name'] ?? '',
          ip: json['ip'] ?? '',
          port: json['port'] ?? 0,
          serviceType: json['type_name'] ?? '',
          txtRecords: Map<String, String>.from(json['txt'] ?? {}),
        ));
      } else if (json['type'] == 'error') {
        print('❌ Native error: \'${json['message']}\'');
      }
    }, debug: 2);
    // Wait for 10 seconds
    await Future.delayed(Duration(seconds: 10));

    mdnsFfi.stopScan();

    print('Found \\${foundDevices.length} Chromecast devices:');
    for (final device in foundDevices) {
      print('  • \\${device.name} at \\${device.ip}:\\${device.port}');
      if (device.txtRecords.isNotEmpty) {
        print('    TXT records: \\${device.txtRecords}');
      }
    }

    print('\n' + '=' * 50);

    // Example 2: Scan multiple service types
    print('🎯 Scanning multiple service types simultaneously...');
    foundDevices.clear();
    final multiTypes = ['_googlecast._tcp', '_airplay._tcp', '_raop._tcp'];
    for (final type in multiTypes) {
      mdnsFfi.startScanJson(type, (json) {
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
      }, debug: 2);
      await Future.delayed(Duration(milliseconds: 200));
    }
    await Future.delayed(Duration(seconds: 15));
    mdnsFfi.stopScan();
    print('\nFound \\${foundDevices.length} devices total:');
    final devicesByType = <String, List<DeviceInfo>>{};
    for (final device in foundDevices) {
      devicesByType.putIfAbsent(device.serviceType, () => []).add(device);
    }
    for (final serviceType in devicesByType.keys) {
      final typeDevices = devicesByType[serviceType]!;
      print('\n\\${serviceType} (\\${typeDevices.length} devices):');
      for (final device in typeDevices) {
        print('  • \\${device.name} (\\${device.ip}:\\${device.port})');
      }
    }
    print('\n' + '=' * 50);

    // Example 3: Periodic scanning
    print('🔄 Periodic scanning example...');
    print('Sending queries every 3 seconds for 12 seconds total\n');
    foundDevices.clear();
    mdnsFfi.startPeriodicScanJson('_googlecast._tcp', (json) {
      if (json['type'] == 'device') {
        foundDevices.add(DeviceInfo(
          name: json['name'] ?? '',
          ip: json['ip'] ?? '',
          port: json['port'] ?? 0,
          serviceType: json['type_name'] ?? '',
          txtRecords: Map<String, String>.from(json['txt'] ?? {}),
          queryNumber: json['queryNumber'] ?? 0,
        ));
      } else if (json['type'] == 'error') {
        print('❌ Native error: \\${json['message']}');
      }
    }, queryIntervalMs: 3000, totalDurationMs: 12000, debug: 2);
    await Future.delayed(Duration(seconds: 12));
    mdnsFfi.stopScan();
    print('\nPeriodic scan results:');
    for (final device in foundDevices) {
      print(
          '  • \\${device.name} found in query #\\${device.queryNumber} at \\${TimingAnalyzer.formatTime(device.foundAt)}');
    }
    // Show timing analysis
    if (foundDevices.isNotEmpty) {
      print('\n📊 Timing Analysis:');
      TimingAnalyzer.analyzeTimings(foundDevices);
    }
  } catch (e) {
    print('❌ Error during scanning: $e');
  } finally {
    print('\n🧹 Cleaning up...');
    mdnsFfi.dispose();
    print('✅ Done!');
  }
}
