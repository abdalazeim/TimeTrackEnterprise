import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/offline_scan.dart';

/// Offline roster and scan queue backed by `offline_scan.db`.
///
/// The schema and resolution rules intentionally match the reference
/// `OfflineStore.java` so rosters produced for the Android app keep working.
/// A custom [DatabaseFactory] and [path] can be injected by tests.
class OfflineStore {
  OfflineStore({
    DatabaseFactory? factory,
    String? path,
    DateTime Function()? clock,
  })  : _factory = factory,
        _path = path,
        _clock = clock ?? DateTime.now;

  static const String databaseName = 'offline_scan.db';
  static const int schemaVersion = 1;
  static const Duration dedupeWindow = Duration(milliseconds: 2500);
  static const int partialMatchMin = 8;
  static const int partialMatchMaxExtra = 4;
  static const int syncedRetentionDays = 30;

  final DatabaseFactory? _factory;
  final String? _path;
  final DateTime Function() _clock;

  Database? _database;
  String _lastCode = '';
  DateTime? _lastCodeAt;

  Future<Database> _open() async {
    final existing = _database;
    if (existing != null) return existing;
    final factory = _factory ?? databaseFactory;
    final databasePath =
        _path ?? p.join(await factory.getDatabasesPath(), databaseName);
    final database = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: _onCreate,
        onUpgrade: (db, oldVersion, newVersion) => _onCreate(db, newVersion),
      ),
    );
    _database = database;
    return database;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await db.execute(
      "CREATE TABLE IF NOT EXISTS students (student_nin TEXT PRIMARY KEY,"
      "first_name TEXT NOT NULL DEFAULT '',last_name TEXT NOT NULL DEFAULT '',"
      "full_name TEXT NOT NULL DEFAULT '',class_group TEXT NOT NULL DEFAULT '',"
      'is_active INTEGER NOT NULL DEFAULT 1)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_class '
      'ON students(class_group, last_name)',
    );
    await db.execute(
      "CREATE TABLE IF NOT EXISTS periods (id INTEGER PRIMARY KEY,"
      "name TEXT NOT NULL DEFAULT '',start_time TEXT NOT NULL DEFAULT '00:00:00',"
      "on_time_cutoff TEXT NOT NULL DEFAULT '00:00:00',"
      "absent_cutoff_time TEXT NOT NULL DEFAULT '23:59:59',"
      'sort_order INTEGER NOT NULL DEFAULT 0)',
    );
    await db.execute(
      "CREATE TABLE IF NOT EXISTS queue (id INTEGER PRIMARY KEY AUTOINCREMENT,"
      'client_id TEXT NOT NULL UNIQUE,code TEXT NOT NULL,'
      'scanned_at TEXT NOT NULL,scan_date TEXT NOT NULL,period_id INTEGER,'
      "local_status TEXT NOT NULL,student_nin TEXT,"
      "student_name TEXT NOT NULL DEFAULT '',class_group TEXT NOT NULL DEFAULT '',"
      'sync_status TEXT,sync_message TEXT,synced INTEGER NOT NULL DEFAULT 0)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_queue_pending ON queue(synced, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_queue_date ON queue(scan_date)',
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // ---------------------------------------------------------------------
  // Roster
  // ---------------------------------------------------------------------

  /// Applies the roster payload returned by `/api/mobile/offline/roster`.
  /// Returns `true` when the roster content changed (not metadata-only).
  Future<bool> applyRoster(Map<String, Object?> roster) async {
    final db = await _open();
    final unchanged = roster['unchanged'] == true;
    await db.transaction((txn) async {
      if (!unchanged) {
        await txn.delete('students');
        await txn.delete('periods');

        final students = roster['students'];
        if (students is List) {
          for (final raw in students) {
            if (raw is! Map) continue;
            final item = raw.cast<String, Object?>();
            final nin = _text(item['student_nin']).trim();
            if (nin.isEmpty) continue;
            await txn.insert(
              'students',
              <String, Object?>{
                'student_nin': nin,
                'first_name': _text(item['first_name']),
                'last_name': _text(item['last_name']),
                'full_name': _text(item['full_name']),
                'class_group': _text(item['class_group']),
                'is_active': item['is_active'] == false ? 0 : 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        final periods = roster['periods'];
        if (periods is List) {
          for (final raw in periods) {
            if (raw is! Map) continue;
            final item = raw.cast<String, Object?>();
            await txn.insert(
              'periods',
              <String, Object?>{
                'id': (item['id'] as num?)?.toInt() ?? 0,
                'name': _text(item['name']),
                'start_time': _text(item['start_time'], '00:00:00'),
                'on_time_cutoff': _text(item['on_time_cutoff'], '00:00:00'),
                'absent_cutoff_time':
                    _text(item['absent_cutoff_time'], '23:59:59'),
                'sort_order': (item['sort_order'] as num?)?.toInt() ?? 0,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }

      await _putMeta(txn, 'roster_version', _text(roster['version']));
      await _putMeta(txn, 'roster_at', _nowStamp(_clock()));
      await _putMeta(txn, 'server_date', _text(roster['server_date']));
      if (!unchanged) {
        await _putMeta(txn, 'school_name', _text(roster['school_name']));
        await _putMeta(txn, 'academic_year', _text(roster['academic_year']));
      }
    });
    return !unchanged;
  }

  Future<String> rosterVersion() => _meta('roster_version');
  Future<String> schoolName() => _meta('school_name');
  Future<String> academicYear() => _meta('academic_year');
  Future<String> rosterSyncedAt() => _meta('roster_at');
  Future<String> lastSyncAt() => _meta('last_sync_at');
  Future<String> lastServerSync() => _meta('last_sync');
  Future<String> serverDate() => _meta('server_date');

  Future<int> studentCount() => _count('SELECT COUNT(*) FROM students');
  Future<int> periodCount() => _count('SELECT COUNT(*) FROM periods');

  Future<bool> hasRoster() async =>
      await studentCount() > 0 && await periodCount() > 0;

  // ---------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------

  /// Resolves and, when valid, queues an offline scan at [at] (default: now).
  Future<ScanVerdict> scan(String rawCode, {DateTime? at}) async {
    final code = cleanCode(rawCode);
    if (code.isEmpty) {
      return const ScanVerdict(status: OfflineStatus.notFound);
    }

    final db = await _open();
    final now = at ?? _clock();
    final seconds = _secondsOfDay(now);
    final period = await _resolvePeriod(db, seconds);
    final student = await _resolveStudent(db, code);

    if (period == null) {
      return ScanVerdict(
        status: OfflineStatus.noPeriod,
        student: student,
      );
    }
    if (student == null) {
      return ScanVerdict(
        status: OfflineStatus.notFound,
        period: period,
      );
    }
    if (!student.active) {
      return ScanVerdict(
        status: OfflineStatus.inactive,
        student: student,
        period: period,
      );
    }

    final previous = _lastCodeAt;
    if (code == _lastCode &&
        previous != null &&
        now.difference(previous).inMilliseconds <
            dedupeWindow.inMilliseconds) {
      _lastCode = code;
      _lastCodeAt = now;
      return ScanVerdict(
        status: OfflineStatus.duplicate,
        student: student,
        period: period,
      );
    }

    final date = _dateOf(now);
    if (await _hasArrival(db, student.nin, period.id, date)) {
      _lastCode = code;
      _lastCodeAt = now;
      return ScanVerdict(
        status: OfflineStatus.duplicate,
        student: student,
        period: period,
      );
    }

    final status = seconds <= _timeSeconds(period.onTimeCutoff)
        ? OfflineStatus.present
        : OfflineStatus.late;
    final clientId = const Uuid().v4();
    final scannedAt = _isoTime(now);

    await db.insert(
      'queue',
      <String, Object?>{
        'client_id': clientId,
        'code': code,
        'scanned_at': scannedAt,
        'scan_date': date,
        'period_id': period.id,
        'local_status': status,
        'student_nin': student.nin,
        'student_name': student.fullName,
        'class_group': student.classGroup,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    _lastCode = code;
    _lastCodeAt = now;

    return ScanVerdict(
      status: status,
      student: student,
      period: period,
      clientId: clientId,
      scannedAt: scannedAt,
    );
  }

  Future<bool> _hasArrival(
    DatabaseExecutor db,
    String nin,
    int periodId,
    String date,
  ) async {
    final rows = await db.rawQuery(
      "SELECT 1 FROM queue WHERE student_nin = ? AND period_id = ? "
      "AND scan_date = ? AND local_status IN ('present', 'late', 'duplicate') "
      'LIMIT 1',
      <Object?>[nin, periodId, date],
    );
    return rows.isNotEmpty;
  }

  Future<AttendancePeriod?> _resolvePeriod(
    DatabaseExecutor db,
    int seconds,
  ) async {
    final rows = await db.query('periods');
    if (rows.isEmpty) return null;

    final periods = rows.map(_readPeriod).toList(growable: false);
    AttendancePeriod? insideCutoff;
    AttendancePeriod? latestStarted;
    AttendancePeriod? earliest;

    for (final period in periods) {
      final start = _timeSeconds(period.startTime);
      final cutoff = _timeSeconds(period.absentCutoff);
      if (start <= seconds &&
          seconds <= cutoff &&
          (insideCutoff == null ||
              start > _timeSeconds(insideCutoff.startTime))) {
        insideCutoff = period;
      }
      if (start <= seconds &&
          (latestStarted == null ||
              start > _timeSeconds(latestStarted.startTime))) {
        latestStarted = period;
      }
      if (earliest == null ||
          start < _timeSeconds(earliest.startTime)) {
        earliest = period;
      }
    }

    return insideCutoff ?? latestStarted ?? earliest;
  }

  Future<Student?> _resolveStudent(DatabaseExecutor db, String code) async {
    final candidates = _candidates(code);

    for (final candidate in candidates) {
      final rows = await db.query(
        'students',
        where: 'student_nin = ?',
        whereArgs: <Object?>[candidate],
        limit: 1,
      );
      if (rows.isNotEmpty) return _readStudent(rows.first);
    }

    for (final candidate in candidates) {
      if (candidate.length < partialMatchMin) continue;

      final rows = await db.query('students');
      var matches = 0;
      Student? match;
      for (final row in rows) {
        final nin = _text(row['student_nin']);
        if (nin.isEmpty) continue;
        final extra = (candidate.length - nin.length).abs();
        if (extra == 0 || extra > partialMatchMaxExtra) continue;

        final bool matched;
        if (candidate.length > nin.length) {
          matched = candidate.startsWith(nin) || candidate.endsWith(nin);
        } else {
          matched = extra <= 2 &&
              (nin.startsWith(candidate) || nin.endsWith(candidate));
        }
        if (!matched) continue;
        matches += 1;
        match = _readStudent(row);
        if (matches > 1) break;
      }
      if (matches == 1 && match != null) return match;
      if (matches > 1) return null;
    }
    return null;
  }

  /// Candidate variants used for exact and partial NIN matching.
  static List<String> _candidates(String value) {
    final cleaned = cleanCode(value).toUpperCase();
    var start = 0;
    while (start < cleaned.length && cleaned[start] == '*') {
      start++;
    }
    var end = cleaned.length;
    while (end > start && cleaned[end - 1] == '*') {
      end--;
    }
    final trimmed = cleaned.substring(start, end);

    var candidate = trimmed;
    if (trimmed.length >= 3 && trimmed.startsWith(']')) {
      final index = trimmed.length > 1 && trimmed[1] == '^' ? 2 : 1;
      if (index + 2 <= trimmed.length &&
          _isAsciiLetterOrDigit(trimmed[index]) &&
          _isAsciiLetterOrDigit(trimmed[index + 1])) {
        candidate = trimmed.substring(index + 2);
      }
    }

    final result = <String>{};
    if (candidate.isNotEmpty) result.add(candidate);
    if (trimmed.isNotEmpty) result.add(trimmed);
    if (cleaned.isNotEmpty) result.add(cleaned);
    return result.toList(growable: false);
  }

  // ---------------------------------------------------------------------
  // Queue
  // ---------------------------------------------------------------------

  Future<List<QueuedScan>> pending([int limit = 300]) => _readQueue(
        'SELECT * FROM queue WHERE synced = 0 ORDER BY id ASC LIMIT ?',
        <Object?>[limit],
      );

  Future<List<QueuedScan>> recent([int limit = 50]) => _readQueue(
        'SELECT * FROM queue ORDER BY id DESC LIMIT ?',
        <Object?>[limit],
      );

  Future<int> pendingCount() =>
      _count('SELECT COUNT(*) FROM queue WHERE synced = 0');

  Future<OfflineStats> stats() async {
    final date = _dateOf(_clock());
    final rows = await (await _open()).rawQuery(
      'SELECT local_status, COUNT(*) AS total FROM queue '
      'WHERE scan_date = ? GROUP BY local_status',
      <Object?>[date],
    );
    var today = 0;
    var late = 0;
    for (final row in rows) {
      final total = (row['total'] as num?)?.toInt() ?? 0;
      today += total;
      if (_text(row['local_status']) == OfflineStatus.late) {
        late += total;
      }
    }
    final synced = await _count(
      'SELECT COUNT(*) FROM queue WHERE scan_date = ? AND synced = 1',
      <Object?>[date],
    );
    return OfflineStats(
      today: today,
      todayLate: late,
      pending: await pendingCount(),
      synced: synced,
    );
  }

  /// Applies the `results` array returned by `/api/mobile/scans/sync`.
  Future<int> applySyncResults(Map<String, Object?> response) async {
    final rawResults = response['results'];
    if (rawResults is! List) return 0;

    final db = await _open();
    var updated = 0;
    await db.transaction((txn) async {
      for (final raw in rawResults) {
        if (raw is! Map) continue;
        final result = raw.cast<String, Object?>();
        final clientId = _text(result['client_id']);
        if (clientId.isEmpty) continue;

        final action = _text(result['action']);
        final values = <String, Object?>{
          'synced': 1,
          'sync_status': action,
          'sync_message': _text(result['message']),
        };

        var localStatus = _localStatusFor(action);
        final attendance = result['attendance'];
        if (attendance is Map) {
          final status = _text(attendance['status']).toLowerCase();
          if (status == OfflineStatus.present || status == OfflineStatus.late) {
            localStatus = status;
          }
        }
        if (localStatus != null) values['local_status'] = localStatus;

        final student = result['student'];
        if (student is Map) {
          values['student_name'] = _text(student['full_name']);
          values['class_group'] = _text(student['class_group']);
          final nin = _text(student['student_nin']);
          if (nin.isNotEmpty) values['student_nin'] = nin;
        }

        updated += await txn.update(
          'queue',
          values,
          where: 'client_id = ?',
          whereArgs: <Object?>[clientId],
        );
      }

      await _putMeta(
        txn,
        'last_sync',
        '${_text(response['server_date'])} ${_text(response['server_time'])}',
      );
      await _putMeta(txn, 'last_sync_at', _nowStamp(_clock()));
    });

    await prune();
    return updated;
  }

  Future<void> prune() async {
    final cutoff = _dateOf(
      _clock().subtract(const Duration(days: syncedRetentionDays)),
    );
    await (await _open()).delete(
      'queue',
      where: 'synced = 1 AND scan_date < ?',
      whereArgs: <Object?>[cutoff],
    );
  }

  static String? _localStatusFor(String action) {
    switch (action) {
      case 'preview_card':
      case 'not_found':
        return OfflineStatus.notFound;
      case 'present':
      case 'late':
        return action;
      case 'inactive':
        return OfflineStatus.inactive;
      case 'duplicate':
      case 'already_recorded':
        return OfflineStatus.duplicate;
      default:
        return null;
    }
  }

  Future<List<QueuedScan>> _readQueue(
    String sql,
    List<Object?> args,
  ) async {
    final rows = await (await _open()).rawQuery(sql, args);
    return rows
        .map(
          (row) => QueuedScan(
            id: (row['id'] as num?)?.toInt() ?? 0,
            clientId: _text(row['client_id']),
            code: _text(row['code']),
            scannedAt: _text(row['scanned_at']),
            scanDate: _text(row['scan_date']),
            status: _text(row['local_status']),
            studentName: _text(row['student_name']),
            classGroup: _text(row['class_group']),
            synced: (row['synced'] as num?)?.toInt() == 1,
            studentNin:
                row['student_nin'] == null ? null : _text(row['student_nin']),
            syncStatus:
                row['sync_status'] == null ? null : _text(row['sync_status']),
            syncMessage:
                row['sync_message'] == null ? null : _text(row['sync_message']),
          ),
        )
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  Future<int> _count(String sql, [List<Object?>? args]) async {
    final rows = await (await _open()).rawQuery(sql, args);
    if (rows.isEmpty) return 0;
    return (rows.first.values.first as num?)?.toInt() ?? 0;
  }

  Future<String> _meta(String key) async {
    final rows = await (await _open()).query(
      'meta',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return '';
    return _text(rows.first['value']);
  }

  static Future<void> _putMeta(
    DatabaseExecutor db,
    String key,
    String value,
  ) =>
      db.insert(
        'meta',
        <String, Object?>{'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  static AttendancePeriod _readPeriod(Map<String, Object?> row) {
    return AttendancePeriod(
      id: (row['id'] as num?)?.toInt() ?? 0,
      name: _text(row['name']),
      startTime: _text(row['start_time'], '00:00:00'),
      onTimeCutoff: _text(row['on_time_cutoff'], '00:00:00'),
      absentCutoff: _text(row['absent_cutoff_time'], '23:59:59'),
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  static Student _readStudent(Map<String, Object?> row) {
    return Student(
      nin: _text(row['student_nin']),
      firstName: _text(row['first_name']),
      lastName: _text(row['last_name']),
      fullName: _text(row['full_name']),
      classGroup: _text(row['class_group']),
      active: (row['is_active'] as num?)?.toInt() != 0,
    );
  }

  static String _text(Object? value, [String fallback = '']) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  static bool _isAsciiLetterOrDigit(String value) {
    if (value.isEmpty) return false;
    final code = value.codeUnitAt(0);
    return (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A);
  }

  /// Cleans a barcode exactly like the Android implementation.
  static String cleanCode(String? value) {
    if (value == null) return '';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      var unit = rune;
      if (unit >= 0x0660 && unit <= 0x0669) {
        unit -= 1584;
      } else if (unit >= 0x06F0 && unit <= 0x06F9) {
        unit -= 1728;
      }
      if (unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D) {
        continue;
      }
      if (unit < 0x20 || (unit >= 0x7F && unit <= 0x9F)) {
        continue;
      }
      buffer.writeCharCode(unit);
    }
    final result = buffer.toString();
    return result.length > 64 ? result.substring(0, 64) : result;
  }

  static int _timeSeconds(String? value) {
    if (value == null || value.isEmpty) return 0;
    final parts = value.split(':');
    try {
      final hours = int.parse(parts[0].trim());
      final minutes = parts.length > 1 ? int.parse(parts[1].trim()) : 0;
      final seconds = parts.length > 2 ? int.parse(parts[2].trim()) : 0;
      return hours * 3600 + minutes * 60 + seconds;
    } catch (_) {
      return 0;
    }
  }

  static int _secondsOfDay(DateTime value) =>
      value.hour * 3600 + value.minute * 60 + value.second;

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _dateOf(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${_two(value.month)}-${_two(value.day)}';

  static String _nowStamp(DateTime value) =>
      '${_dateOf(value)} ${_two(value.hour)}:${_two(value.minute)}:'
      '${_two(value.second)}';

  static String _isoTime(DateTime value) {
    final offset = value.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absolute = offset.abs();
    return '${_dateOf(value)}T${_two(value.hour)}:${_two(value.minute)}:'
        '${_two(value.second)}$sign${_two(absolute.inHours)}:'
        '${_two(absolute.inMinutes.remainder(60))}';
  }

  /// Exposed for tests and diagnostics.
  static int timeSeconds(String value) => _timeSeconds(value);
  static int secondsOfDay(DateTime value) => _secondsOfDay(value);
  static String isoTime(DateTime value) => _isoTime(value);
  static String dateOf(DateTime value) => _dateOf(value);

  /// A random sample used by the test suite without opening a database.
  static String sampleCode([int length = 12]) {
    final random = Random();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(random.nextInt(10));
    }
    return buffer.toString();
  }
}
