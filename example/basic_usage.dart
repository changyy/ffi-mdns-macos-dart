import 'package:native_mdns_scanner/native_mdns_scanner.dart';

void main() async {
  final mdnsFfi = MdnsFfi();

  try {
    print('🔍 Basic mDNS scanning example\n');

    // Example 1: Simple scan for Chromecast devices
    print('📱 Scanning for Chromecast devices...');
    mdnsFfi.startScan('_googlecast._tcp');

    // Wait for 10 seconds
    await Future.delayed(Duration(seconds: 10));

    mdnsFfi.stopScan();

    final devices = mdnsFfi.foundDevices;
    print('Found ${devices.length} Chromecast devices:');
    for (final device in devices) {
      print('  • ${device.name} at ${device.ip}:${device.port}');
      if (device.txtRecords.isNotEmpty) {
        print('    TXT records: ${device.txtRecords}');
      }
    }

    print('\n' + '=' * 50);

    // Example 2: Scan multiple service types
    print('🎯 Scanning multiple service types simultaneously...');

    mdnsFfi.clearFoundDevices();
    final multiDevices = await mdnsFfi.scanMultipleServices([
      '_googlecast._tcp',
      '_airplay._tcp',
      '_raop._tcp',
    ], timeout: Duration(seconds: 15));

    print('\nFound ${multiDevices.length} devices total:');
    final devicesByType = mdnsFfi.getDevicesByServiceType();

    for (final serviceType in devicesByType.keys) {
      final typeDevices = devicesByType[serviceType]!;
      print('\n$serviceType (${typeDevices.length} devices):');
      for (final device in typeDevices) {
        print('  • ${device.name} (${device.ip}:${device.port})');
      }
    }

    print('\n' + '=' * 50);

    // Example 3: Periodic scanning
    print('🔄 Periodic scanning example...');
    print('Sending queries every 3 seconds for 12 seconds total\n');

    mdnsFfi.clearFoundDevices();
    final periodicDevices = await mdnsFfi.scanMultipleServicesWithPeriodic(
      [
        '_googlecast._tcp',
      ],
      timeout: Duration(seconds: 12),
      queryInterval: Duration(seconds: 3),
    );

    print('\nPeriodic scan results:');
    for (final device in periodicDevices) {
      print(
          '  • ${device.name} found in query #${device.queryNumber} at ${TimingAnalyzer.formatTime(device.foundAt)}');
    }

    // Show timing analysis
    if (periodicDevices.isNotEmpty) {
      print('\n📊 Timing Analysis:');
      TimingAnalyzer.analyzeTimings(periodicDevices);
    }
  } catch (e) {
    print('❌ Error during scanning: $e');
  } finally {
    print('\n🧹 Cleaning up...');
    mdnsFfi.dispose();
    print('✅ Done!');
  }
}
