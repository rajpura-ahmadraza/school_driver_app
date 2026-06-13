import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:school_driver_app/features/home/notification_service.dart';
import 'core/controllers/app_bindings.dart';
import 'core/controllers/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/services/background_tracking_service.dart';
import 'core/theme/app_theme.dart';
import 'features/tracking/gps_status_monitor.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SingleFileAssetLoader extends AssetLoader {
  const SingleFileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final jsonString = await rootBundle.loadString(path);
    final Map<String, dynamic> fullMap =
        json.decode(jsonString) as Map<String, dynamic>;
    final localeMap = fullMap[locale.languageCode];
    if (localeMap == null) {
      throw Exception('Missing locale ${locale.languageCode} in $path');
    }
    return Map<String, dynamic>.from(localeMap as Map<String, dynamic>);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('attendance_box');
  await EasyLocalization.ensureInitialized();

  // Initialize background tracking service configuration
  await initializeBackgroundService();

  // Firebase Initialization with Options
  try {
    if (kIsWeb) {
      await Firebase.initializeApp();
    } else {
      if (GetPlatform.isAndroid) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyCmL0xq-K7Ax-NrO9VEHGDg8evkeyJlQZ8',
            appId: '1:30883525731:android:416c9d0f5bec2509887456',
            messagingSenderId: '30883525731',
            projectId: 'school-management-19ee2',
            storageBucket: 'school-management-19ee2.firebasestorage.app',
          ),
        );
      } else if (GetPlatform.isIOS) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyCmL0xq-K7Ax-NrO9VEHGDg8evkeyJlQZ8',
            appId: '1:30883525731:android:416c9d0f5bec2509887456',
            messagingSenderId: '30883525731',
            projectId: 'school-management-19ee2',
            storageBucket: 'school-management-19ee2.firebasestorage.app',
            iosBundleId: 'com.school.teacher_app',
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
    }

    debugPrint('Firebase initialized successfully');

    // Background Notifications Handler
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      // Local Notification Service
      await NotificationService.instance.init();
      NotificationService.instance.listenToTokenRefresh();

      try {
        final token = await FirebaseMessaging.instance.getToken();
        debugPrint('📱 FCM Token: $token');
      } catch (e) {
        debugPrint('Failed to get FCM token: $e');
      }
    }
  } catch (e) {
    debugPrint('Failed to initialize Firebase or Notifications: $e');
  }

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize all GetX controllers before app starts
  AppBindings().dependencies();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('gu'),
      ],
      path: 'assets/translations/translations.json',
      assetLoader: const SingleFileAssetLoader(),
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildAppRouter();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Get.find<LocaleController>().syncFromContext(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final locale = Get.find<LocaleController>().currentLocale.value;

      return MaterialApp.router(
        title: 'School Driver',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        routerConfig: _router,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: locale,
        builder: (context, child) {
          return GpsStatusMonitor(
            child: KeyedSubtree(
              key: ValueKey(locale.languageCode),
              child: child!,
            ),
          );
        },
      );
    });
  }
}
