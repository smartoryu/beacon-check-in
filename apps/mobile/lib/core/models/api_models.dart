enum UserRole {
  superAdmin,
  admin,
  user;

  static UserRole fromString(String? value) {
    switch (value) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.user;
    }
  }

  String get value => switch (this) {
    UserRole.superAdmin => 'super_admin',
    UserRole.admin => 'admin',
    UserRole.user => 'user',
  };

  bool get isAdmin => this == UserRole.admin || this == UserRole.superAdmin;
}

class User {
  const User({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.mustChangePassword,
    this.deletedAt,
  });

  final String id;
  final String displayName;
  final String email;
  final UserRole role;
  final bool mustChangePassword;
  final DateTime? deletedAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    displayName: (json['display_name'] ?? '') as String,
    email: (json['email'] ?? '') as String,
    role: UserRole.fromString(json['role'] as String?),
    mustChangePassword: json['must_change_password'] == true,
    deletedAt: _date(json['deleted_at']),
  );
}

class AuthResponse {
  const AuthResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final User user;
  final String accessToken;
  final String refreshToken;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    user: User.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
  );
}

class Beacon {
  const Beacon({
    required this.id,
    required this.identityKey,
    required this.proximityUuid,
    required this.major,
    required this.minor,
    required this.label,
    this.localName,
    this.platformDeviceId,
    this.deviceAddressType,
    this.txPower,
    this.metadata,
    this.gattInfo,
    this.lastSeenAt,
    this.deletedAt,
  });

  final String id;
  final String identityKey;
  final String proximityUuid;
  final int major;
  final int minor;
  final String label;
  final String? localName;
  final String? platformDeviceId;
  final String? deviceAddressType;
  final int? txPower;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? gattInfo;
  final DateTime? lastSeenAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  factory Beacon.fromJson(Map<String, dynamic> json) => Beacon(
    id: json['id'] as String,
    identityKey: json['identity_key'] as String,
    proximityUuid: json['proximity_uuid'] as String,
    major: (json['major'] as num).toInt(),
    minor: (json['minor'] as num).toInt(),
    label: (json['label'] ?? '') as String,
    localName: json['local_name'] as String?,
    platformDeviceId: json['platform_device_id'] as String?,
    deviceAddressType: json['device_address_type'] as String?,
    txPower: (json['tx_power'] as num?)?.toInt(),
    metadata: _map(json['metadata']),
    gattInfo: _map(json['gatt_info']),
    lastSeenAt: _date(json['last_seen_at']),
    deletedAt: _date(json['deleted_at']),
  );
}

class EventBeacon {
  const EventBeacon({
    required this.beaconId,
    required this.identityKey,
    required this.label,
    this.txPower,
    this.txPowerOverride,
    this.x = 0,
    this.y = 0,
    this.beaconDeletedAt,
    this.latitude,
    this.longitude,
    this.locationAccuracyM,
    this.locationSource,
    this.locationConfirmedAt,
    this.locationConfirmedBy,
    this.locationConfirmedByName,
  });

  final String beaconId;
  final String identityKey;
  final String label;
  final int? txPower;
  final int? txPowerOverride;
  final double x;
  final double y;
  final DateTime? beaconDeletedAt;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracyM;
  final String? locationSource;
  final DateTime? locationConfirmedAt;
  final String? locationConfirmedBy;
  final String? locationConfirmedByName;

  int? get effectiveTxPower => txPowerOverride ?? txPower;
  bool get hasConfirmedLocation => latitude != null && longitude != null;

  factory EventBeacon.fromJson(Map<String, dynamic> json) => EventBeacon(
    beaconId: json['beacon_id'] as String,
    identityKey: json['identity_key'] as String,
    label: (json['label'] ?? '') as String,
    txPower: (json['tx_power'] as num?)?.toInt(),
    txPowerOverride: (json['tx_power_override'] as num?)?.toInt(),
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    beaconDeletedAt: _date(json['beacon_deleted_at']),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    locationAccuracyM: (json['location_accuracy_m'] as num?)?.toDouble(),
    locationSource: json['location_source'] as String?,
    locationConfirmedAt: _date(json['location_confirmed_at']),
    locationConfirmedBy: json['location_confirmed_by'] as String?,
    locationConfirmedByName: json['location_confirmed_by_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'beacon_id': beaconId,
    'identity_key': identityKey,
    'label': label,
    'tx_power': txPower,
    'tx_power_override': txPowerOverride,
    'x': x,
    'y': y,
    'beacon_deleted_at': beaconDeletedAt?.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'location_accuracy_m': locationAccuracyM,
    'location_source': locationSource,
    'location_confirmed_at': locationConfirmedAt?.toIso8601String(),
    'location_confirmed_by': locationConfirmedBy,
    'location_confirmed_by_name': locationConfirmedByName,
  };
}

class EventBeaconInput {
  const EventBeaconInput({
    required this.beaconId,
    required this.x,
    required this.y,
    this.txPowerOverride,
  });

