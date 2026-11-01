# Flutter App Specification — Goods Transportation System

## Base URL
https://goodstransportationsystem.onrender.com

## All APIs
See `api/API_Reference.txt` (259 endpoints) and `api/API-ALL.txt`.

## Architecture
Clean Architecture (Uncle Bob) — Feature-First. See `GDS-Android-Template/Senior Flutter Engineer — Clean Architecture.txt`.

## Offline-First Sync
- 20 syncable models (see SYNCABLE_MODELS_Reference.md)
- Push kinds: shipment.advance, shipment.create, trip.advance
- Cursor: server updated_at, page size 500
- Tombstones + idempotency via operation_id

## UI / Icons / Division
Take icons, screens, divisions from the Django web system at `D:\Project Django Frameworks\GoodsTransportationSystem` (templates/, static/, apps/). Mirror module names: transport (shipments, trips, customers, drivers, vehicles, goods, routes, branches, agents, payments, expenses, invoices, ledgers, vouchers, dashboard, reports), org (companies, cities, locations, entities, departments, unit-types), chart_of_accounts, journal_entries, budgets, regions, accounting_reports, accounting_reviewer, financial_analysis, reports_center, settings.

## Auth
JWT: POST /api/v1/auth/token/  {username, password} -> {access, refresh, user, token_type}. Refresh: POST /api/v1/auth/token/refresh/. Profile: GET /api/v1/auth/me.

## Standard envelope
Success: {"success":true,"message":"...","data":...,"errors":null}
Error: {"success":false,"error":"..."}

## Render env
SECRET_KEY, DATABASE_URL, DJANGO_SETTINGS_MODULE=config.settings.production, ALLOWED_HOSTS=goodstransportationsystem.onrender.com

## Build on target machine
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk
