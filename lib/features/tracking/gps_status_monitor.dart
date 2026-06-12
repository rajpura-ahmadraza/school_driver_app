import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

class GpsStatusMonitor extends StatefulWidget {
  final Widget child;
  const GpsStatusMonitor({super.key, required this.child});

  @override
  State<GpsStatusMonitor> createState() => _GpsStatusMonitorState();
}

class _GpsStatusMonitorState extends State<GpsStatusMonitor> with WidgetsBindingObserver {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  StreamSubscription<ServiceStatus>? _gpsStatusSubscription;
  bool _isInForeground = true;
  bool _notificationsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    _startMonitoring();
  }

  Future<void> _initNotifications() async {
    if (kIsWeb) return;
    if (_notificationsInitialized) return;
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // When notification is clicked, bring app to foreground and check GPS
        _checkGpsStatus();
      },
    );
    _notificationsInitialized = true;
  }

  void _startMonitoring() {
    // 1. Initial check
    _checkGpsStatus();

    // 2. Stream subscription for real-time changes
    if (!kIsWeb) {
      _gpsStatusSubscription = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
        if (status == ServiceStatus.disabled) {
          _handleGpsDisabled();
        }
      });
    }
  }

  Future<void> _checkGpsStatus() async {
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      _handleGpsDisabled();
    }
  }

  void _handleGpsDisabled() {
    if (!_isInForeground) {
      _showGpsDisabledNotification();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _isInForeground = true;
      _checkGpsStatus();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isInForeground = false;
    }
  }

  Future<void> _showGpsDisabledNotification() async {
    if (kIsWeb) return;
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'gps_status_alerts',
      'GPS Status Alerts',
      channelDescription: 'Alerts when GPS is disabled',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      id: 999, // Unique ID for GPS notifications
      title: 'gps_notification_title'.tr(),
      body: 'gps_notification_body'.tr(),
      notificationDetails: platformChannelSpecifics,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
