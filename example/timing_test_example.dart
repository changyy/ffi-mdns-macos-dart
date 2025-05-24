import 'package:native_mdns_scanner/native_mdns_scanner.dart';

void main() async {
  // Adjustable debugLevel: 0=silent, 1=error/result, 2=normal, 3=verbose
  final int debugLevel = int.tryParse(
          const String.fromEnvironment('DEBUG_LEVEL', defaultValue: '1')) ??
      1;
  final mdnsFfi = NativeMdnsScanner(debugLevel: debugLevel);
  final foundDevices1 = <DeviceInfo>[];
  final foundDevices2 = <DeviceInfo>[];
  try {
    print(
        '🧪 Testing simultaneous vs periodic scanning with timing analysis...\n');
    final serviceTypes = ['_googlecast._tcp', '_airplay._tcp', '_raop._tcp'];
    print('=' * 60);
    print('📊 Test 1: Basic simultaneous scanning');
    print('🔍 Services: \\${serviceTypes.join(', ')}\n');
    for (final type in serviceTypes) {
      mdnsFfi.startScanJson(type, (json) {
        if (json['type'] == 'device') {
          foundDevices1.add(DeviceInfo(
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
    await Future.delayed(Duration(seconds: 15));
    mdnsFfi.stopScan();
    print('\n📋 Test 1 Summary:');
    print('Total devices found: \\${foundDevices1.length}');
    final devicesByType1 = <String, List<DeviceInfo>>{};
    for (final device in foundDevices1) {
      devicesByType1.putIfAbsent(device.serviceType, () => []).add(device);
    }
    for (String serviceType in devicesByType1.keys) {
      final typeDevices = devicesByType1[serviceType]!;
      print('  \\${serviceType}: \\${typeDevices.length} devices');
    }
    TimingAnalyzer.analyzeTimings(foundDevices1);
    print('\n' + '=' * 60);
    print('📊 Test 2: Periodic simultaneous scanning');
    print('🔍 Services: \\${serviceTypes.join(', ')}');
    print('📅 Query every 5 seconds for 20 seconds total\n');
    foundDevices2.clear();
    for (final type in serviceTypes) {
      await mdnsFfi.startPeriodicScanJsonWithDone(
        type,
        (json) {
          if (json['type'] == 'device') {
            foundDevices2.add(DeviceInfo(
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
        },
        queryIntervalMs: 5000,
        totalDurationMs: 20000,
        debug: debugLevel,
      );
      await Future.delayed(Duration(milliseconds: 300));
    }
    await Future.delayed(Duration(seconds: 20));
    mdnsFfi.stopScan();
    print('\n📋 Test 2 Summary:');
    print('Total devices found: \\${foundDevices2.length}');
    final devicesByType2 = <String, List<DeviceInfo>>{};
    for (final device in foundDevices2) {
      devicesByType2.putIfAbsent(device.serviceType, () => []).add(device);
    }
    for (String serviceType in devicesByType2.keys) {
      final typeDevices = devicesByType2[serviceType]!;
      print('  \\${serviceType}: \\${typeDevices.length} devices');
    }
    TimingAnalyzer.analyzeTimings(foundDevices2);
    print('\n🔢 Comparison Statistics:');
    final stats1 = TimingAnalyzer.getStatistics(foundDevices1);
    final stats2 = TimingAnalyzer.getStatistics(foundDevices2);
    print(
        'Test 1 (Basic): \\${stats1['totalDevices']} devices, \\${stats1['discoverySpanMs']}ms span');
    print(
        'Test 2 (Periodic): \\${stats2['totalDevices']} devices, \\${stats2['discoverySpanMs']}ms span');
    print('\n🏁 All tests completed');
  } finally {
    print('🧹 Cleaning up resources...');
    mdnsFfi.dispose();
    await Future.delayed(Duration(milliseconds: 500));
    print('✅ Cleanup completed');
  }
}
