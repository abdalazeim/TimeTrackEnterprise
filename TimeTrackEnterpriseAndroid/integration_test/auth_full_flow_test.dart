import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/app/app.dart';
import 'package:generic_template/core/auth/profile_store.dart';
import 'package:generic_template/core/auth/token_store.dart';
import 'package:generic_template/core/di/providers.dart';
import 'package:generic_template/core/network/dio_factory.dart';
import 'package:integration_test/integration_test.dart';

/// يتحقق من مسار النجاح الكامل على جهاز حقيقي دون لمس الإنتاج:
/// دخول → حفظ آمن → /auth/me → الرئيسية → إعادة تشغيل → خروج.
///
/// الخادم وهمي ويعمل داخل التطبيق على 127.0.0.1؛ لذلك لا يحتاج حسابًا حقيقيًا.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const username = 'demo_user';
  const password = 'demo_password';
  const access = 'test-access-1';
  const refresh = 'test-refresh-1';

  late HttpServer server;
  late String baseUrl;
  late List<String> calls;

  Future<void> handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    calls.add('${request.method} $path');
    final response = request.response;
    response.headers.contentType = ContentType(
      'application',
      'json',
      charset: 'utf-8',
    );

    switch (path) {
      case '/api/v1/auth/token/':
        final raw = await utf8.decoder.bind(request).join();
        final body = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map;
        if (body['username'] != username || body['password'] != password) {
          response.statusCode = 401;
          response.write(
            jsonEncode(<String, dynamic>{
              'success': false,
              'error': 'No active account found with the given credentials',
              'data': null,
            }),
          );
        } else {
          response.write(
            jsonEncode(<String, dynamic>{
              'success': true,
              'message': 'تم تسجيل الدخول بنجاح',
              'data': <String, dynamic>{
                'access': access,
                'refresh': refresh,
                'user': <String, dynamic>{'id': 7, 'username': username},
                'token_type': 'Bearer',
              },
            }),
          );
        }
      case '/api/v1/auth/me':
        if (request.headers.value('Authorization') != 'Bearer $access') {
          response.statusCode = 401;
          response.write(
            jsonEncode(<String, dynamic>{
              'success': false,
              'error': 'unauthorized',
            }),
          );
        } else {
          response.write(
            jsonEncode(<String, dynamic>{
              'success': true,
              'message': 'ok',
              'data': <String, dynamic>{'id': 7, 'username': username},
            }),
          );
        }
      case '/api/v1/auth/logout':
        await request.drain<void>();
        response.write(
          jsonEncode(<String, dynamic>{'success': true, 'message': 'ok'}),
        );
      default:
        await request.drain<void>();
        response.statusCode = 404;
        response.write(
          jsonEncode(<String, dynamic>{
            'success': false,
            'error': 'not found',
          }),
        );
    }

    await response.close();
  }

  setUp(() async {
    await SecureTokenStore().clear();
    await SecureProfileStore().clear();
    calls = <String>[];

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
    server.listen(handleRequest);
  });

  tearDown(() async {
    await server.close(force: true);
  });

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail('لم يظهر العنصر المطلوب: $finder');
  }

  testWidgets('دخول ناجح، استعادة جلسة، ثم خروج', (tester) async {
    // ---------- 1) الدخول ----------
    final dio = createDio(baseUrl: baseUrl);
    addTearDown(() => dio.close(force: true));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[dioProvider.overrideWithValue(dio)],
        child: const App(),
      ),
    );
    await waitFor(tester, find.text('دخول'));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, username);
    await tester.enterText(fields.last, password);
    await tester.tap(find.text('دخول'));

    await waitFor(tester, find.textContaining('أهلًا'));
    expect(find.textContaining(username), findsWidgets);

    // الرموز والملف حُفظا فعليًا في التخزين الآمن على الجهاز.
    final stored = await SecureTokenStore().read();
    expect(stored?.access, access);
    expect(stored?.refresh, refresh);
    final profile = await SecureProfileStore().read();
    expect(profile?['username'], username);

    expect(calls, contains('POST /api/v1/auth/token/'));

    // ---------- 2) إعادة تشغيل التطبيق: استعادة الجلسة ----------
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    dio.close(force: true);

    final restartedDio = createDio(baseUrl: baseUrl);
    addTearDown(() => restartedDio.close(force: true));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[dioProvider.overrideWithValue(restartedDio)],
        child: const App(),
      ),
    );

    await waitFor(tester, find.textContaining('أهلًا'));
    expect(find.text('تسجيل الدخول'), findsNothing, reason: 'استُعيدت الجلسة');
    expect(find.textContaining(username), findsWidgets);
    expect(
      calls,
      contains('GET /api/v1/auth/me'),
      reason: 'الاستعادة تستخدم /auth/me مع رأس Bearer',
    );

    // ---------- 3) الخروج ----------
    await tester.tap(find.byTooltip('تسجيل الخروج'));
    await waitFor(tester, find.text('خروج'));
    await tester.tap(find.text('خروج'));

    await waitFor(tester, find.text('تسجيل الدخول'));
    expect(await SecureTokenStore().read(), isNull);
    expect(await SecureProfileStore().read(), isNull);

    // الإبلاغ الاختياري للخادم لا يعطّل الخروج.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!calls.contains('POST /api/v1/auth/logout') &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(calls, contains('POST /api/v1/auth/logout'));
  }, timeout: const Timeout(Duration(minutes: 4)),);
}

