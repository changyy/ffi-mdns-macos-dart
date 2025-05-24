import 'package:native_mdns_scanner/native_mdns_scanner.dart';

void main() async {
  {
    final scanner = NativeMdnsScanner();
    try {
      // Scan for Chromecast devices
      scanner.startScan('_googlecast._tcp');
      // Wait for 10 seconds
      await Future.delayed(Duration(seconds: 10));
      scanner.stopScan();
      // Get results
      final devices = scanner.foundDevices;
      for (final device in devices) {
        print('Found: \\${device.name} at \\${device.ip}:\\${device.port}');
      }
    } finally {
      scanner.dispose();
    }
  }
  {
    final scanner = NativeMdnsScanner();
    final foundDevices = <DeviceInfo>[];
    await scanner.startPeriodicScanJsonWithDone(
      '_googlecast._tcp',
      (json) {
        if (json['type'] == 'device') {
          foundDevices.add(DeviceInfo(
            name: json['name'] ?? '',
            ip: json['ip'] ?? '',
            port: json['port'] ?? 0,
            serviceType: json['type_name'] ?? '',
            txtRecords: Map<String, String>.from(json['txt'] ?? {}),
            queryNumber: json['queryNumber'] ?? 0,
          ));
          print(
              'Found device: \\${json['name']} (query #\\${json['queryNumber']})');
        } else if (json['type'] == 'error') {
          print('Error: \\${json['message']}');
        }
      },
      queryIntervalMs: 3000, // 每 3 秒查詢一次
      totalDurationMs: 12000, // 共執行 12 秒
      debug: 2,
    );
  }
}
