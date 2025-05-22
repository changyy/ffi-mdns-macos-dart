import 'package:native_mdns_scanner/native_mdns_scanner.dart';

void main() async {
  final mdnsFfi = MdnsFfi();

  try {
    print(
        '🧪 Testing simultaneous vs periodic scanning with timing analysis...\n');

    final serviceTypes = ['_googlecast._tcp', '_airplay._tcp', '_raop._tcp'];

    print('=' * 60);
    print('📊 Test 1: Basic simultaneous scanning');
    print('🔍 Services: ${serviceTypes.join(', ')}\n');

    final devices1 = await mdnsFfi.scanMultipleServices(
      serviceTypes,
      timeout: Duration(seconds: 15),
    );

    print('\n📋 Test 1 Summary:');
    print('Total devices found: ${devices1.length}');

    final devicesByType1 = mdnsFfi.getDevicesByServiceType();
    for (String serviceType in devicesByType1.keys) {
      final typeDevices = devicesByType1[serviceType]!;
      print('  $serviceType: ${typeDevices.length} devices');
    }

    TimingAnalyzer.analyzeTimings(devices1);

    print('\n' + '=' * 60);
    print('📊 Test 2: Periodic simultaneous scanning');
    print('🔍 Services: ${serviceTypes.join(', ')}');
    print('📅 Query every 5 seconds for 20 seconds total\n');

    // Clear previous results
    mdnsFfi.clearFoundDevices();

    final devices2 = await mdnsFfi.scanMultipleServicesWithPeriodic(
      serviceTypes,
      timeout: Duration(seconds: 20),
      queryInterval: Duration(seconds: 5),
    );

    print('\n📋 Test 2 Summary:');
    print('Total devices found: ${devices2.length}');

    final devicesByType2 = mdnsFfi.getDevicesByServiceType();
    for (String serviceType in devicesByType2.keys) {
      final typeDevices = devicesByType2[serviceType]!;
      print('  $serviceType: ${typeDevices.length} devices');
    }

    TimingAnalyzer.analyzeTimings(devices2);

    print('\n🔢 Comparison Statistics:');
    final stats1 = TimingAnalyzer.getStatistics(devices1);
    final stats2 = TimingAnalyzer.getStatistics(devices2);

    print(
        'Test 1 (Basic): ${stats1['totalDevices']} devices, ${stats1['discoverySpanMs']}ms span');
    print(
        'Test 2 (Periodic): ${stats2['totalDevices']} devices, ${stats2['discoverySpanMs']}ms span');

    print('\n🏁 All tests completed');
  } finally {
    // 確保所有資源都被清理
    print('🧹 Cleaning up resources...');
    mdnsFfi.dispose();

    // 給一點時間讓清理完成
    await Future.delayed(Duration(milliseconds: 500));
    print('✅ Cleanup completed');
  }
}
