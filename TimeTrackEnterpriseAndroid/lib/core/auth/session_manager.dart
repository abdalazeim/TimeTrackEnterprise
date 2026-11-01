import 'dart:async';

import 'auth_tokens.dart';
import 'token_store.dart';

/// دالة تجديد الرموز. تُمرَّر من طبقة الميزة لتفادي اعتماد `core` على `features`.
typedef RefreshTokensCallback = Future<AuthTokens> Function(
  String refreshToken,
);

enum SessionEventType { signedIn, refreshed, expired, signedOut }

class SessionEvent {
  const SessionEvent(this.type, {this.reason});

  final SessionEventType type;
  final String? reason;

  @override
  String toString() => 'SessionEvent($type, reason: $reason)';
}

/// مالك الجلسة: الرموز، التجديد أحادي التنفيذ، والانتهاء.
class SessionManager {
  SessionManager({
    required TokenStore store,
    required RefreshTokensCallback refreshTokens,
  })  : _store = store,
        _refreshTokens = refreshTokens;

  final TokenStore _store;
  final RefreshTokensCallback _refreshTokens;
  final StreamController<SessionEvent> _events =
      StreamController<SessionEvent>.broadcast();

  AuthTokens? _tokens;
  Future<AuthTokens?>? _inFlightRefresh;
  Future<void> _storageTail = Future<void>.value();
  int _generation = 0;

  Stream<SessionEvent> get events => _events.stream;

  AuthTokens? get tokens => _tokens;

  bool get hasTokens => _tokens?.isValid ?? false;

  String? get accessToken => _tokens?.access;

  /// يستعيد الرموز من التخزين الآمن عند الإقلاع.
  Future<AuthTokens?> restore() async {
    final generation = _generation;
    try {
      final restored = await _store.read();
      if (generation == _generation) _tokens = restored;
    } catch (_) {
      if (generation == _generation) _tokens = null;
    }
    return _tokens;
  }

  /// يحفظ جلسة جديدة بعد نجاح الدخول.
  Future<void> save(AuthTokens tokens) async {
    final generation = ++_generation;
    _tokens = tokens;
    await _serializeStorage(() async {
      if (generation == _generation) await _store.write(tokens);
    });
    if (generation == _generation) {
      _emit(const SessionEvent(SessionEventType.signedIn));
    }
  }

  /// يحدّث الرموز بعد تدوير الخادم (access + refresh معًا).
  Future<void> update(AuthTokens tokens) async {
    final generation = ++_generation;
    _tokens = tokens;
    await _serializeStorage(() async {
      if (generation == _generation) await _store.write(tokens);
    });
    if (generation == _generation) {
      _emit(const SessionEvent(SessionEventType.refreshed));
    }
  }

  /// Associates a legacy restored session with the identity returned by /me.
  /// This changes only local session metadata; it does not report a refresh.
  Future<void> bindIdentity(AuthTokens tokens) async {
    final generation = ++_generation;
    _tokens = tokens;
    await _serializeStorage(() async {
      if (generation == _generation) await _store.write(tokens);
    });
  }

  /// تجديد أحادي التنفيذ: مهما تعددت الطلبات، يحدث تجديد واحد فقط.
  Future<String?> refreshAccessToken() {
    final running = _inFlightRefresh;
    if (running != null) {
      return running.then((tokens) => tokens?.access);
    }

    final future = _performRefresh();
    _inFlightRefresh = future;
    return future.whenComplete(() => _inFlightRefresh = null).then(
          (tokens) => tokens?.access,
        );
  }

  Future<AuthTokens?> _performRefresh() async {
    final generation = _generation;
    final current = _tokens ?? await _store.read();
    if (generation != _generation) return null;
    if (current == null || current.refresh.isEmpty) {
      await expire(reason: 'لا توجد جلسة قابلة للتجديد.');
      return null;
    }

    try {
      final rotated = await _refreshTokens(current.refresh);
      if (generation != _generation) return null;
      if (!rotated.isValid) {
        await expire(reason: 'أعاد الخادم رموزًا غير صالحة.');
        return null;
      }
      final identified = rotated.copyWith(
        userId: rotated.userId ?? current.userId,
        server: rotated.server ?? current.server,
      );
      _tokens = identified;
      await _serializeStorage(() async {
        if (generation == _generation) await _store.write(identified);
      });
      if (generation != _generation) return null;
      _emit(const SessionEvent(SessionEventType.refreshed));
      return identified;
    } catch (error) {
      if (generation != _generation) return null;
      await expire(reason: 'فشل تجديد الجلسة: $error');
      return null;
    }
  }

  /// ينتهي بسبب فشل التجديد — يمسح الرموز ويُعلم المستمعين.
  Future<void> expire({String? reason}) async {
    final generation = ++_generation;
    _tokens = null;
    try {
      await _serializeStorage(() async {
        if (generation == _generation) await _store.clear();
      });
    } catch (_) {
      // لا نمنع تسجيل الخروج بسبب فشل التخزين.
    }
    if (generation == _generation) {
      _emit(SessionEvent(SessionEventType.expired, reason: reason));
    }
  }

  /// خروج صريح بطلب المستخدم.
  Future<void> signOut() async {
    final generation = ++_generation;
    _tokens = null;
    try {
      await _serializeStorage(() async {
        if (generation == _generation) await _store.clear();
      });
    } catch (_) {
      // تجاهل — الحالة في الذاكرة أصبحت فارغة على أي حال.
    }
    if (generation == _generation) {
      _emit(const SessionEvent(SessionEventType.signedOut));
    }
  }

  Future<void> dispose() => _events.close();

  Future<void> _serializeStorage(Future<void> Function() action) {
    final next = _storageTail.then((_) => action());
    _storageTail = next.catchError((Object _) {});
    return next;
  }

  void _emit(SessionEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
