import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LocaleController extends GetxController {
  final Rx<Locale> currentLocale = const Locale('en').obs;

  /// Align GetX state with EasyLocalization after app start.
  void syncFromContext(BuildContext context) {
    final easyLocale = context.locale;
    if (currentLocale.value.languageCode != easyLocale.languageCode) {
      currentLocale.value = easyLocale;
    }
  }

  Future<void> setLocale(BuildContext context, Locale locale) async {
    if (context.locale.languageCode == locale.languageCode &&
        currentLocale.value.languageCode == locale.languageCode) {
      return;
    }
    await context.setLocale(locale);
    currentLocale.value = locale;
  }
}

/// Helper function to change locale — same API as before
Future<void> changeAppLocale(BuildContext context, Locale locale) {
  return Get.find<LocaleController>().setLocale(context, locale);
}
