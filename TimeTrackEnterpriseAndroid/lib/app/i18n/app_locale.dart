import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';

final appLocaleProvider = StateProvider<Locale>((ref) {
  final language = AppConfig.defaultLanguage.toLowerCase();
  return Locale(language == 'en' ? 'en' : 'ar');
});

void toggleAppLocale(WidgetRef ref) {
  final current = ref.read(appLocaleProvider).languageCode;
  ref.read(appLocaleProvider.notifier).state =
      Locale(current == 'ar' ? 'en' : 'ar');
}
