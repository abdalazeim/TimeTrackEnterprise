import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/auth/auth_tokens.dart';
import 'package:generic_template/core/auth/session_manager.dart';

import '../helpers/fakes.dart';

void main() {
  group('SessionManager', () {
    const initial = AuthTokens(access: 'a1', refresh: 'r1');

    test('يستعيد الرموز من التخزين', () async {
      final store = InMemoryTokenStore(initial);
      final session = SessionManager(
        store: store,
        refreshTokens: (_) async => initial,
      );

      final tokens = await session.restore();

      expect(tokens, initial);
      expect(session.hasTokens, isTrue);
      expect(session.accessToken, 'a1');
    });

    test('يحفظ الرموز بعد الدخول ويطلق حدث signedIn', () async {
      final store = InMemoryTokenStore();
      final session = SessionManager(
        store: store,
        refreshTokens: (_) async => initial,
      );
      final events = <SessionEventType>[];
      final subscription =
          session.events.listen((event) => events.add(event.type));

      await session.save(initial);
      await Future<void>.delayed(Duration.zero);

      expect(store.current, initial);
      expect(events, contains(SessionEventType.signedIn));

      await subscription.cancel();
      await session.dispose();
    });

    test('تجديد أحادي التنفيذ مهما تعددت الطلبات', () async {
      final store = InMemoryTokenStore(initial);
      final gate = Completer<void>();
      var calls = 0;

      final session = SessionManager(
        store: store,
        refreshTokens: (refresh) async {
          calls++;
          expect(refresh, 'r1');
          await gate.future;
          return const AuthTokens(access: 'a2', refresh: 'r2');
        },
      );

      await session.restore();

      final first = session.refreshAccessToken();
      final second = session.refreshAccessToken();
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);

      gate.complete();
      expect(await first, 'a2');
      expect(await second, 'a2');
      expect(store.current?.access, 'a2');
      expect(store.current?.refresh, 'r2', reason: 'يجب حفظ refresh المدوّر');
      expect(session.tokens?.refresh, 'r2');
    });

    test('فشل التجديد يمسح الرموز ويطلق expired', () async {
      final store = InMemoryTokenStore(initial);
      final session = SessionManager(
        store: store,
        refreshTokens: (_) async => throw StateError('network down'),
      );
      await session.restore();
      final events = <SessionEventType>[];
      final subscription =
          session.events.listen((event) => events.add(event.type));

      final result = await session.refreshAccessToken();
      await Future<void>.delayed(Duration.zero);

      expect(result, isNull);
      expect(session.hasTokens, isFalse);
      expect(store.current, isNull);
      expect(events, contains(SessionEventType.expired));

      await subscription.cancel();
      await session.dispose();
    });

    test('نتيجة تجديد الحساب السابق لا تعيد الجلسة بعد تسجيل الخروج', () async {
      final owned = initial.copyWith(userId: 9);
      final store = InMemoryTokenStore(owned);
      final gate = Completer<void>();
      final session = SessionManager(
        store: store,
        refreshTokens: (_) async {
          await gate.future;
          return const AuthTokens(
            access: 'stale-access',
            refresh: 'stale-refresh',
          );
        },
      );
      await session.restore();

      final refresh = session.refreshAccessToken();
      await Future<void>.delayed(Duration.zero);
      await session.signOut();
      gate.complete();

      expect(await refresh, isNull);
      expect(session.tokens, isNull);
      expect(store.current, isNull);
      await session.dispose();
    });

    test('نتيجة تجديد الحساب السابق لا تستبدل حسابًا دخل لاحقًا', () async {
      final owned = initial.copyWith(userId: 9);
      const nextAccount = AuthTokens(
        access: 'account-b-access',
        refresh: 'account-b-refresh',
        userId: 10,
      );
      final store = InMemoryTokenStore(owned);
      final gate = Completer<void>();
      final session = SessionManager(
        store: store,
        refreshTokens: (_) async {
          await gate.future;
          return const AuthTokens(
            access: 'stale-access',
            refresh: 'stale-refresh',
          );
        },
      );
      await session.restore();

      final refresh = session.refreshAccessToken();
      await Future<void>.delayed(Duration.zero);
      await session.save(nextAccount);
      gate.complete();

      expect(await refresh, isNull);
      expect(session.tokens?.userId, 10);
      expect(store.current?.access, nextAccount.access);
      expect(store.current?.userId, 10);
      await session.dispose();
    });

    test('لا يجدّد بلا refresh token', () async {
      final store = InMemoryTokenStore();
      final session = SessionManager(
        store: store,
        refreshTokens: (_) async => initial,
      );
      await session.restore();

      expect(await session.refreshAccessToken(), isNull);
      expect(session.hasTokens, isFalse);
    });

    test('الخروج يمسح كل شيء ويطلق signedOut', () async {
      final store = InMemoryTokenStore(initial);
      final session = SessionManager(
        store: store,
        refreshTokens: (_) async => initial,
      );
      await session.restore();
      final events = <SessionEventType>[];
      final subscription =
          session.events.listen((event) => events.add(event.type));

      await session.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(store.current, isNull);
      expect(session.tokens, isNull);
      expect(events, contains(SessionEventType.signedOut));

      await subscription.cancel();
      await session.dispose();
    });
  });
}
