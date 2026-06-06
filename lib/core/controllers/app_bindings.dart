import 'package:get/get.dart';
import '../api/api_client.dart';
import 'auth_controller.dart';
import 'gps_controller.dart';
import 'locale_controller.dart';

/// Registers all GetX controllers on app start.
class AppBindings extends Bindings {
  @override
  void dependencies() {
    // ApiClient — permanent singleton
    Get.put<ApiClient>(ApiClient(), permanent: true);

    // Auth — permanent, drives navigation
    Get.put<AuthController>(
      AuthController(Get.find<ApiClient>()),
      permanent: true,
    );

    // Locale — permanent
    Get.put<LocaleController>(LocaleController(), permanent: true);

    // GPS — permanent (tracks even across routes)
    Get.put<GpsController>(
      GpsController(Get.find<ApiClient>()),
      permanent: true,
    );
  }
}
