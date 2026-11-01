# بنية التطبيق

يحافظ التطبيق على حدود بسيطة بين العرض والنطاق والبيانات. الهدف أن تستبدل عميل API أو التخزين أو شاشة مثال دون أن ينتقل Dio أو Flutter إلى منطق المجال.

## الطبقات

- `app/`: `MaterialApp.router`، التنقل، الثيم، واللغة الحالية.
- `core/auth/`: مخزن الرموز والملف الشخصي ومدير الجلسة.
- `core/network/`: Dio، الترويسات، التجديد، قراءة المغلف، وتحويل الأخطاء.
- `core/database/` و`core/sync/`: قاعدة SQLite والطوابير والحالة المحلية.
- `features/<name>/domain/`: الكيانات وواجهات المستودعات.
- `features/<name>/data/`: طلبات API وتنفيذ المستودعات وتحويل JSON.
- `features/<name>/presentation/`: صفحات Flutter ومزوّدات Riverpod.
- `shared/widgets/`: عناصر واجهة لا تعتمد على مجال بعينه.
- `examples/transport/`: تطبيق مرجعي مستقل؛ مساراته في
  `TransportExampleRoutes.routes` وتُضاف صراحةً عند تفعيل العينة.

## مسار طلب محمي

```text
Page -> Riverpod provider -> repository -> ApiClient -> Dio interceptor
     -> REST endpoint -> Envelope -> entity -> repository -> provider -> UI
```

`SessionManager` هو المالك الوحيد للرموز. يضيف interceptor رمز الوصول، ويشارك عملية تجديد واحدة بين الطلبات المتزامنة، ويعيد الطلب الأصلي مرة واحدة. `ApiClient` يترجم فشل HTTP ومغلف الخطأ إلى `ApiException` موحد.

## وحدة المثال

`features/example` تستخدم واجهة `ExampleItemRepository`، ومصدر `ExampleItemsApi`، وكيان `ExampleItem`. صفحة القائمة تستعمل `FutureProvider.family` للبحث وإعادة التحميل؛ النماذج تتحقق من المدخلات قبل الإرسال، وتعرض حالة التحميل والفراغ والخطأ.

## التخزين والطابور

`AppDatabase` يفتح اتصال SQLite واحدًا ويطبق تغييرات المخطط. جداول الطابور وحالة الجهاز عامة، لكنها محلية فقط في هذا القالب. قبل استخدامها لبيانات حسابات متعددة، أضف `account_id` إلى الملكية أو امسح البيانات عند تبديل المستخدم، وقرر تشفير قاعدة البيانات والنسخ الاحتياطي.

## إضافة ميزة

أنشئ مجلدات `domain`, `data`, `presentation`، ثم سجل `Provider`، وأضف المسار في `app/router/app_router.dart`، واستخدم المكونات المشتركة. أضف اختبارات تحويل الكيان والـrepository وتفاعل الصفحة.