  final String beaconId;
  final double x;
  final double y;
  final int? txPowerOverride;

  Map<String, dynamic> toJson() => {
    'beacon_id': beaconId,
    'x': x,
    'y': y,
    'tx_power_override': txPowerOverride,
  };
}

class EventInput {
  const EventInput({
    required this.title,
    required this.placeName,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.floorWidthM,
    required this.floorHeightM,
    required this.rssiThresholdDbm,
    required this.minBeacons,
    required this.pathLossExponent,
    required this.beacons,
    this.description,
    this.address,
    this.coverageRadiusM,
  });

  final String title;
  final String? description;
  final String placeName;
  final String? address;
  final DateTime startsAt;
  final DateTime endsAt;
  final String timezone;
  final double floorWidthM;
  final double floorHeightM;
  final int rssiThresholdDbm;
  final int minBeacons;
  final double? coverageRadiusM;
  final double pathLossExponent;
  final List<EventBeaconInput> beacons;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'place_name': placeName,
    'address': address,
    'latitude': null,
    'longitude': null,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    'timezone': timezone,
    'floor_width_m': floorWidthM,
    'floor_height_m': floorHeightM,
    'rssi_threshold_dbm': rssiThresholdDbm,
    'min_beacons': minBeacons,
    'coverage_radius_m': coverageRadiusM,
    'path_loss_exponent': pathLossExponent,
    'beacons': beacons.map((beacon) => beacon.toJson()).toList(),
  };
}

class EventBeaconLocationHistory {
  const EventBeaconLocationHistory({
    required this.id,
    required this.eventId,
    required this.beaconId,
    required this.latitude,
    required this.longitude,
    required this.source,
    required this.createdAt,
    this.accuracyM,
    this.recordedBy,
    this.recordedByName,
  });

  final String id;
  final String eventId;
  final String beaconId;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final String source;
  final String? recordedBy;
  final String? recordedByName;
  final DateTime createdAt;

