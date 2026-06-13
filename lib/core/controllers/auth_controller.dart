import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../../features/home/notification_service.dart';

const _lastEmailKey = 'last_login_email';

class AuthController extends GetxController {
  final ApiClient _api;

  AuthController(this._api);

  // ── Observable state ─────────────────────────────────────
  final Rx<String?> token = Rx<String?>(null);
  final Rx<Map<String, dynamic>?> user = Rx<Map<String, dynamic>?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isInitializing = true.obs;
  final Rx<String?> error = Rx<String?>(null);

  bool get isAuthenticated => token.value != null && token.value!.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  // ── App Start ─────────────────────────────────────────────
  Future<void> _initialize() async {
    try {
      isInitializing.value = true;

      final prefs = await SharedPreferences.getInstance();

      // Load cached token and user data from SharedPreferences first
      final savedToken = prefs.getString('persistent_driver_token');
      final savedUserJson = prefs.getString('persistent_driver_user');

      if (savedToken != null && savedToken.isNotEmpty) {
        token.value = savedToken;
        await _api.setToken(savedToken);
      }

      if (savedUserJson != null && savedUserJson.isNotEmpty) {
        try {
          user.value = Map<String, dynamic>.from(json.decode(savedUserJson));
        } catch (_) {}
      }

      // If we didn't get token from SharedPreferences, try secure storage as fallback
      if (token.value == null || token.value!.isEmpty) {
        final secureToken = await _api.getToken();
        if (secureToken != null && secureToken.isNotEmpty) {
          token.value = secureToken;
          await _api.setToken(secureToken);
          // Save back to SharedPreferences for reliability
          await prefs.setString('persistent_driver_token', secureToken);
        }
      }

      // If still no token, we are not logged in
      if (token.value == null || token.value!.isEmpty) {
        isInitializing.value = false;
        return;
      }

      try {
        // Verify token with server
        final response = await _api.get('/auth/me');

        final userData = Map<String, dynamic>.from(
          response.data['user'] ?? response.data,
        );

        if (userData['role'] != 'driver') {
          // Wrong role → force logout
          await logout();
          return;
        }

        user.value = userData;
        // Save the updated user data
        await prefs.setString('persistent_driver_user', json.encode(userData));

        // Update cached email
        final email = userData['email']?.toString();
        if (email != null && email.isNotEmpty) {
          await prefs.setString(_lastEmailKey, email);
        }
      } on ApiException catch (e) {
        if (e.isUnauthorized) {
          // 401 → token invalid/expired → logout
          await logout();
          return;
        } else {
          // Server/network error → keep session alive with saved token and user data
        }
      } catch (_) {
        // Network unavailable or timeout → stay logged in with saved token and user data
      }

      isInitializing.value = false;
    } catch (e) {
      // Unexpected error → logout
      await logout();
    }
  }

  // ── Login ─────────────────────────────────────────────────
  Future<String?> login(String email, String password) async {
    try {
      isLoading.value = true;
      error.value = null;

      final deviceInfo = await _getDeviceInfo();
      final userFcm = await NotificationService.instance.getFCMToken();

      final loginData = {
        'email': email.trim(),
        'password': password,
        'device_id': userFcm?.toString() ?? ' ',
        'fcm_token': userFcm?.toString() ?? ' ',
        'device_info': deviceInfo['device_model']?.toString() ?? 'Unknown',
        'device_type': deviceInfo['device_type']?.toString() ?? 'Unknown',
        'device_model': deviceInfo['device_model']?.toString() ?? 'Unknown',
        'device_platform':
            deviceInfo['device_platform']?.toString() ?? 'Unknown',
        'device_uuid': deviceInfo['device_uuid']?.toString() ?? 'Unknown',
        'device_version': deviceInfo['device_version']?.toString() ?? 'Unknown',
        'device_manufacturer':
            deviceInfo['device_manufacturer']?.toString() ?? 'Unknown',
        'device_IsVirtual':
            deviceInfo['device_IsVirtual']?.toString() ?? 'false',
        'app_version_code': '1',
      };

      // ignore: avoid_print
      print("Login Request Parameters: $loginData");

      final response = await _api.post(
        '/auth/login',
        loginData,
      );

      final data = Map<String, dynamic>.from(response.data);
      final newToken = data['access_token']?.toString() ?? '';
      final userData = Map<String, dynamic>.from(data['user'] ?? {});

      if (newToken.isEmpty) {
        throw const ApiException('Token not found', 500);
      }

      if (userData['role'] != 'driver') {
        isLoading.value = false;
        error.value = 'access_denied';
        return 'access_denied';
      }

      await _api.setToken(newToken);

      // Successful login -> save token, user and email to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastEmailKey, email.trim());
      await prefs.setString('persistent_driver_token', newToken);
      await prefs.setString('persistent_driver_user', json.encode(userData));

      token.value = newToken;
      user.value = userData;
      isLoading.value = false;
      error.value = null;

      return null; // null = success
    } on ApiException catch (e) {
      final msg = e.isUnauthorized ? 'invalid_credentials' : e.message;
      isLoading.value = false;
      error.value = msg;
      return msg;
    } catch (e) {
      isLoading.value = false;
      error.value = 'login_failed';
      return 'login_failed';
    }
  }

  // ── Forgot Password ───────────────────────────────────────
  Future<Map<String, dynamic>?> forgotPassword(String email) async {
    try {
      isLoading.value = true;
      error.value = null;

      final response = await _api.post(
        '/auth/forgot-password',
        {'email': email.trim()},
      );

      isLoading.value = false;
      return Map<String, dynamic>.from(response.data as Map? ?? {});
    } on ApiException catch (e) {
      isLoading.value = false;
      error.value = e.message;
      return {'error': e.message};
    } catch (e) {
      isLoading.value = false;
      error.value = 'forgot_password_failed';
      return {'error': 'forgot_password_failed'};
    }
  }

  // ── Logout ────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}

    await _api.clearToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('persistent_driver_token');
    await prefs.remove('persistent_driver_user');
    await prefs.remove(_lastEmailKey);

    token.value = null;
    user.value = null;
    isLoading.value = false;
    error.value = null;
    isInitializing.value = false;
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    Map<String, dynamic> deviceData = {
      'device_model': 'Unknown',
      'device_type': 'Unknown',
      'device_platform': 'Unknown',
      'device_uuid': 'Unknown',
      'device_version': 'Unknown',
      'device_manufacturer': 'Unknown',
      'device_IsVirtual': 'false',
    };

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceData = {
          'device_model': androidInfo.model,
          'device_type': 'Android',
          'device_platform': 'Android ${androidInfo.version.release}',
          'device_uuid': androidInfo.id,
          'device_version': androidInfo.version.sdkInt.toString(),
          'device_manufacturer': androidInfo.manufacturer,
          'device_IsVirtual': (!androidInfo.isPhysicalDevice).toString(),
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceData = {
          'device_model': iosInfo.model,
          'device_type': 'iOS',
          'device_platform': iosInfo.systemName,
          'device_uuid': iosInfo.identifierForVendor ?? 'Unknown',
          'device_version': iosInfo.systemVersion,
          'device_manufacturer': 'Apple',
          'device_IsVirtual': (!iosInfo.isPhysicalDevice).toString(),
        };
      }
    } catch (_) {}

    return deviceData;
  }
}
