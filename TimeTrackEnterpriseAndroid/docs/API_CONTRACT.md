# عقد Android مع Django

يستخدم التطبيق الإصدار `/api/v1/` وغلاف الاستجابة التالي:

```json
{"success": true, "message": "", "data": {}, "errors": null}
```

القوائم المرقّمة موجودة في `data.items` و`data.meta`. يحوّل `Envelope.dataList` القائمة إلى List، ويرفض `success:false` حتى إذا أعاد الخادم حالة HTTP ناجحة.

## المسارات المشتركة

| العملية | الطريقة والمسار | القراءة في Flutter |
| --- | --- | --- |
| دخول | `POST /api/v1/auth/token/` | `AuthApi.login` |
| تجديد | `POST /api/v1/auth/token/refresh/` | `SessionManager` و`AuthApi.refresh` |
| المستخدم الحالي | `GET /api/v1/auth/me` | `AuthApi.me` |
| خروج | `POST /api/v1/auth/logout` | `AuthApi.logout` |
| القدرات | `GET /api/v1/capabilities/` | متاح للاكتشاف والتوافق |
| دفع عمليات المزامنة | `POST /api/v1/sync/` | `SyncCoordinator` |
| سحب التغييرات | `GET /api/v1/sync/?since=<cursor>&models=example.item` | `SyncCoordinator` |

تُرسل الطلبات المحمية مع `Authorization: Bearer <access>`. يحصل العميل على زوج الرموز عبر `data.access` و`data.refresh`، ويقبل الحقول العلوية التي يحتفظ بها الخادم للتوافق.

## مثال السجلات

تعريف المسارات في `lib/core/network/api_endpoints.dart` يطابق `docs/api/API_CONTRACT.md` في مشروع Django:

- GET القائمة: `/api/v1/modules/example/items/` مع معامل اختياري `q`.
- POST الإنشاء: `/api/v1/modules/example/items/create/`.
- PATCH التعديل: `/api/v1/modules/example/items/{id}/update/`.
- DELETE الحذف: `/api/v1/modules/example/items/{id}/delete/`.

`ExampleItemsApi` يحول JSON إلى `ExampleItem` ويمر عبر `ApiClient`. اختبار `test/features/example/example_items_api_test.dart` يثبت المسار والطريقة وشكل الاستجابة على Dio محاكى؛ اختبار Django `tests/api/test_mobile_contract.py` ينفذ CRUD حقيقيًا داخل قاعدة اختبار مؤقتة.

## معالجة الأخطاء

تُحوّل أخطاء الشبكة وHTTP إلى `ApiException` ثم إلى حالة تحميل/خطأ في الصفحة. تستعمل `ApiClient` غلاف الأخطاء أيضًا في الطلبات التي لا تعيد كيانًا، مثل الحذف.

## المزامنة والعمل دون اتصال

ينسق `SyncCoordinator` طابور `operation_id` مع عقد Django. كل عملية تحمل `operation_id` ثابتًا و`kind` و`payload`. العمليات المقبولة تُعلّم كمطبقة، والرفض الدائم والتعارض يحتاجان معالجة المستخدم، وأخطاء النقل تعاد وفق backoff. السحب يحدّث جدول السجلات العام، يطبق tombstones ويحفظ المؤشر بعد نجاح التطبيق.

تعريف المجموعة وأنواع العمليات تابع للوحدة. قالب المثال يستخدم `example.item` و`example.item.create/update/delete`، ويمكن تغيير قائمة المجموعات عند البناء بواسطة `--dart-define=SYNC_MODELS=example.item,another.collection` بعد تسجيلها في الخادم.

يرجع الخادم كل تغييرات المجموعة المطلوبة في استجابة واحدة. الوحدات كبيرة الحجم تحتاج paging token متوافقًا من الطرفين قبل تفعيل المزامنة عليها.

يُخزن زوج الرموز كحزمة واحدة في التخزين الآمن مع `user_id` وعنوان الخادم. قاعدة SQLite وملف المستخدم المحفوظ منفصلان حسب الحساب والخادم؛ لذلك لا تُعرض بيانات الحساب السابق عند تبديل المستخدم أو عنوان API. ترحيل الرموز القديمة لا يخمّن هوية الحساب، ويلزم اتصال ناجح بـ`/auth/me` قبل استعادة الملف الشخصي دون شبكة.
