import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Load configuration details from Shared Preferences
  // GpsController will save these details before starting the service
  final token = prefs.getString('driver_jwt_token');
  final routeId = prefs.getInt('tracking_route_id');
  const baseUrl =
      'https://laravel-api.emaad-infotech.com/school-management-system/api/v1/';

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  ));

  // Tracking Thresholds (matching GpsController)
  const int intervalSeconds = 30;
  const double minDistMeters = 30.0;
  const double emaAlpha = 0.2;

  Position? lastSent;
  DateTime? lastSentAt;
  double? smoothedSpeedKmh;
  bool isOffline = false;
  bool isAppInForeground = false;

  service.on('app_lifecycle').listen((event) {
    if (event != null) {
      isAppInForeground = event['state'] == 'foreground';
    }
  });

  final localNotifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await localNotifications.initialize(
    settings: const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  double haversine(double lat1, double lon1, double lat2, double lon2) {
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

  Future<void> sendLocation(Position pos) async {
    final speedKmh =
        smoothedSpeedKmh ?? ((pos.speed < 0 ? 0.0 : pos.speed) * 3.6);
    final displaySpeed = smoothedSpeedKmh == null
        ? 0.0
        : (smoothedSpeedKmh! < 0.5 ? 0.0 : smoothedSpeedKmh!);
    try {
      await dio.post('/bus/location', data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'speed': speedKmh,
        'heading': pos.heading,
        'accuracy': pos.accuracy,
        if (routeId != null) 'route_id': routeId,
      });

      lastSent = pos;
      lastSentAt = DateTime.now();

      // If we were offline, notify recovery
      if (isOffline) {
        isOffline = false;
        await prefs.setBool('background_tracking_offline', false);
        service.invoke('network_status', {'online': true});

        if (!isAppInForeground) {
          await localNotifications.show(
            id: 8888,
            title: 'GPS Tracking Active',
            body: 'Internet restored. GPS tracking has resumed.',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                importance: Importance.high,
                priority: Priority.high,
                playSound: true,
              ),
            ),
          );
        }
      }

      // Update foreground notification info
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'School Driver Tracking',
          content: 'Speed: ${displaySpeed.toStringAsFixed(1)} km/h',
        );
      }

      // Send update to UI
      service.invoke('location_update', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'speed': displaySpeed,
        'lastSentAt': lastSentAt?.toIso8601String(),
      });
    } catch (_) {
      // If we were online, notify disconnect
      if (!isOffline) {
        isOffline = true;
        await prefs.setBool('background_tracking_offline', true);
        service.invoke('network_status', {'online': false});

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'School Driver Tracking (Offline)',
            content: 'No internet connection. Tracking paused.',
          );
        }

        if (!isAppInForeground) {
          await localNotifications.show(
            id: 8888,
            title: 'GPS Tracking Paused',
            body: 'No internet connection. GPS tracking will resume when online.',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                importance: Importance.high,
                priority: Priority.high,
                playSound: true,
              ),
            ),
          );
        }
      }
    }
  }

  void onPosition(Position pos) {
    final rawSpeedKmh = (pos.speed < 0 ? 0.0 : pos.speed) * 3.6;
    smoothedSpeedKmh = smoothedSpeedKmh == null
        ? rawSpeedKmh
        : emaAlpha * rawSpeedKmh + (1 - emaAlpha) * smoothedSpeedKmh!;

    final displaySpeed = smoothedSpeedKmh! < 0.5 ? 0.0 : smoothedSpeedKmh!;

    // Send location update to UI for real-time speed display
    service.invoke('location_update', {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'speed': displaySpeed,
      'lastSentAt': lastSentAt?.toIso8601String(),
    });

    if (service is AndroidServiceInstance) {
      if (!isOffline) {
        service.setForegroundNotificationInfo(
          title: 'School Driver Tracking',
          content: 'Speed: ${displaySpeed.toStringAsFixed(1)} km/h',
        );
      } else {
        service.setForegroundNotificationInfo(
          title: 'School Driver Tracking (Offline)',
          content: 'No internet connection. Tracking paused.',
        );
      }
    }

    final now = DateTime.now();
    final timeDiff = lastSentAt == null
        ? intervalSeconds + 1
        : now.difference(lastSentAt!).inSeconds;
    final distDiff = lastSent == null
        ? double.infinity
        : haversine(
            lastSent!.latitude,
            lastSent!.longitude,
            pos.latitude,
            pos.longitude,
          );

    if (timeDiff >= intervalSeconds || distDiff >= minDistMeters) {
      sendLocation(pos);
    }
  }

  // Geolocation Settings
  LocationSettings locationSettings;
  if (defaultTargetPlatform == TargetPlatform.android) {
    locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      forceLocationManager: true,
      intervalDuration: const Duration(seconds: 10),
    );
  } else {
    locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  // Start tracking position stream
  final StreamSubscription<Position> posStream = Geolocator.getPositionStream(
    locationSettings: locationSettings,
  ).listen(
    onPosition,
    onError: (_) {},
    cancelOnError: false,
  );

  // Fallback timer to force location update if stationary but timer elapsed
  final Timer timer = Timer.periodic(
    const Duration(seconds: intervalSeconds),
    (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        await sendLocation(pos);
      } catch (_) {}
    },
  );

  // Listen for stop request
  service.on('stopService').listen((event) async {
    await posStream.cancel();
    timer.cancel();
    await service.stopSelf();
  });
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // Create notification channel for Android before configuring the service
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground', // id
      'School Driver Tracking Service', // title
      description: 'Used for persistent location tracking of the school bus.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // We start it manually on driver action
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'School Driver Tracking',
      initialNotificationContent: 'Starting tracking...',
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}
