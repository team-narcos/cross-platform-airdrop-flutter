class DeviceModel {
  final String id;
  final String name;
  final String ipAddress;
  final DeviceType type;
  final bool isOnline;
  final DateTime lastSeen;
  final int port;

  const DeviceModel({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.type,
    this.isOnline = false,
    required this.lastSeen,
    this.port = 8080,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      ipAddress: json['ipAddress'] as String,
      type: DeviceType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => DeviceType.unknown,
      ),
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      port: json['port'] as int? ?? 8080,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ipAddress': ipAddress,
      'type': type.toString().split('.').last,
      'isOnline': isOnline,
      'lastSeen': lastSeen.toIso8601String(),
      'port': port,
    };
  }

  DeviceModel copyWith({
    String? id,
    String? name,
    String? ipAddress,
    DeviceType? type,
    bool? isOnline,
    DateTime? lastSeen,
    int? port,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      type: type ?? this.type,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      port: port ?? this.port,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DeviceModel(id: $id, name: $name, ipAddress: $ipAddress, type: $type, isOnline: $isOnline)';
  }
}

enum DeviceType {
  android,
  ios,
  windows,
  macos,
  linux,
  unknown,
}

extension DeviceTypeExtension on DeviceType {
  String get displayName {
    switch (this) {
      case DeviceType.android:
        return 'Android';
      case DeviceType.ios:
        return 'iOS';
      case DeviceType.windows:
        return 'Windows';
      case DeviceType.macos:
        return 'macOS';
      case DeviceType.linux:
        return 'Linux';
      case DeviceType.unknown:
        return 'Unknown';
    }
  }

  String get iconAsset {
    switch (this) {
      case DeviceType.android:
        return '📱';
      case DeviceType.ios:
        return '📱';
      case DeviceType.windows:
        return '💻';
      case DeviceType.macos:
        return '💻';
      case DeviceType.linux:
        return '💻';
      case DeviceType.unknown:
        return '❓';
    }
  }
}