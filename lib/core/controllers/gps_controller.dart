import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Trans;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
bool _notificationsInitialized = false;

Future<void> _initNotifications() async {
  if (kIsWeb) return;
  if (_notificationsInitialized) return;
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await _flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );
  _notificationsInitialized = true;
}

const _trackingNotificationAndroid = AndroidNotificationDetails(
  'tracking_alerts',
  'Tracking Alerts',
  channelDescription: 'Heads-up notifications for tracking status',
  importance: Importance.max,
  priority: Priority.high,
  ticker: 'ticker',
);

const _trackingNotificationDetails =
    NotificationDetails(android: _trackingNotificationAndroid);

Future<void> _showTrackingStartedNotification() async {
  if (kIsWeb) return;
  await _initNotifications();
  await _flutterLocalNotificationsPlugin.show(
    id: 0,
    title: 'tracking_started_notification_title'.tr(),
    body: 'tracking_started_notification_body'.tr(),
    notificationDetails: _trackingNotificationDetails,
  );
}

Future<void> _showTrackingStoppedNotification() async {
  if (kIsWeb) return;
  await _initNotifications();
  await _flutterLocalNotificationsPlugin.show(
    id: 1,
    title: 'tracking_stopped_notification_title'.tr(),
    body: 'tracking_stopped_notification_body'.tr(),
    notificationDetails: _trackingNotificationDetails,
  );
}

class GpsController extends GetxController {
  final ApiClient _api;

  GpsController(this._api);

  // ── Thresholds ────────────────────────────────────────────
  static const int _intervalSeconds = 30;
  static const double _minDistMeters = 30.0;
  static const double _emaAlpha = 0.2;

  // ── Observable state ──────────────────────────────────────
  final RxBool isTracking = false.obs;
  final RxDouble speed = 0.0.obs;
  final Rx<double?> latitude = Rx<double?>(null);
  final Rx<double?> longitude = Rx<double?>(null);
  final Rx<String?> error = Rx<String?>(null);
  final Rx<DateTime?> lastSentAt = Rx<DateTime?>(null);

  // ── Internals ─────────────────────────────────────────────
  StreamSubscription<Position>? _posStream;
  Timer? _timer;
  Position? _lastSent;
  DateTime? _lastSentAt;
  int? _routeId;
  double? _smoothedSpeedKmh;

  // ── Start tracking ────────────────────────────────────────
  Future<String?> start({int? routeId}) async {
    error.value = null;

    // 1. Check service enabled
    if (!await Geolocator.isLocationServiceEnabled()) {
      error.value = 'gps_disabled';
      return 'gps_disabled';
    }

    // Request notification permission for foreground service on Android 13+
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await Permission.notification.request();
    }

    // 2. Check / request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      error.value = 'location_permission_title';
      return 'location_permission_title';
    }

    _routeId = routeId;

    // 3. Subscribe to position stream
    LocationSettings locationSettings;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'Tracking your route in the background',
          notificationTitle: 'School Driver Tracking',
          enableWakeLock: true,
        ),
      );
    } else if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS)) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    _posStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPosition,
      onError: (_) {},
      cancelOnError: false,
    );

    // 4. Fallback timer
    _timer = Timer.periodic(
      const Duration(seconds: _intervalSeconds),
      (_) async {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          await _sendLocation(pos);
        } catch (_) {}
      },
    );

    isTracking.value = true;
    _showTrackingStartedNotification();
    return null;
  }

  // ── Stop tracking ─────────────────────────────────────────
  Future<void> stop() async {
    _posStream?.cancel();
    _timer?.cancel();
    _posStream = null;
    _timer = null;
    _lastSent = null;
    _lastSentAt = null;

    try {
      await _api.post('/bus/stop-tracking');
    } catch (_) {}

    // Clear attendance keys for today when tracking is stopped
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      for (final key in keys) {
        if (key.startsWith('attendance_') && key.contains(today)) {
          await prefs.remove(key);
        }
      }
    } catch (_) {
      // Ignore
    }

    _smoothedSpeedKmh = null;
    isTracking.value = false;
    speed.value = 0;
    latitude.value = null;
    longitude.value = null;
    error.value = null;
    lastSentAt.value = null;

    _showTrackingStoppedNotification();
  }

  // ── Position update from stream ───────────────────────────
  void _onPosition(Position pos) {
    final rawSpeedKmh = (pos.speed < 0 ? 0.0 : pos.speed) * 3.6;
    _smoothedSpeedKmh = _smoothedSpeedKmh == null
        ? rawSpeedKmh
        : _emaAlpha * rawSpeedKmh + (1 - _emaAlpha) * _smoothedSpeedKmh!;

    final displaySpeed = _smoothedSpeedKmh! < 0.5 ? 0.0 : _smoothedSpeedKmh!;

    speed.value = displaySpeed;
    latitude.value = pos.latitude;
    longitude.value = pos.longitude;

    final now = DateTime.now();
    final timeDiff = _lastSentAt == null
        ? _intervalSeconds + 1
        : now.difference(_lastSentAt!).inSeconds;
    final distDiff = _lastSent == null
        ? double.infinity
        : _haversine(
            _lastSent!.latitude,
            _lastSent!.longitude,
            pos.latitude,
            pos.longitude,
          );

    if (timeDiff >= _intervalSeconds || distDiff >= _minDistMeters) {
      _sendLocation(pos);
    }
  }

  // ── Send to backend ───────────────────────────────────────
  Future<void> _sendLocation(Position pos) async {
    final speedKmh =
        _smoothedSpeedKmh ?? ((pos.speed < 0 ? 0.0 : pos.speed) * 3.6);
    try {
      await _api.post('/bus/location', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'speed': speedKmh,
        'heading': pos.heading,
        'accuracy': pos.accuracy,
        if (_routeId != null) 'route_id': _routeId,
      });

      _lastSent = pos;
      _lastSentAt = DateTime.now();
      latitude.value = pos.latitude;
      longitude.value = pos.longitude;
      lastSentAt.value = _lastSentAt;
    } catch (_) {}
  }

  // ── Haversine distance formula ────────────────────────────
  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  void onClose() {
    _posStream?.cancel();
    _timer?.cancel();
    super.onClose();
  }
}
