import '../../domain/entities/scan_event.dart';

/// In-memory ring of barcode scans served by the local HTTP gateway.
///
/// It mirrors `ScanQueue` from the reference app:
/// * normalises Arabic-Indic and Persian digits,
/// * removes whitespace/control characters and clamps the code to 64 chars,
/// * drops the same code scanned twice within 2.5 seconds,
/// * keeps at most 40 scans for 10 minutes.
class ScanQueue {
  ScanQueue({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const int maxItems = 40;
  static const int maxCodeLength = 64;
  static const Duration dedupeWindow = Duration(milliseconds: 2500);
  static const Duration maxAge = Duration(minutes: 10);

  final DateTime Function() _clock;
  final List<ScanEvent> _items = <ScanEvent>[];

  int _lastSeq = 0;
  int _received = 0;
  String _lastCode = '';
  DateTime? _lastAt;

  int get lastSeq => _lastSeq;
  int get received => _received;
  int get pending => _items.length;
  List<ScanEvent> get items => List<ScanEvent>.unmodifiable(_items);

  /// Adds a scan and returns its sequence, or 0 when the scan was ignored.
  int add(String code) {
    final normalised = normalizeCode(code);
    if (normalised.isEmpty) return 0;

    final now = _clock();
    final previous = _lastAt;
    if (normalised == _lastCode &&
        previous != null &&
        now.difference(previous) < dedupeWindow) {
      return 0;
    }

    _lastCode = normalised;
    _lastAt = now;
    _prune(now);

    _lastSeq += 1;
    final event = ScanEvent(seq: _lastSeq, code: normalised, at: now);
    _items.add(event);
    while (_items.length > maxItems) {
      _items.removeAt(0);
    }
    _received += 1;
    return event.seq;
  }

  /// Scans newer than [after], oldest first. The HTTP layer limits the response
  /// to 20 items, exactly like the reference implementation.
  List<ScanEvent> since(int after) {
    _prune(_clock());
    return _items.where((event) => event.seq > after).toList(growable: false);
  }

  void clear() {
    _items.clear();
    _lastCode = '';
    _lastAt = null;
  }

  void _prune(DateTime now) {
    while (_items.isNotEmpty && now.difference(_items.first.at) > maxAge) {
      _items.removeAt(0);
    }
  }

  /// Normalises a barcode the same way the Android gateway did.
  static String normalizeCode(String? value) {
    if (value == null) return '';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      var unit = rune;
      if (unit >= 0x0660 && unit <= 0x0669) {
        unit -= 1584; // Arabic-Indic digits -> ASCII
      } else if (unit >= 0x06F0 && unit <= 0x06F9) {
        unit -= 1728; // Extended Arabic-Indic digits -> ASCII
      }
      if (unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D) {
        continue;
      }
      // Ignore ISO control characters.
      if (unit < 0x20 || (unit >= 0x7F && unit <= 0x9F)) {
        continue;
      }
      buffer.writeCharCode(unit);
    }
    final result = buffer.toString();
    return result.length > maxCodeLength
        ? result.substring(0, maxCodeLength)
        : result;
  }
}
