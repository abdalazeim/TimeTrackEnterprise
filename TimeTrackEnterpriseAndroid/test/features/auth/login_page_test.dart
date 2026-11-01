import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/di/providers.dart';
import 'package:generic_template/features/auth/presentation/pages/login_page.dart';

import '../../helpers/fakes.dart';

Future<void> _pumpLogin(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: <Locale>[Locale('ar')],
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: LoginPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('يعرض شاشة الدخول بالعربية', (tester) async {
    await _pumpLogin(tester);

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('اسم المستخدم'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.text('دخول'), findsOneWidget);
  });

  testWidgets('يمنع الإرسال الفارغ ويعرض رسائل التحقق', (tester) async {
    await _pumpLogin(tester);

    await tester.tap(find.text('دخول'));
    await tester.pump();

    expect(find.text('اسم المستخدم مطلوب.'), findsOneWidget);
    expect(find.text('كلمة المرور مطلوبة.'), findsOneWidget);
  });

  testWidgets('يبدّل إظهار/إخفاء كلمة المرور', (tester) async {
    await _pumpLogin(tester);

    TextField passwordField() =>
        tester.widget<TextField>(find.byType(TextField).last);

    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byTooltip('إظهار كلمة المرور'));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);

    await tester.tap(find.byTooltip('إخفاء كلمة المرور'));
    await tester.pump();

    expect(passwordField().obscureText, isTrue);
  });
}
