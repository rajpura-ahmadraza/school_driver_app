import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons, Navigator;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Trans;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../api/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_dialog.dart';
import '../router/app_router.dart';

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

  // ── Observable state ──────────────────────────────────────
  final RxBool isTracking = false.obs;
  final RxDouble speed = 0.0.obs;
  final Rx<double?> latitude = Rx<double?>(null);
  final Rx<double?> longitude = Rx<double?>(null);
  final Rx<String?> error = Rx<String?>(null);
  final Rx<DateTime?> lastSentAt = Rx<DateTime?>(null);

  // ── Suspension & Dialog state ─────────────────────────────
  bool _suspendedDueToOffline = false;
  bool _isOfflineDialogShowing = false;

  // ── Internals ─────────────────────────────────────────────
  StreamSubscription<Map<String, dynamic>?>? _serviceEventSubscription;
  StreamSubscription<Map<String, dynamic>?>? _networkStatusSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void onInit() {
    super.onInit();
    _checkRunningStatus();
    _startConnectivityListener();
  }

  void _startConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.isEmpty ||
          results.contains(ConnectivityResult.none) ||
          (!results.contains(ConnectivityResult.wifi) &&
           !results.contains(ConnectivityResult.mobile) &&
           !results.contains(ConnectivityResult.ethernet) &&
           !results.contains(ConnectivityResult.vpn));

      if (isOffline) {
        if (isTracking.value) {
          // Wait 3 seconds to confirm it's not a transient disconnect
          Future.delayed(const Duration(seconds: 3), () async {
            if (isTracking.value) {
              final doubleCheck = await Connectivity().checkConnectivity();
              final stillOffline = doubleCheck.isEmpty ||
                  doubleCheck.contains(ConnectivityResult.none) ||
                  (!doubleCheck.contains(ConnectivityResult.wifi) &&
                   !doubleCheck.contains(ConnectivityResult.mobile) &&
                   !doubleCheck.contains(ConnectivityResult.ethernet) &&
                   !doubleCheck.contains(ConnectivityResult.vpn));
              if (stillOffline) {
                _suspendedDueToOffline = true;
                _showOfflineDialog();
              }
            }
          });
        }
      } else {
        // We are online!
        if (_suspendedDueToOffline) {
          _suspendedDueToOffline = false;
          _dismissOfflineDialog();
        }
      }
    });
  }

  void _showOfflineDialog() {
    if (_isOfflineDialogShowing) return;
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      _isOfflineDialogShowing = true;
      showPremiumOneButtonDialog(
        context: context,
        icon: Icons.wifi_off_rounded,
        iconColor: AppTheme.danger,
        title: 'disconnected'.tr(),
        message: 'no_internet'.tr(),
        buttonLabel: 'confirm'.tr(),
        buttonColor: AppTheme.primary,
        onPressed: () {
          _isOfflineDialogShowing = false;
          Navigator.pop(context);
        },
      ).then((_) {
        _isOfflineDialogShowing = false;
      });
    }
  }

  void _dismissOfflineDialog() {
    if (_isOfflineDialogShowing) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        _isOfflineDialogShowing = false;
        Navigator.pop(context);
      }
    }
  }

  Future<void> _checkRunningStatus() async {
    final running = await FlutterBackgroundService().isRunning();
    if (running) {
      isTracking.value = true;
      _listenToServiceEvents();

      // Check if background service was suspended offline
      final prefs = await SharedPreferences.getInstance();
      final bgOffline = prefs.getBool('background_tracking_offline') ?? false;
      if (bgOffline) {
        _suspendedDueToOffline = true;
        _showOfflineDialog();
      }
    }
  }

  void _listenToServiceEvents() {
    _serviceEventSubscription?.cancel();
    _serviceEventSubscription = FlutterBackgroundService()
        .on('location_update')
        .listen((event) {
      if (event != null) {
        latitude.value = (event['latitude'] as num?)?.toDouble();
        longitude.value = (event['longitude'] as num?)?.toDouble();
        speed.value = (event['speed'] as num?)?.toDouble() ?? 0.0;
        if (event['lastSentAt'] != null) {
          lastSentAt.value = DateTime.tryParse(event['lastSentAt'] as String);
        }
      }
    });

    _networkStatusSubscription?.cancel();
    _networkStatusSubscription = FlutterBackgroundService()
        .on('network_status')
        .listen((event) {
      if (event != null) {
        final online = event['online'] as bool? ?? true;
        if (!online) {
          _suspendedDueToOffline = true;
          _showOfflineDialog();
        } else {
          _suspendedDueToOffline = false;
          _dismissOfflineDialog();
        }
      }
    });
  }

  Future<String?> start({int? routeId}) async {
    error.value = null;

    // Check internet connection
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      error.value = 'no_internet';
      return 'no_internet';
    }

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

    // Save configurations to SharedPreferences so the background service can access them
    final prefs = await SharedPreferences.getInstance();
    if (routeId != null) {
      await prefs.setInt('tracking_route_id', routeId);
    } else if (!prefs.containsKey('tracking_route_id')) {
      await prefs.setInt('tracking_route_id', 2);
    }
    final token = await _api.getToken();
    if (token != null) {
      await prefs.setString('driver_jwt_token', token);
    }

    // Start background tracking service
    final isRunning = await FlutterBackgroundService().isRunning();
    if (!isRunning) {
      await FlutterBackgroundService().startService();
    }

    _listenToServiceEvents();

    isTracking.value = true;
    _showTrackingStartedNotification();
    return null;
  }

  // ── Stop tracking ─────────────────────────────────────────
  Future<void> stop({bool keepSuspendedState = false}) async {
    if (!keepSuspendedState) {
      _suspendedDueToOffline = false;
    }
    FlutterBackgroundService().invoke('stopService');
    _serviceEventSubscription?.cancel();
    _serviceEventSubscription = null;

    try {
      await _api.post('/bus/stop-tracking');
    } catch (_) {}

    // Clear attendance keys for today when tracking is stopped
    try {
      final box = Hive.box('attendance_box');
      final keys = box.keys.toList();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      for (final key in keys) {
        if (key is String && key.startsWith('attendance_') && key.contains(today)) {
          await box.delete(key);
        }
      }
    } catch (_) {
      // Ignore
    }

    isTracking.value = false;
    speed.value = 0;
    latitude.value = null;
    longitude.value = null;
    error.value = null;
    lastSentAt.value = null;

    _showTrackingStoppedNotification();
  }

  @override
  void onClose() {
    _serviceEventSubscription?.cancel();
    _networkStatusSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.onClose();
  }
}

