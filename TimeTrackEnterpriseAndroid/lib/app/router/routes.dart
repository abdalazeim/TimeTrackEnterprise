/// مسارات التنقل المركزية حتى لا تستورد الشاشات ملف الراوتر نفسه.
/// يمكن إضافة مسارات جديدة هنا لاستخدامها في go_router.
class Routes {
  const Routes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/home';
  static const String exampleItems = '/example/items';

  // Attendance Gateway Companion
  static const String gateway = '/gateway';
  static const String gatewayScanner = '/gateway/scanner';
  static const String gatewayScannerSetup = '/gateway/scanner-setup';
  static const String gatewayPortal = '/gateway/portal';
  static const String gatewayCompanion = '/gateway/companion';
  static const String gatewayAbout = '/gateway/about';
}
