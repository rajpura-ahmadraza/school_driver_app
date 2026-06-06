import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart' hide Response;
import '../controllers/auth_controller.dart';

/// Live API base URL
const String kBaseUrl =
    'https://laravel-api.emaad-infotech.com/school-management-system/api/v1/';

/// App root (for storage / uploaded media paths from admin).
const String kAppBaseUrl =
    'https://laravel-api.emaad-infotech.com/school-management-system/';

const String _tokenKey = 'driver_jwt_token';

class ApiClient {
  late final Dio _dio;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: kBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(_dio, _storage),
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
      ),
    ]);
  }

  // ── HTTP helpers ─────────────────────────────────────────

  Future<Response> get(String path, {Map<String, dynamic>? params}) async {
    return _handle(() => _dio.get(path, queryParameters: params));
  }

  Future<Response> post(String path, [dynamic data]) async {
    return _handle(() => _dio.post(path, data: data));
  }

  Future<Response> put(String path, [dynamic data]) async {
    return _handle(() => _dio.put(path, data: data));
  }

  Future<Response> delete(String path) async {
    return _handle(() => _dio.delete(path));
  }

  Future<Response> _handle(Future<Response> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ApiException('Connection timed out. Check your internet.', 408);
    }
    if (e.type == DioExceptionType.connectionError) {
      return ApiException('No internet connection.', 0);
    }
    final status = e.response?.statusCode ?? 0;
    final msg =
        e.response?.data?['message'] as String? ?? e.message ?? 'Unknown error';
    return ApiException(msg, status);
  }

  // ── Token management ─────────────────────────────────────

  Future<void> setToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<String?> getToken() async {
    try {
      final secureToken = await _storage.read(key: _tokenKey);
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _dio.options.headers.remove('Authorization');
  }
}

// ── Auth interceptor: attaches token + handles 401 ────────────
class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  bool _isRefreshing = false;

  _AuthInterceptor(this._dio, this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    String? token;
    try {
      token = await _storage.read(key: _tokenKey);
    } catch (_) {}
    if (token == null || token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_tokenKey);
    }
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        String? token;
        try {
          token = await _storage.read(key: _tokenKey);
        } catch (_) {}
        if (token == null || token.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          token = prefs.getString(_tokenKey);
        }
        if (token != null) {
          final resp = await _dio.post(
            '/auth/refresh',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          final newToken = resp.data['access_token'] as String?;
          if (newToken != null) {
            try {
              await _storage.write(key: _tokenKey, value: newToken);
            } catch (_) {}
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_tokenKey, newToken);

            if (Get.isRegistered<AuthController>()) {
              Get.find<AuthController>().token.value = newToken;
            }

            err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final retried = await _dio.fetch(err.requestOptions);
            _isRefreshing = false;
            return handler.resolve(retried);
          }
        }
      } catch (_) {}
      _isRefreshing = false;
      try {
        await _storage.delete(key: _tokenKey);
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);

      if (Get.isRegistered<AuthController>()) {
        Get.find<AuthController>().token.value = null;
        Get.find<AuthController>().user.value = null;
      }
    }
    handler.next(err);
  }
}

// ── Custom exception ──────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;
  bool get isNetworkError => statusCode == 0;
  bool get isTimeout => statusCode == 408;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
