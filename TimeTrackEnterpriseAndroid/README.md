# Generic Android Template

قالب Flutter عام لتطبيقات Android. يحتوي المسار الأساسي على المصادقة، عميل REST API، التخزين المحلي، حالة مزامنة قابلة للتوسعة، الواجهة الرئيسية، ووحدة سجلات محايدة تتكامل مع قالب Django عبر عقد REST موثق.

## المتطلبات والتشغيل

- Flutter حديث يدعم إصدار Dart الموجود في `pubspec.yaml`.
- Android SDK وJDK 17.

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-api.example.com
```

القيم الافتراضية هي `APP_NAME=Generic Android Template` و`APP_LOCALE=ar` و`API_BASE_URL=https://api.example.com`. غيّرها أثناء البناء عبر `--dart-define` أو عبر قيم التطبيق في `lib/core/config/app_config.dart`.

```powershell
$env:APP_NAME = 'Sample Project'
$env:API_BASE_URL = 'https://api.example.com'
$env:ANDROID_KEYSTORE_PATH = 'C:\secure\release-key.jks'
$env:ANDROID_KEYSTORE_PASSWORD = '<keystore-password>'
$env:ANDROID_KEY_ALIAS = '<key-alias>'
$env:ANDROID_KEY_PASSWORD = '<key-password>'
flutter build apk --release `
  --dart-define="APP_NAME=$env:APP_NAME" `
  --dart-define=APP_LOCALE=en `
  --dart-define="API_BASE_URL=$env:API_BASE_URL"
```

يتطلب بناء الإصدار `API_BASE_URL` ومفتاح توقيع إنتاج مضبوطًا عبر متغيرات
البيئة الموضحة في [دليل التطوير](docs/DEVELOPMENT.md). لا يُسمح بإصدار APK
موقّع بمفتاح التطوير.

يستخدم Gradle قيمة `APP_NAME` نفسها لاسم التطبيق في Android. حدّث `applicationId` و`namespace` وحزمة `MainActivity` عند تحويل القالب إلى تطبيق مستقل.

## البنية

```text
lib/
├─ app/                 # MaterialApp، التنقل، الألوان، اللغة
├─ core/                # الشبكة، الجلسة الآمنة، SQLite، الطابور، DI
├─ features/
│  ├─ auth/             # الدخول واستعادة الجلسة والخروج
│  ├─ example/          # CRUD محايد متصل بوحدة Django example
│  └─ home/             # الرئيسية وحالة التخزين والمزامنة
├─ examples/transport/  # عينة مجال معزولة؛ ليست في التنقل الافتراضي
└─ shared/widgets/      # الشعار المؤقت والمكونات المشتركة
```

راجع [شرح البنية](docs/ARCHITECTURE.md) لمسار البيانات ومسؤولية كل طبقة.

## المصادقة وREST API

تستخدم الشبكة Dio و`ApiClient` و`Envelope` و`FailureMapper`. يحتفظ `SessionManager` برموز الوصول والتحديث عبر `flutter_secure_storage`، ويضيف `ApiInterceptor` رأس Bearer ويجدد الجلسة عند 401 لمرة واحدة مع منع طلبات التجديد المتزامنة.

صفحة **سجلات المثال** تنفذ قائمة وبحثًا وإنشاءً وتعديلًا وحذفًا عبر:

- `GET /api/v1/modules/example/items/?q=...`
- `POST /api/v1/modules/example/items/create/`
- `PATCH /api/v1/modules/example/items/{id}/update/`
- `DELETE /api/v1/modules/example/items/{id}/delete/`

تتطابق الاستجابات مع غلاف Django `{success, message, data, errors}`. انظر [عقد التكامل](docs/API_CONTRACT.md).

## العربية والإنجليزية

تدعم الواجهة RTL للعربية وLTR للإنجليزية، مع زر تبديل في شاشة الدخول والرئيسية وعينة السجلات. الاختيار داخل الجلسة فقط؛ يحدد `APP_LOCALE` اللغة الأولى عند كل تشغيل. ترجمات القالب الأساسي في `lib/app/i18n/app_strings.dart`.

## التخزين المحلي

يخزّن SQLite حالة الجهاز والسجلات والطابور المحلي. يظل الطابور على الجهاز عند تسجيل الخروج، ولا يرسل المثال المحايد عملياته تلقائيًا إلى واجهة push/pull. قاعدة SQLite غير مشفّرة؛ لا تضع أسرارًا أو بيانات عالية الحساسية في الحمولة المحلية قبل إضافة تشفير مناسب وسياسة عزل مستخدم.

## التحقق والبناء

```powershell
flutter analyze
flutter test
flutter test integration_test/app_smoke_test.dart -d emulator-5554
flutter build apk --debug
```

`tool/build_release.ps1` يشغّل التحليل والاختبارات والبناء، ثم يحفظ ملفات الإصدار في `dist/`. راجع [دليل التطوير والبناء](docs/DEVELOPMENT.md) قبل بناء إصدار موزع.

## تخصيص القالب

1. اختر `APP_NAME` و`APP_LOCALE` و`API_BASE_URL`.
2. استبدل الشعار المؤقت ومجموعة ألوان `lib/app/theme/` وأيقونات Android.
3. غيّر `applicationId` و`namespace` وحزمة Kotlin في `MainActivity`.
4. أنشئ feature جديدة داخل `lib/features/<name>/domain|data|presentation`، ثم أضف مسارها في `lib/app/router/app_router.dart` ومزوّداتها في Riverpod.
5. أضف endpoint موثقًا واختبر طلبه وغلاف استجابته مع الخادم.

عينة النقل موجودة في `lib/examples/transport` و`examples/transport` للرجوع إليها فقط؛ لا تُستورد مساراتها في التطبيق الأساسي. عند تفعيلها أضف `TransportExampleRoutes.routes` إلى الراوتر، وفعّل وحدة Django الاختيارية في `ENABLE_DOMAIN_SAMPLES`.

## الأمان والقيود الحالية

- تخزين access وrefresh في Android Keystore عبر `flutter_secure_storage`.
- عنوان API افتراضي تجريبي؛ مرر عنوان الخادم الفعلي لكل بيئة.
- بيانات SQLite والطابور غير مشفّرة وغير معزولة حسب حساب المستخدم.
- سكربتات البناء تجهّز إصدارًا محليًا؛ لا توفر توقيع متجر أو نشرًا تلقائيًا.
- سجل اختبار تكامل يتصل بخادم إنتاج ليس ضمن اختبارات القالب؛ اختبارات API تستخدم Dio محاكى واختبارات Django تستخدم قاعدة مؤقتة.
