import 'device_info.dart';

/// Utility class for analyzing discovery timing patterns
class TimingAnalyzer {
  /// Analyze the timing patterns of discovered devices
  static void analyzeTimings(List<DeviceInfo> devices) {
    if (devices.isEmpty) {
      print('📊 No devices found for timing analysis');
      return;
    }

    print('\n📊 Timing Analysis:');

    // 按服務類型分組
    final Map<String, List<DeviceInfo>> byType = {};
    for (DeviceInfo device in devices) {
      byType.putIfAbsent(device.serviceType, () => []).add(device);
    }

    // 找出第一個和最後一個發現的設備
    devices.sort((a, b) => a.foundAt.compareTo(b.foundAt));
    final firstFound = devices.first;
    final lastFound = devices.last;
    final totalSpan = lastFound.foundAt.difference(firstFound.foundAt);

    print(
        '  First device found: ${firstFound.name} (${firstFound.serviceType}) at ${formatTime(firstFound.foundAt)}');
    print(
        '  Last device found: ${lastFound.name} (${lastFound.serviceType}) at ${formatTime(lastFound.foundAt)}');
    print('  Total discovery span: ${totalSpan.inMilliseconds}ms');

    print('\n📈 Discovery pattern by service type:');
    for (String serviceType in byType.keys) {
      final typeDevices = byType[serviceType]!;
      typeDevices.sort((a, b) => a.foundAt.compareTo(b.foundAt));

      print('  $serviceType (${typeDevices.length} devices):');
      for (DeviceInfo device in typeDevices) {
        final offsetMs =
            device.foundAt.difference(firstFound.foundAt).inMilliseconds;
        print(
            '    +${offsetMs.toString().padLeft(4)}ms: ${device.name} [Query #${device.queryNumber}]');
      }
    }

    // 分析查詢模式
    print('\n🔢 Query Pattern Analysis:');
    final Map<String, Map<int, List<DeviceInfo>>> queryPattern = {};
    for (DeviceInfo device in devices) {
      queryPattern.putIfAbsent(device.serviceType, () => {});
      queryPattern[device.serviceType]!
          .putIfAbsent(device.queryNumber, () => [])
          .add(device);
    }

    for (String serviceType in queryPattern.keys) {
      final queries = queryPattern[serviceType]!;
      print('  $serviceType:');
      for (int queryNum in queries.keys.toList()..sort()) {
        final queryDevices = queries[queryNum]!;
        print('    Query #$queryNum: ${queryDevices.length} devices found');
      }
    }

    // 分析同時性
    final Map<int, List<DeviceInfo>> bySecond = {};
    for (DeviceInfo device in devices) {
      final second = (device.foundAt.millisecondsSinceEpoch / 1000).floor();
      bySecond.putIfAbsent(second, () => []).add(device);
    }

    print('\n🔍 Simultaneity Evidence:');
    bool foundSimultaneous = false;
    for (int second in bySecond.keys) {
      final secondDevices = bySecond[second]!;
      if (secondDevices.length > 1) {
        final serviceTypes = secondDevices.map((d) => d.serviceType).toSet();
        if (serviceTypes.length > 1) {
          foundSimultaneous = true;
          print(
              '  Second $second: Found ${secondDevices.length} devices from ${serviceTypes.length} different service types');
          for (DeviceInfo device in secondDevices) {
            print(
                '    - ${device.name} (${device.serviceType}) [Query #${device.queryNumber}]');
          }
        }
      }
    }

    if (foundSimultaneous) {
      print(
          '\n✅ CONFIRMED: Multiple service types discovered in the same time period');
      print('   This proves simultaneous scanning is working!');
    } else {
      print('\n⚠️  No clear evidence of simultaneous discovery found');
      print(
          '   Devices might be discovered too quickly or sparsely to show overlap');
    }
  }

  /// Format a DateTime as HH:mm:ss.SSS
  static String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}.${time.millisecond.toString().padLeft(3, '0')}';
  }

  /// Get timing statistics for a list of devices
  static Map<String, dynamic> getStatistics(List<DeviceInfo> devices) {
    if (devices.isEmpty) {
      return {
        'totalDevices': 0,
        'serviceTypes': 0,
        'discoverySpanMs': 0,
        'simultaneousDiscoveries': false,
      };
    }

    devices.sort((a, b) => a.foundAt.compareTo(b.foundAt));
    final firstFound = devices.first;
    final lastFound = devices.last;
    final totalSpan = lastFound.foundAt.difference(firstFound.foundAt);

    // 按服務類型分組
    final Map<String, List<DeviceInfo>> byType = {};
    for (DeviceInfo device in devices) {
      byType.putIfAbsent(device.serviceType, () => []).add(device);
    }

    // 檢查同時性
    final Map<int, List<DeviceInfo>> bySecond = {};
    for (DeviceInfo device in devices) {
      final second = (device.foundAt.millisecondsSinceEpoch / 1000).floor();
      bySecond.putIfAbsent(second, () => []).add(device);
    }

    bool foundSimultaneous = false;
    for (int second in bySecond.keys) {
      final secondDevices = bySecond[second]!;
      if (secondDevices.length > 1) {
        final serviceTypes = secondDevices.map((d) => d.serviceType).toSet();
        if (serviceTypes.length > 1) {
          foundSimultaneous = true;
          break;
        }
      }
    }

    return {
      'totalDevices': devices.length,
      'serviceTypes': byType.keys.length,
      'discoverySpanMs': totalSpan.inMilliseconds,
      'simultaneousDiscoveries': foundSimultaneous,
      'firstFoundAt': firstFound.foundAt.toIso8601String(),
      'lastFoundAt': lastFound.foundAt.toIso8601String(),
      'devicesByType': byType.map((k, v) => MapEntry(k, v.length)),
    };
  }
}
