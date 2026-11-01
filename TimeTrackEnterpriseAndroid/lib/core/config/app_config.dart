/// إعدادات التطبيق العامة.
///
/// يمكن overriding عنوان الخادم عند البناء:
/// `flutter build apk --dart-define=API_BASE_URL=https://your-api.com`
class AppConfig {
  const AppConfig._();

  /// اسم التطبيق الظاهر فيlauncher و الشاشة الرئيسية.
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Generic Android Template',
  );

  /// يطابق `version:` في `pubspec.yaml`.
  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  static const String defaultLanguage = String.fromEnvironment(
    'APP_LOCALE',
    defaultValue: 'ar',
  );

  /// عنوان الخادم الأساسي (يستخدم في جميع طلبات API).
  /// يمكن overriding عبر --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.com',
  );

  /// Comma-separated server collection names supported by this build.
  static const String syncModels = String.fromEnvironment(
    'SYNC_MODELS',
    defaultValue: 'example.item',
  );

  static List<String> get syncModelNames => syncModels
      .split(',')
      .map((model) => model.trim())
      .where((model) => model.isNotEmpty)
      .toList(growable: false);

  /// مهلة الاتصال / الاستقبال (بالثواني).
  static const Duration connectTimeout = Duration(seconds: 120);
  static const Duration receiveTimeout = Duration(seconds: 120);

  /// مهلة الإرسال (بالثواني).
  static const Duration sendTimeout = Duration(seconds: 60);
}
