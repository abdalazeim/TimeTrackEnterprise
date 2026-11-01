# التطوير والبناء

## الإعدادات

| المتغير | مكان الاستخدام | الافتراضي |
| --- | --- | --- |
| `APP_NAME` | عنوان Material واسم تطبيق Android وسكربت الإصدار | `Generic Android Template` |
| `APP_LOCALE` | اللغة عند بدء التطبيق (`ar` أو `en`) | `ar` |
| `API_BASE_URL` | عنوان خادم REST API | `https://api.example.com` |
| `APP_VERSION` | النص المعروض في واجهة الدخول | `1.0.0` |
| `SYNC_MODELS` | مجموعات السحب المسجلة على الخادم، مفصولة بفاصلة | `example.item` |

مثال تشغيل:

```powershell
flutter run `
  --dart-define=APP_NAME="Sample Project" `
  --dart-define=APP_LOCALE=en `
  --dart-define=API_BASE_URL=https://api.example.com
```

## مزامنة عمليات الوحدة

يضيف `SyncQueue` العملية محليًا بمعرّف ثابت، ثم يرسل `SyncCoordinator` دفعة العمليات ويسحب المجموعات المحددة. يختار كل مشروع أسماء الأنواع والحمولات المطابقة لمعالجات Django المسجلة:

```dart
await ref.read(syncQueueProvider).enqueue(
  kind: 'example.item.create',
  payload: {
    'data': {'name': 'عنصر', 'code': 'ITEM-01'},
  },
);
final result = await ref.read(syncCoordinatorProvider).sync();
```

شغّل `sync()` عند بدء جلسة موثقة، وعند عودة الاتصال، أو من آلية الخلفية التي يختارها التطبيق. لا يعتمد القالب على إضافة خاصة بالتشغيل في الخلفية. تُحفظ قاعدة محلية منفصلة لكل خادم وحساب، وتمنع المنسقة تطبيق رد قديم بعد تبديل الهوية.

إذا غيّرت اسم الحزمة، حدّث `android/app/build.gradle.kts` ومسار `MainActivity.kt` وبيان Android معًا. لا ترفع ملفات keystore أو كلمات مرورها إلى Git.

## اختبارات وفحوص

```powershell
flutter analyze
flutter test
flutter test test/features/example/example_items_api_test.dart
flutter test integration_test/app_smoke_test.dart -d emulator-5554
```

اختبارات التكامل تحتاج محاكيًا أو جهازًا متصلًا. اختبارات الوحدة تستخدم قاعدة بيانات مؤقتة وDio محاكى ولا تتصل بخادم حي.

## بناء APK

```powershell
flutter build apk --debug
```

يتطلب بناء الإصدار `API_BASE_URL` وعناصر التوقيع الأربعة التالية في بيئة
PowerShell؛ لا تُضمّن المفتاح أو كلمات مروره في المستودع:

```powershell
$env:API_BASE_URL = 'https://api.example.com'
$env:ANDROID_KEYSTORE_PATH = 'C:\secure\release-key.jks'
$env:ANDROID_KEYSTORE_PASSWORD = '<keystore-password>'
$env:ANDROID_KEY_ALIAS = '<key-alias>'
$env:ANDROID_KEY_PASSWORD = '<key-password>'
flutter build apk --release `
  --dart-define="API_BASE_URL=$env:API_BASE_URL" `
  --dart-define=APP_LOCALE=en
```

`tool/build_release.ps1` يشغّل التحليل والاختبارات والبناء، ثم يجهّز ملفات
`dist/`؛ يجب تعيين المتغيرات نفسها قبل تشغيله.

## الترحيل والتحديث

عند إضافة dependency:

1. أضفها إلى `pubspec.yaml` ثم نفّذ `flutter pub get`.
2. راجع `pubspec.lock` ونتيجة `flutter analyze`.
3. اختبر أقل إصدار Android مدعومًا ومحاكيًا بإصدار حديث.
4. راجع عقد API قبل تغيير نماذج JSON أو أسماء الحقول.

كل ترقية للمخطط المحلي تحتاج زيادة `DatabaseSchema.version` وهجرة متوافقة، مع اختبار إنشاء قاعدة جديدة والترقية من الإصدار السابق.
