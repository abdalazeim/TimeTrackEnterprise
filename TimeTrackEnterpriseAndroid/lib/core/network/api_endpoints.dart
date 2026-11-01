/// مسارات الـAPI — أمثلة قابلة للتعديل حسب واجهة back-end الخاصة بك.
///
/// هذه المسارات متوافقة مع عقد قالب Django المرفق كمثال.
/// يمكن إضافة أو إزالة مسارات لتناسب تطبيقك الخاص.
class ApiEndpoints {
  const ApiEndpoints._();

  static const String prefix = '/api/v1';

  // المصادقة
  static const String login = '$prefix/auth/token/';
  static const String refresh = '$prefix/auth/token/refresh/';
  static const String logout = '$prefix/auth/logout';
  static const String me = '$prefix/auth/me';

  // المزامنة والقدرات
  static const String sync = '$prefix/sync/';
  static const String capabilities = '$prefix/capabilities/';

  // Neutral sample API demonstrating paginated CRUD requests.
  static const String exampleItems = '$prefix/modules/example/items/';
  static const String exampleItemCreate = '$prefix/modules/example/items/create/';
  static String exampleItem(int id) => '$exampleItems$id/';
  static String exampleItemUpdate(int id) => '$exampleItems$id/update/';
  static String exampleItemDelete(int id) => '$exampleItems$id/delete/';
}
