import 'dart:io';
import 'package:test/test.dart';
import 'package:native_mdns_scanner/native_mdns_scanner.dart';

void main() {
  group('Platform Support', () {
    test('should only run on macOS', () {
      if (!Platform.isMacOS) {
        expect(() => MdnsFfi(), throwsA(isA<UnsupportedError>()));
      } else {
        expect(() => MdnsFfi(), returnsNormally);
      }
    });
  });

  group('DeviceInfo', () {
    test('should create device with all required fields', () {
      final now = DateTime.now();
      final device = DeviceInfo(
        name: 'Test Device',
        ip: '192.168.1.100',
        port: 8080,
        serviceType: '_test._tcp',
        txtRecords: {'key': 'value'},
        foundAt: now,
        queryNumber: 1,
      );

      expect(device.name, equals('Test Device'));
      expect(device.ip, equals('192.168.1.100'));
      expect(device.port, equals(8080));
      expect(device.serviceType, equals('_test._tcp'));
      expect(device.txtRecords, equals({'key': 'value'}));
      expect(device.foundAt, equals(now));
      expect(device.queryNumber, equals(1));
    });

    test('should use current time if foundAt is not provided', () {
      final before = DateTime.now();
      final device = DeviceInfo(
        name: 'Test Device',
        ip: '192.168.1.100',
        port: 8080,
        serviceType: '_test._tcp',
        txtRecords: {},
      );
      final after = DateTime.now();

      expect(device.foundAt.isAfter(before.subtract(Duration(seconds: 1))),
          isTrue);
      expect(device.foundAt.isBefore(after.add(Duration(seconds: 1))), isTrue);
    });

    test('should support equality comparison', () {
      final device1 = DeviceInfo(
        name: 'Test Device',
        ip: '192.168.1.100',
        port: 8080,
        serviceType: '_test._tcp',
        txtRecords: {},
      );

      final device2 = DeviceInfo(
        name: 'Test Device',
        ip: '192.168.1.100',
        port: 8080,
        serviceType: '_test._tcp',
        txtRecords: {
          'different': 'records'
        }, // TXT records don't affect equality
      );

      final device3 = DeviceInfo(
        name: 'Different Device',
        ip: '192.168.1.100',
        port: 8080,
        serviceType: '_test._tcp',
        txtRecords: {},
      );

      expect(device1, equals(device2));
      expect(device1, isNot(equals(device3)));
    });

    test('should support copyWith', () {
      final original = DeviceInfo(
        name: 'Original',
        ip: '192.168.1.100',
        port: 8080,
        serviceType: '_test._tcp',
        txtRecords: {},
      );

      final copied = original.copyWith(name: 'Modified', port: 9090);

      expect(copied.name, equals('Modified'));
      expect(copied.port, equals(9090));
      expect(copied.ip, equals(original.ip));
      expect(copied.serviceType, equals(original.serviceType));
    });

    test('should convert to/from JSON', () {
      final device = DeviceInfo(
        name: 'Test Device',
        ip: '192.168.1.100',
        port: 8080,
        serviceType: '_test._tcp',
        txtRecords: {'key': 'value'},
        queryNumber: 2,
      );

      final json = device.toJson();
      final restored = DeviceInfo.fromJson(json);

      expect(restored.name, equals(device.name));
      expect(restored.ip, equals(device.ip));
      expect(restored.port, equals(device.port));
      expect(restored.serviceType, equals(device.serviceType));
      expect(restored.txtRecords, equals(device.txtRecords));
      expect(restored.queryNumber, equals(device.queryNumber));
      // Note: foundAt might have slight differences due to serialization
    });
  });

  group('TimingAnalyzer', () {
    test('should handle empty device list', () {
      final stats = TimingAnalyzer.getStatistics([]);

      expect(stats['totalDevices'], equals(0));
      expect(stats['serviceTypes'], equals(0));
      expect(stats['discoverySpanMs'], equals(0));
      expect(stats['simultaneousDiscoveries'], isFalse);
    });

    test('should calculate statistics for multiple devices', () {
      final now = DateTime.now();
      final devices = [
        DeviceInfo(
          name: 'Device1',
          ip: '192.168.1.101',
          port: 8080,
          serviceType: '_test1._tcp',
          txtRecords: {},
          foundAt: now,
        ),
        DeviceInfo(
          name: 'Device2',
          ip: '192.168.1.102',
          port: 8080,
          serviceType: '_test2._tcp',
          txtRecords: {},
          foundAt: now.add(Duration(milliseconds: 500)),
        ),
        DeviceInfo(
          name: 'Device3',
          ip: '192.168.1.103',
          port: 8080,
          serviceType: '_test1._tcp',
          txtRecords: {},
          foundAt: now.add(Duration(milliseconds: 1000)),
        ),
      ];

      final stats = TimingAnalyzer.getStatistics(devices);

      expect(stats['totalDevices'], equals(3));
      expect(stats['serviceTypes'], equals(2));
      expect(stats['discoverySpanMs'], equals(1000));
      expect(
          stats['devicesByType'], equals({'_test1._tcp': 2, '_test2._tcp': 1}));
    });

    test('should detect simultaneous discoveries', () {
      final now = DateTime.now();
      final sameSecond = (now.millisecondsSinceEpoch / 1000).floor();

      final devices = [
        DeviceInfo(
          name: 'Device1',
          ip: '192.168.1.101',
          port: 8080,
          serviceType: '_test1._tcp',
          txtRecords: {},
          foundAt: DateTime.fromMillisecondsSinceEpoch(sameSecond * 1000),
        ),
        DeviceInfo(
          name: 'Device2',
          ip: '192.168.1.102',
          port: 8080,
          serviceType: '_test2._tcp',
          txtRecords: {},
          foundAt: DateTime.fromMillisecondsSinceEpoch(sameSecond * 1000 + 500),
        ),
      ];

      final stats = TimingAnalyzer.getStatistics(devices);
      expect(stats['simultaneousDiscoveries'], isTrue);
    });

    test('should format time correctly', () {
      final time = DateTime(2025, 1, 1, 14, 30, 45, 123);
      final formatted = TimingAnalyzer.formatTime(time);
      expect(formatted, equals('14:30:45.123'));
    });
  });

  // Integration tests (only run on macOS)
  group('MdnsFfi Integration', () {
    late MdnsFfi mdnsFfi;

    setUp(() {
      if (Platform.isMacOS) {
        mdnsFfi = MdnsFfi();
      }
    });

    tearDown(() {
      if (Platform.isMacOS) {
        mdnsFfi.dispose();
      }
    });

    test('should initialize without throwing', () {
      if (!Platform.isMacOS) {
        return; // Skip on non-macOS
      }

      expect(() => MdnsFfi(), returnsNormally);
    }, skip: !Platform.isMacOS ? 'macOS only' : null);

    test('should start and stop scanning', () async {
      if (!Platform.isMacOS) {
        return;
      }

      expect(mdnsFfi.isScanning(), isFalse);

      mdnsFfi.startScan('_test._tcp');
      expect(mdnsFfi.isScanning(), isTrue);

      mdnsFfi.stopScan();
      await Future.delayed(Duration(milliseconds: 100)); // Give time to stop
      expect(mdnsFfi.isScanning(), isFalse);
    }, skip: !Platform.isMacOS ? 'macOS only' : null);

    test('should handle multiple service scanning', () async {
      if (!Platform.isMacOS) {
        return;
      }

      // Start multiple scans
      mdnsFfi.startScan('_test1._tcp');
      mdnsFfi.startScan('_test2._tcp');

      expect(mdnsFfi.isScanning(), isTrue);

      mdnsFfi.stopScan();
      await Future.delayed(Duration(milliseconds: 100));
      expect(mdnsFfi.isScanning(), isFalse);
    }, skip: !Platform.isMacOS ? 'macOS only' : null);

    test('should clear found devices', () {
      if (!Platform.isMacOS) {
        return;
      }

      expect(mdnsFfi.foundDevices, isEmpty);
      mdnsFfi.clearFoundDevices();
      expect(mdnsFfi.foundDevices, isEmpty);
    }, skip: !Platform.isMacOS ? 'macOS only' : null);

    test('should group devices by service type', () {
      if (!Platform.isMacOS) {
        return;
      }

      final grouped = mdnsFfi.getDevicesByServiceType();
      expect(grouped, isA<Map<String, List<DeviceInfo>>>());
    }, skip: !Platform.isMacOS ? 'macOS only' : null);

    test('should timeout properly in scanMultipleServices', () async {
      if (!Platform.isMacOS) {
        return;
      }

      final startTime = DateTime.now();

      // Use a very short timeout and non-existent service to test timeout
      final devices = await mdnsFfi.scanMultipleServices(
        ['_nonexistent._tcp'],
        timeout: Duration(seconds: 2),
      );

      final endTime = DateTime.now();
      final elapsed = endTime.difference(startTime);

      // Should complete within reasonable time (allowing some margin)
      expect(elapsed.inSeconds, lessThanOrEqualTo(3));
      expect(devices, isA<List<DeviceInfo>>());
    }, skip: !Platform.isMacOS ? 'macOS only' : null);
  });

  group('Service Type Validation', () {
    test('should handle common service types', () {
      final commonServices = [
        '_googlecast._tcp',
        '_airplay._tcp',
        '_raop._tcp',
        '_http._tcp',
        '_ssh._tcp',
        '_printer._tcp',
        '_ipp._tcp',
      ];

      for (final service in commonServices) {
        expect(service.startsWith('_'), isTrue,
            reason: 'Service type should start with underscore: $service');
        expect(service.endsWith('._tcp') || service.endsWith('._udp'), isTrue,
            reason: 'Service type should end with protocol: $service');
      }
    });
  });

  group('Error Handling', () {
    test('should handle library loading errors gracefully', () {
      if (!Platform.isMacOS) {
        expect(() => MdnsFfi(libraryPath: 'nonexistent.dylib'),
            throwsA(isA<ArgumentError>()));
      } else {
        expect(
            () => MdnsFfi(libraryPath: 'nonexistent.dylib'), throwsA(anything));
      }
    });
  });
}
