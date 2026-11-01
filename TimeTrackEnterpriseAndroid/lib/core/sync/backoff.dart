import 'dart:math' as math;

/// تباعد أسّي بسيط وقابل للاختبار (لا عشوائية).
class Backoff {
  const Backoff({
    this.base = const Duration(seconds: 30),
    this.maxDelay = const Duration(minutes: 30),
    this.multiplier = 2,
    this.maxAttempts = 8,
  });

  final Duration base;
  final Duration maxDelay;
  final int multiplier;
  final int maxAttempts;

  /// `attempt` يبدأ من 1 بعد أول فشل.
  Duration delayFor(int attempt) {
    final safeAttempt = attempt < 1 ? 1 : attempt;
    final seconds = base.inSeconds * math.pow(multiplier, safeAttempt - 1);
    final capped = math.min(seconds.toDouble(), maxDelay.inSeconds.toDouble());
    return Duration(seconds: capped.round());
  }

  bool canRetry(int attempts) => attempts < maxAttempts;
}
