# واجهات البرمجة (API) — نظام نقل البضائع GTS

كل المسارات مأخوذة من العقد الحقيقي لحزمة الويب الحيّة (`/static/js/dist/app.js`) ولا يوجد أي مسار مُخترع.
الملف المرجعي في الكود: `lib/core/network/api_endpoints.dart`.

## الأساسيات

| البند | القيمة |
|---|---|
| الخادم الافتراضي | `https://goodstransportationsystem.onrender.com` |
| البادئة | `/api/v1` |
| المصادقة | `Authorization: Bearer <access_token>` |
| التجديد | `POST /api/v1/auth/token/refresh/` بجسم `{ "refresh": "..." }` |
| الغلاف | `{ "success": true, "data": ... }` — يُفكّه `Envelope.dataMap` / `dataList` |
| الأخطاء | 400 / 401 / 403 / 404 / 409 / 429 / 5xx تُحوَّل إلى `Failure` في `failure_mapper.dart` |
| المهلات | اتصال/استقبال 120ث، إرسال 60ث (خادم Render يستيقظ ببطء) |

> المسارات التالية تُرسل بلا شرطة نهائية حسب العقد: `/auth/me` و`/auth/logout`.
> أما `/auth/token/` و`/auth/token/refresh/` و`/sync/` و`/capabilities/` فبشرطة نهائية.

---

## 1) المصادقة — `lib/features/auth/data/datasources/auth_api.dart`

| # | الطريقة | المسار | المصادقة | الجسم | الغرض |
|---|---|---|---|---|---|
| 1 | `POST` | `/api/v1/auth/token/` | عامة | `username`, `password` | تسجيل الدخول وإرجاع `access` + `refresh` + بيانات المستخدم |
| 2 | `POST` | `/api/v1/auth/token/refresh/` | عامة | `refresh` | تدوير الرموز (الخادم يرجّع refresh جديد أيضًا) |
| 3 | `GET` | `/api/v1/auth/me` | مطلوبة | — | الملف الشخصي الحالي واستعادة الجلسة |
| 4 | `POST` | `/api/v1/auth/logout` | مطلوبة | `refresh` (اختياري) | إبلاغ الخادم بالخروج (أفضل جهد، لا يعطّل الخروج المحلي) |

## 2) المزامنة والقدرات

| # | الطريقة | المسار | المصادقة | الحالة في التطبيق |
|---|---|---|---|---|
| 5 | `GET` | `/api/v1/sync/` | مطلوبة | متاح في العقد — غير مستخدم حاليًا (المزامنة محلية بالطابور) |
| 6 | `GET` | `/api/v1/capabilities/` | مطلوبة | متاح في العقد — غير مستخدم حاليًا |

## 3) لوحة المعلومات والتقارير

| # | الطريقة | المسار | المصادقة | الحالة |
|---|---|---|---|---|
| 7 | `GET` | `/api/v1/modules/transport/dashboard/` | مطلوبة | متاح في العقد — التقارير تُحسب محليًا |
| 8 | `GET` | `/api/v1/modules/transport/reports/` | مطلوبة | متاح في العقد — غير مستخدم |
| 9 | `GET` | `/api/v1/modules/transport/reports/top/` | مطلوبة | متاح في العقد — غير مستخدم |

## 4) بيانات الوحدة المرجعية

| # | الطريقة | المسار | المصادقة | الاستخدام |
|---|---|---|---|---|
| 10 | `GET` | `/api/v1/modules/transport/meta/` | مطلوبة | حالات الشحنات/الرحلات والقوائم المرجعية |
| 11 | `GET` | `/api/v1/modules/transport/customers/` | مطلوبة | قائمة العملاء في النموذج |
| 12 | `GET` | `/api/v1/modules/transport/vehicles/` | مطلوبة | قائمة المركبات |
| 13 | `GET` | `/api/v1/modules/transport/drivers/` | مطلوبة | قائمة السائقين |
| 14 | `GET` | `/api/v1/modules/transport/routes/` | مطلوبة | قائمة المسارات |
| 15 | `GET` | `/api/v1/modules/transport/payments/` | مطلوبة | المدفوعات (التقارير) |
| 16 | `GET` | `/api/v1/modules/transport/expenses/` | مطلوبة | المصروفات (التقارير) |

## 5) الشحنات — `lib/features/transport/data/datasources/transport_api.dart`

