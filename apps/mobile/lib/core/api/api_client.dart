// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../auth/token_storage.dart';
import '../config/app_config.dart';
import '../models/api_models.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({required TokenStorage tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                headers: {'Content-Type': 'application/json'},
              ),
            ) {
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          if (status == 401 && !path.contains('/auth/refresh')) {
            final refreshed = await _refreshAccessToken();
            if (refreshed) {
              try {
                final token = await _tokenStorage.readAccessToken();
                final options = error.requestOptions;
                options.headers['Authorization'] = 'Bearer $token';
                final response = await _dio.fetch<dynamic>(options);
                return handler.resolve(response);
              } catch (_) {
                // Fall through to the original error.
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  late final Dio _refreshDio;
  final TokenStorage _tokenStorage;
  Future<bool>? _refreshInFlight;

  Future<bool> _refreshAccessToken() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final future = () async {
      final refreshToken = await _tokenStorage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;
      try {
        final response = await _refreshDio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refresh_token': refreshToken},
        );
        final data = response.data;
        if (data == null) return false;
        await _tokenStorage.saveTokens(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
        );
        return true;
      } catch (_) {
        await _tokenStorage.clear();
        return false;
      } finally {
        _refreshInFlight = null;
      }
    }();

    _refreshInFlight = future;
    return future;
  }

  Future<T> _guard<T>(
    Future<Response<dynamic>> Function() call,
    T Function(dynamic data) parse,
  ) async {
    try {
      final response = await call();
      return parse(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<AuthResponse> signIn(String email, String password) {
    return _guard(
      () => _dio.post<dynamic>(
        '/auth/signin/email',
        data: {'email': email, 'password': password},
      ),
      (data) => AuthResponse.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _guard(
      () => _dio.post<dynamic>(
        '/auth/signup',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
        },
      ),
      (data) => AuthResponse.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<User> me() {
    return _guard(
      () => _dio.get<dynamic>('/auth/me'),
      (data) => User.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _guard(
      () => _dio.post<dynamic>(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'password_confirmation': newPassword,
        },
      ),
      (_) {},
    );
  }

  Future<List<Event>> activeEvents() {
    return _guard(
      () => _dio.get<dynamic>('/events/active'),
      (data) => (data as List<dynamic>)
          .map((item) => Event.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }

  Future<Event> getEvent(String id) {
    return _guard(
      () => _dio.get<dynamic>('/events/$id'),
      (data) => Event.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<List<Beacon>> listBeacons({String status = 'active'}) {
    return _guard(
      () => _dio.get<dynamic>('/beacons', queryParameters: {'status': status}),
      (data) => (data as List<dynamic>)
          .map((item) => Beacon.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }

  Future<Map<String, BeaconLookupItem>> lookupBeacons(List<String> identities) {
    return _guard(
      () => _dio.post<dynamic>('/beacons/lookup', data: {'identities': identities}),
      (data) {
        final map = Map<String, dynamic>.from(data as Map);
        final items = map['items'] as List<dynamic>? ?? const [];
        final result = <String, BeaconLookupItem>{};
        for (final item in items) {
          final json = Map<String, dynamic>.from(item as Map);
          final identity = json['identity_key'] as String;
          result[identity] = BeaconLookupItem(
            identityKey: identity,
            status: (json['status'] ?? 'unknown') as String,
            beacon: json['beacon'] == null
                ? null
                : Beacon.fromJson(Map<String, dynamic>.from(json['beacon'] as Map)),
          );
        }
        return result;
      },
    );
  }

  Future<Beacon> registerBeacon({
    required String proximityUuid,
    required int major,
    required int minor,
    required String label,
    String? localName,
    String? platformDeviceId,
    String? deviceAddressType,
    int? txPower,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? gattInfo,
    List<int>? rssiSamples,
  }) {
    return _guard(
      () => _dio.post<dynamic>('/beacons', data: {
        'proximity_uuid': proximityUuid,
        'major': major,
        'minor': minor,
        'label': label,
        'local_name': localName,
        'platform_device_id': platformDeviceId,
        'device_address_type': deviceAddressType,
        'tx_power': txPower,
        'metadata': metadata,
        'gatt_info': gattInfo,
        'rssi_samples': rssiSamples,
      }),
      (data) => Beacon.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<void> requestRestore(String beaconId, String reason) {
    return _guard(
      () => _dio.post<dynamic>('/beacons/$beaconId/restore', data: {'reason': reason}),
      (_) {},
    );
  }

  Future<SubmitCheckinResponse> submitCheckin({
    required String eventId,
    required String clientCheckinId,
    required DateTime recordedAt,
    required List<CheckinReadingInput> readings,
    Map<String, dynamic>? deviceInfo,
  }) {
    return _guard(
      () => _dio.post<dynamic>(
        '/events/$eventId/checkins',
        data: {
          'client_checkin_id': clientCheckinId,
          'recorded_at': recordedAt.toUtc().toIso8601String(),
          'readings': readings.map((reading) => reading.toJson()).toList(),
          'device_info': deviceInfo,
        },
      ),
      (data) => SubmitCheckinResponse.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<List<Checkin>> myCheckins() {
    return _guard(
      () => _dio.get<dynamic>('/me/checkins'),
      (data) => (data as List<dynamic>)
          .map((item) => Checkin.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }

  String newClientCheckinId() => const Uuid().v4();
}
