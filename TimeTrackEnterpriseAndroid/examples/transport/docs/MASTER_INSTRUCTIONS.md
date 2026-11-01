# MASTER INSTRUCTIONS — Goods Transportation System Flutter Android App

Consolidated from all files in `GDS-Android-Template`. Target device: install Flutter SDK, then follow.

## Base URL
https://goodstransportationsystem.onrender.com

## Architecture
Backend واحد + DB واحدة + واجهتان مستقلتان + طبقة sync موثوقة.
- Django: منطق العمل، التحقق، المصادقة، الصلاحيات.
- DRF: واجهة API.
- Render: استضافة.
- Neon PostgreSQL 16: DB مركزية.
- Flutter/Dart: تطبيق Android.
- SQLite: تخزين محلي + طابور عمليات.

## Clean Architecture (Uncle Bob)
Feature-First: lib/features/<feature>/{domain,data,presentation}. Domain مستقل عن Flutter/Dio/Riverpod. Riverpod DI, Dio HTTP. See Senior_Flutter_Engineer.md.

## Offline-First Sync
20 نموذج synced. Push kinds: shipment.advance, shipment.create, trip.advance. Cursor=server updated_at, page 500. Tombstones + idempotency (operation_id). See SYNCABLE_MODELS_Reference.md.

## All APIs
See api/API_Reference.txt (259 endpoints) and api/API-ALL.txt.

## Auth
POST /api/v1/auth/token/ {username,password} -> {access,refresh,user,token_type}. Refresh: POST /api/v1/auth/token/refresh/. Profile: GET /api/v1/auth/me. Envelope: {"success":true,"message":"...","data":...,"errors":null}; errors {"success":false,"error":"..."}.

## UI/Icons/Division
Take from Django web system: templates/, static/, apps/. Mirror modules: transport (shipments, trips, customers, drivers, vehicles, goods, routes, branches, agents, payments, expenses, invoices, ledgers, vouchers, dashboard, reports), org (companies, cities, locations, entities, departments, unit-types), chart_of_accounts, journal_entries, budgets, regions, accounting_reports, accounting_reviewer, financial_analysis, reports_center, settings.

## Render env
SECRET_KEY, DATABASE_URL, DJANGO_SETTINGS_MODULE=config.settings.production, ALLOWED_HOSTS=goodstransportationsystem.onrender.com

## Build
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk

## Full architecture docs
See architecture/*.md in app_spec/.