| # | الطريقة | المسار | الجسم | الغرض |
|---|---|---|---|---|
| 17 | `GET` | `/api/v1/modules/transport/shipments/?drafts=1` | — | كل الشحنات بما فيها المسودات |
| 18 | `POST` | `/api/v1/modules/transport/shipments/add/` | بيانات الشحنة | إنشاء شحنة |
| 19 | `POST` | `/api/v1/modules/transport/drafts/save/` | بيانات الشحنة | حفظ مسودة استلام |
| 20 | `POST` | `/api/v1/modules/transport/drafts/{id}/submit/` | اختياري | ترحيل المسودة إلى شحنة |
| 21 | `POST` | `/api/v1/modules/transport/shipments/edit/{id}/` | بيانات الشحنة | تعديل شحنة (الخادم يقبل POST) |
| 22 | `DELETE` | `/api/v1/modules/transport/shipments/{id}/delete/` | — | حذف شحنة |
| 23 | `POST` | `/api/v1/modules/transport/shipments/{id}/advance/` | — | نقل الشحنة للحالة التالية |
| 24 | `POST` | `/api/v1/modules/transport/shipments/{id}/except/` | سبب/ملاحظة | تسجيل استثناء |
| 25 | `POST` | `/api/v1/modules/transport/shipments/{id}/pod/` | إثبات التسليم + التوقيع | حفظ POD |
| 26 | `POST` | `/api/v1/modules/transport/shipments/{id}/unload/` | — | تأكيد التفريغ |

## 6) البضائع

| # | الطريقة | المسار | الجسم | الغرض |
|---|---|---|---|---|
| 27 | `GET` | `/api/v1/modules/transport/goods/` | — | أنواع البضائع |
| 28 | `POST` | `/api/v1/modules/transport/goods/add/` | بيانات النوع | إضافة نوع |
| 29 | `POST` | `/api/v1/modules/transport/goods/{id}/` | بيانات النوع | تحديث نوع |
| 30 | `DELETE` | `/api/v1/modules/transport/goods/{id}/delete/` | — | حذف نوع |

## 7) الرحلات

| # | الطريقة | المسار | الجسم | الغرض |
|---|---|---|---|---|
| 31 | `GET` | `/api/v1/modules/transport/trips/` | — | كل الرحلات |
| 32 | `POST` | `/api/v1/modules/transport/trips/add/` | بيانات الرحلة | إنشاء رحلة |
| 33 | `POST` | `/api/v1/modules/transport/trips/{id}/edit/` | بيانات الرحلة | تعديل رحلة |
| 34 | `DELETE` | `/api/v1/modules/transport/trips/{id}/delete/` | — | حذف رحلة |
| 35 | `POST` | `/api/v1/modules/transport/trips/{id}/advance/` | — | نقل الرحلة للحالة التالية |
| 36 | `POST` | `/api/v1/modules/transport/trips/{id}/close/` | — | إغلاق الرحلة |
| 37 | `POST` | `/api/v1/modules/transport/trips/{id}/reopen/` | — | إعادة فتح الرحلة |
| 38 | `POST` | `/api/v1/modules/transport/trips/{id}/link/` | `{ "shipIds": [...] }` | ربط شحنات بالرحلة |
| 39 | `POST` | `/api/v1/modules/transport/trips/{id}/load/` | `{ "shipIds": [...] }` | تحميل الشحنات (لا يتجاوز سعة المركبة) |

---

## ملخص سريع

- **39 مسارًا** موثقًا: 4 مصادقة + 2 مزامنة/قدرات + 3 لوحة/تقارير + 7 مرجعية + 10 شحنات + 4 بضائع + 9 رحلات.
- **21 مسارًا مستخدمًا فعليًا** في التطبيق، والباقي متاح في العقد للتوسعة.
- كل الطلبات تمر عبر `ApiClient` → `Envelope` → `Failure`، مع تجديد تلقائي للرمز عند 401 في `ApiInterceptor`.
- الطلبات غير المتصلة تُحفظ في طابور محلي (`sync_queue`) وتُعاد تلقائيًا (backoff أسّي).

## نموذج الاستدعاء

```dart
final meta = await api.getMap(ApiEndpoints.transportMeta);
final shipments = await api.getList(
  ApiEndpoints.shipments,
  query: <String, dynamic>{'drafts': 1},
);
await api.postVoid(
  ApiEndpoints.tripLoad(id),
  body: <String, dynamic>{'shipIds': ids},
);
```