  factory EventBeaconLocationHistory.fromJson(Map<String, dynamic> json) =>
      EventBeaconLocationHistory(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        beaconId: json['beacon_id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
        source: (json['source'] ?? 'gps') as String,
        recordedBy: json['recorded_by'] as String?,
        recordedByName: json['recorded_by_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class Event {
  const Event({
    required this.id,
    required this.title,
    required this.placeName,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.floorWidthM,
    required this.floorHeightM,
    required this.rssiThresholdDbm,
    required this.minBeacons,
    required this.pathLossExponent,
    required this.beacons,
    this.description,
    this.address,
    this.coverageRadiusM,
    this.checkinCount = 0,
  });

  final String id;
  final String title;
  final String? description;
  final String placeName;
  final String? address;
  final DateTime startsAt;
  final DateTime endsAt;
  final String timezone;
  final double floorWidthM;
  final double floorHeightM;
  final int rssiThresholdDbm;
  final int minBeacons;
  final double? coverageRadiusM;
  final double pathLossExponent;
  final List<EventBeacon> beacons;
  final int checkinCount;

  bool get isOngoing {
    final now = DateTime.now().toUtc();
    return !now.isBefore(startsAt.toUtc()) && !now.isAfter(endsAt.toUtc());
  }

  bool get isUpcoming => DateTime.now().toUtc().isBefore(startsAt.toUtc());

  factory Event.fromJson(Map<String, dynamic> json) => Event(
    id: json['id'] as String,
    title: (json['title'] ?? '') as String,
    description: json['description'] as String?,
    placeName: (json['place_name'] ?? '') as String,
    address: json['address'] as String?,
    startsAt: DateTime.parse(json['starts_at'] as String),
    endsAt: DateTime.parse(json['ends_at'] as String),
    timezone: (json['timezone'] ?? 'Asia/Jakarta') as String,
    floorWidthM: (json['floor_width_m'] as num?)?.toDouble() ?? 20,
    floorHeightM: (json['floor_height_m'] as num?)?.toDouble() ?? 20,
    rssiThresholdDbm: (json['rssi_threshold_dbm'] as num?)?.toInt() ?? -75,
    minBeacons: (json['min_beacons'] as num?)?.toInt() ?? 1,
    coverageRadiusM: (json['coverage_radius_m'] as num?)?.toDouble(),
    pathLossExponent: (json['path_loss_exponent'] as num?)?.toDouble() ?? 2,
    beacons: ((json['beacons'] as List<dynamic>?) ?? const [])
        .map(
          (item) =>
              EventBeacon.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    checkinCount: (json['checkin_count'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'place_name': placeName,
    'address': address,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    'timezone': timezone,
    'floor_width_m': floorWidthM,
    'floor_height_m': floorHeightM,
    'rssi_threshold_dbm': rssiThresholdDbm,
    'min_beacons': minBeacons,
    'coverage_radius_m': coverageRadiusM,
    'path_loss_exponent': pathLossExponent,
    'beacons': beacons.map((beacon) => beacon.toJson()).toList(),
    'checkin_count': checkinCount,
  };
}

class CheckinReadingInput {
  const CheckinReadingInput({
    required this.identityKey,
    required this.rssiSamples,
    this.txPower,
    this.platformDeviceId,
  });

  final String identityKey;
  final List<int> rssiSamples;
  final int? txPower;
  final String? platformDeviceId;

  Map<String, dynamic> toJson() => {
    'identity_key': identityKey,
    'rssi_samples': rssiSamples,
    'tx_power': txPower,
    'platform_device_id': platformDeviceId,
  };

  factory CheckinReadingInput.fromJson(Map<String, dynamic> json) =>
      CheckinReadingInput(
        identityKey: json['identity_key'] as String,
        rssiSamples: ((json['rssi_samples'] as List<dynamic>?) ?? const [])
            .map((value) => (value as num).toInt())
            .toList(),
        txPower: (json['tx_power'] as num?)?.toInt(),
        platformDeviceId: json['platform_device_id'] as String?,
      );
}

class Checkin {
  const Checkin({
    required this.id,
    required this.clientCheckinId,
    required this.eventId,
    required this.userId,
    required this.status,
    required this.recordedAt,
    required this.receivedAt,
    required this.usedBeaconCount,
    this.rejectReason,
    this.estimatedX,
    this.estimatedY,
    this.accuracyM,
  });

  final String id;
  final String clientCheckinId;
  final String eventId;
  final String userId;
  final String status;
  final String? rejectReason;
  final DateTime recordedAt;
  final DateTime receivedAt;
  final int usedBeaconCount;
  final double? estimatedX;
  final double? estimatedY;
  final double? accuracyM;

  bool get isAccepted => status == 'accepted';

  factory Checkin.fromJson(Map<String, dynamic> json) => Checkin(
    id: json['id'] as String,
    clientCheckinId: (json['client_checkin_id'] ?? '') as String,
    eventId: json['event_id'] as String,
    userId: json['user_id'] as String,
    status: (json['status'] ?? 'rejected') as String,
    rejectReason: json['reject_reason'] as String?,
    recordedAt: DateTime.parse(json['recorded_at'] as String),
    receivedAt: DateTime.parse(json['received_at'] as String),
    usedBeaconCount: (json['used_beacon_count'] as num?)?.toInt() ?? 0,
    estimatedX: (json['estimated_x'] as num?)?.toDouble(),
    estimatedY: (json['estimated_y'] as num?)?.toDouble(),
    accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
  );
}

class SubmitCheckinResponse {
  const SubmitCheckinResponse({
    required this.checkin,
    required this.duplicate,
    this.reason,
  });

  final Checkin checkin;
  final bool duplicate;
  final String? reason;

  factory SubmitCheckinResponse.fromJson(Map<String, dynamic> json) =>
      SubmitCheckinResponse(
        checkin: Checkin.fromJson(
          Map<String, dynamic>.from(json['checkin'] as Map),
        ),
        duplicate: json['duplicate'] == true,
        reason: json['reason'] as String?,
      );
}

class BeaconLookupItem {
  const BeaconLookupItem({
    required this.identityKey,
    required this.status,
    this.beacon,
  });

  final String identityKey;
  final String status; // registered | deleted | unknown
  final Beacon? beacon;
}

DateTime? _date(dynamic value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
