/// Represents a discovered mDNS service/device.
class DeviceInfo {
  /// The service name
  final String name;

  /// The IP address
  final String ip;

  /// The port number
  final int port;

  /// The service type (e.g., '_googlecast._tcp')
  final String serviceType;

  /// TXT record key-value pairs
  final Map<String, String> txtRecords;

  /// When this device was discovered
  final DateTime foundAt;

  /// Which query number found this device
  final int queryNumber;

  DeviceInfo({
    required this.name,
    required this.ip,
    required this.port,
    required this.serviceType,
    required this.txtRecords,
    DateTime? foundAt,
    this.queryNumber = 0,
  }) : foundAt = foundAt ?? DateTime.now();

  @override
  String toString() {
    return 'DeviceInfo{name: $name, ip: $ip, port: $port, type: $serviceType, time: ${foundAt.millisecondsSinceEpoch}, query: $queryNumber}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceInfo &&
        other.name == name &&
        other.ip == ip &&
        other.port == port &&
        other.serviceType == serviceType;
  }

  @override
  int get hashCode {
    return Object.hash(name, ip, port, serviceType);
  }

  /// Creates a copy with some fields replaced
  DeviceInfo copyWith({
    String? name,
    String? ip,
    int? port,
    String? serviceType,
    Map<String, String>? txtRecords,
    DateTime? foundAt,
    int? queryNumber,
  }) {
    return DeviceInfo(
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      serviceType: serviceType ?? this.serviceType,
      txtRecords: txtRecords ?? this.txtRecords,
      foundAt: foundAt ?? this.foundAt,
      queryNumber: queryNumber ?? this.queryNumber,
    );
  }

  /// Convert to JSON-compatible map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ip': ip,
      'port': port,
      'serviceType': serviceType,
      'txtRecords': txtRecords,
      'foundAt': foundAt.toIso8601String(),
      'queryNumber': queryNumber,
    };
  }

  /// Create from JSON-compatible map
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      serviceType: json['serviceType'] as String,
      txtRecords: Map<String, String>.from(json['txtRecords'] as Map),
      foundAt: DateTime.parse(json['foundAt'] as String),
      queryNumber: json['queryNumber'] as int? ?? 0,
    );
  }
}
