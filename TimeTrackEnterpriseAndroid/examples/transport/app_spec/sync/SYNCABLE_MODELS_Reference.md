# مرجع نماذج المزامنة (SYNCABLE_MODELS)

> **ملف مُولَّد** — لا يُعدَّل يدوياً.
> التوليد: `.\venv\Scripts\python.exe scripts\gen_sync_reference.py`
> المصدر: `apps/synchronization/views.py` + استخراج AST من الـ serializers
> (نفس البيانات التي يقدمها `GET /api/v1/capabilities/`).

## البروتوكول باختصار

| البند | القيمة |
|-------|--------|
| نقطة النهاية | `GET/POST /api/v1/sync/` |
| حجم الصفحة | 500 صف |
| المؤشر (cursor) | `updated_at` بساعة **الخادم** (لا ساعة الجهاز) |
| منع التكرار | `operation_id` (UUID لكل عملية) — الإرسال المكرر يعيد النتيجة المسجّلة |
| الحذف | `SyncTombstone` — يُسحب مع التغييرات |
| عدد النماذج | 20 |

السحب يعيد `{rows: {model: [...]}, tombstones: [...]}` منذ المؤشر،
والدفع يرسل `{operations: [{operation_id, kind, payload}]}`.

## النماذج وحقولها

### `customer`

- **النموذج**: `transport.customer`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (10):

```
id, name, phone, city, type, active, note, created, debit_account, credit_account
```

### `driver`

- **النموذج**: `transport.driver`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (10):

```
id, name, phone, lic, type, rating, trips, status, debit_account, credit_account
```

### `vehicle`

- **النموذج**: `transport.vehicle`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (11):

```
id, name, plate, type, capKg, vol, fuel, year, km, driver, status
```

### `goods`

- **النموذج**: `transport.goodstype`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (7):

```
id, name, cat, haz, unit, store, note
```

### `route`

- **النموذج**: `transport.route`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (6):

```
id, from, to, dist, time, price
```

### `branch`

- **النموذج**: `transport.branch`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (8):

```
id, name, city, type, manager, phone, emp, status
```

### `agent`

- **النموذج**: `transport.agent`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (8):

```
id, name, phone, city, type, status, debit_account, credit_account
```

### `shipment`

- **النموذج**: `transport.shipment`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (36):

```
id, waybill, rog, status, draft, customer, goods, qty, unit, wt, vol, from, to, dist, shipper, consignee, fee, feeTotal, pay, tripId, vehicle, driver, route, dates, pod, invoice, notes, urgent, services, items, events, created, date, due, paid, updated_at
```

### `trip`

- **النموذج**: `transport.trip`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (22):

```
id, name, from, to, vehicle, driver, route, dist, hours, capKg, wt, linkedWt, count, loadedCount, rev, exp, status, closed, dates, stops, note, updated_at
```

### `payment`

- **النموذج**: `transport.payment`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (17):

```
id, shipId, customer, amount, method, ref, agent, note, ledger, ledgerName, ledgerNo, txn, created, time, date, enteredOn, enteredTime
```

### `expense`

- **النموذج**: `transport.expense`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (10):

```
id, txn, cat, note, amount, method, ref, tripId, created, time
```

### `invoice`

- **النموذج**: `transport.invoice`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (16):

```
id, no, typ, ship, shipId, party, customer, supplier, total, advance, state, date, ref, note, created, time
```

### `company`

- **النموذج**: `org.company`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (16):

```
id, parent_company, parent_company_name, code, name, company_type, email, phone, address, logo, status, active, subscription_type, subscription_expiry, location_count, created_at
```

### `city`

- **النموذج**: `org.city`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (6):

```
id, code, name, active, location_count, created_at
```

### `location`

- **النموذج**: `org.location`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (11):

```
id, company, company_name, city, city_name, code, name, address, active, entity_count, created_at
```

### `operational_entity`

- **النموذج**: `org.operationalentity`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (10):

```
id, location, location_name, code, name, entity_type, active, department_count, vehicle_count, created_at
```

### `department`

- **النموذج**: `org.department`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (11):

```
id, entity, entity_name, code, name, manager_name, description, active, vehicle_count, driver_count, created_at
```

### `chart_of_accounts_item`

- **النموذج**: `chart_of_accounts.chartofaccountsitem`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (11):

```
id, code, name, account_type, type_label, normal_balance, parent_id, opening_balance, budget, description, is_active
```

### `journal_entries_item`

- **النموذج**: `journal_entries.journalentriesitem`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (16):

```
id, movement_no, entry_date, description, journal_id, journal_code, journal_name, partner_type, partner_ref, partner_name, region_id, status, entry_type, total_debit, total_credit, lines
```

### `regions_item`

- **النموذج**: `regions.regionsitem`
- **حقل التحديث (الcursor)**: `updated_at`
- **الحقول المُصدَّرة** (11):

```
id, name, code, description, is_active, org_level, org_path, depth, journal_entries_count, org_id, org_name
```
