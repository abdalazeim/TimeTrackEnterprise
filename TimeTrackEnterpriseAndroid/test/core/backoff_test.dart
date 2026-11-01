import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/sync/backoff.dart';

void main() {
  group('Backoff', () {
    const backoff = Backoff(
      base: Duration(seconds: 10),
      maxDelay: Duration(minutes: 5),
      maxAttempts: 5,
    );

    test('يتضاعف مع كل محاولة', () {
      expect(backoff.delayFor(1), const Duration(seconds: 10));
      expect(backoff.delayFor(2), const Duration(seconds: 20));
      expect(backoff.delayFor(3), const Duration(seconds: 40));
      expect(backoff.delayFor(4), const Duration(seconds: 80));
    });

    test('لا يتجاوز السقف', () {
      expect(backoff.delayFor(20), const Duration(minutes: 5));
    });

    test('يعامل المحاولة غير الصالحة كالأولى', () {
      expect(backoff.delayFor(0), const Duration(seconds: 10));
      expect(backoff.delayFor(-3), const Duration(seconds: 10));
    });

    test('يوقف المحاولات عند السقف', () {
      expect(backoff.canRetry(4), isTrue);
      expect(backoff.canRetry(5), isFalse);
      expect(backoff.canRetry(9), isFalse);
    });
  });
}
