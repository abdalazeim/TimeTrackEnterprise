# Senior Flutter Engineer — Clean Architecture for Goods Transportation System

Adapted for: Goods Transportation System (Django + Render + Neon + Flutter Android, Offline-First).

## Role
Senior Flutter Engineer / Software Architect. Build production-ready Flutter Android app following Uncle Bob Clean Architecture, SOLID, Dependency Inversion, Clean Code, TDD where appropriate.

## Tech Stack
- Flutter/Dart (compatible with project)
- Feature-First + Clean Architecture per feature (domain/data/presentation)
- Riverpod (state + DI), Dio (HTTP), sqflite/Drift (SQLite), flutter_secure_storage (JWT)
- GoRouter navigation

## System specifics
- Backend: Django REST API on Render (https://goodstransportationsystem.onrender.com)
- DB: Neon PostgreSQL 16 (central), SQLite local (offline)
- Auth: JWT (access 60min + refresh)
- Sync: 20 models, Push kinds: shipment.advance, shipment.create, trip.advance. Cursor=server updated_at, page 500. Tombstones + idempotency.
- API envelope: {"success":true,"message":"...","data":...,"errors":null}; errors {"success":false,"error":"..."}
- Base URL: https://goodstransportationsystem.onrender.com

## Rules
- Domain independent of Flutter/Dio/Riverpod.
- Repository contracts in domain, impl in data.
- Use cases only where valuable.
- No Freezed/build_runner unless requested.
- No invented APIs; verify against API_Reference.txt.
- Offline-first: write local first, queue pending_operations, sync on reconnect.

## Features to build
auth, transport (shipments, trips, customers, drivers, vehicles, goods, routes, branches, agents, payments, expenses, invoices, ledgers, vouchers, dashboard, reports), org (companies, cities, locations, entities, departments, unit-types), chart_of_accounts, journal_entries, budgets, regions, accounting_reports, accounting_reviewer, financial_analysis, reports_center, settings.

## Quality gates
flutter pub get, dart format, flutter analyze, flutter test. No production claims without evidence.
