import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/app/app.dart';
import 'package:generic_template/core/auth/auth_tokens.dart';
import 'package:generic_template/core/auth/token_store.dart';
import 'package:generic_template/core/database/app_database.dart';
import 'package:generic_template/core/database/dao/sync_state_dao.dart';
import 'package:generic_template/core/sync/pending_operation.dart';
import 'package:generic_template/core/sync/sync_queue.dart';
import 'package:integration_test/integration_test.dart';

/// اختبار حدّي على جهاز/محاكي حقيقي:
/// يتحقق من الإقلاع والتوجيه، والتخزين الآمن (Keystore)، وقاعدة SQLite.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // يبدأ كل اختبار بلا جلسة محفوظة.
    await SecureTokenStore().clear();
  });

  testWidgets('يقلع التطبيق ويصل إلى شاشة الدخول العربية', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));

    // شاشة البداية ثم الانتقال إلى الدخول.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.text('تسجيل الدخول').evaluate().isNotEmpty) break;
    }

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('اسم المستخدم'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.text('دخول'), findsOneWidget);
  });

  testWidgets('التحقق المحلي يمنع إرسال نموذج فارغ', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.text('دخول').evaluate().isNotEmpty) break;
    }

    await tester.tap(find.text('دخول'));
    await tester.pump();

    expect(find.text('اسم المستخدم مطلوب.'), findsOneWidget);
    expect(find.text('كلمة المرور مطلوبة.'), findsOneWidget);
  });

  testWidgets('التخزين الآمن يدوّر الرموز فعليًا على الجهاز', (tester) async {
    final store = SecureTokenStore();
    const tokens = AuthTokens(access: 'device-access', refresh: 'device-refresh');

    await store.write(tokens);
    expect(await store.read(), tokens);

    await store.clear();
    expect(await store.read(), isNull);
  });

  testWidgets('قاعدة SQLite والطابور يعملان على الجهاز', (tester) async {
    final database = AppDatabase();
    addTearDown(database.close);

    final state = await SyncStateDao(database).ensure();
    expect(state.deviceId, isNotEmpty);

    final queue = SyncQueue(database);
    final operation = await queue.enqueue(
      kind: 'smoke.test',
      payload: <String, dynamic>{'id': 'smoke-1'},
    );

    expect(operation.status, OperationStatus.pending);
    expect((await queue.find(operation.operationId))?.kind, 'smoke.test');

    await queue.markApplied(operation.operationId);
    expect((await queue.counts())[OperationStatus.applied], greaterThanOrEqualTo(1));

    await queue.clear();
    expect(await queue.count(), 0);
  });
}
