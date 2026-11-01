import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// مالك قاعدة البيانات المحلية: فتح واحد، ترحيلات، وإغلاق نظيف.
class AppDatabase {
  AppDatabase({
    DatabaseFactory? factory,
    String? path,
    String? Function()? scopeKey,
  })  : _factory = factory,
        _path = path,
        _scopeKey = scopeKey;

  static const String fileName = 'generic_template.db';

  final DatabaseFactory? _factory;
  final String? _path;
  final String? Function()? _scopeKey;

  Database? _database;
  String? _databaseScope;
  Future<Database>? _opening;

  bool get isOpen => _database?.isOpen ?? false;

  Future<Database> open() async {
    while (true) {
      final requestedScope = _scopeKey?.call();
      final existing = _database;
      if (existing != null &&
          existing.isOpen &&
          _databaseScope == requestedScope) {
        return existing;
      }

      final pending = _opening;
      if (pending != null) {
        await pending;
        continue;
      }

      final future = _open(requestedScope);
      _opening = future;
      try {
        final database = await future;
        if (_scopeKey?.call() == requestedScope) return database;
      } finally {
        if (identical(_opening, future)) _opening = null;
      }
    }
  }

  Future<Database> _open(String? requestedScope) async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
    _database = null;
    _databaseScope = null;

    final factory = _factory ?? databaseFactory;
    final explicitPath = _path;
    final root = explicitPath == null
        ? await factory.getDatabasesPath()
        : p.dirname(explicitPath);
    final baseName = explicitPath == null ? fileName : p.basename(explicitPath);
    final databasePath = requestedScope == null
        ? (_path ?? p.join(root, fileName))
        : p.join(root, _scopedFileName(baseName, requestedScope));

    final database = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    _database = database;
    _databaseScope = requestedScope;
    return database;
  }

  String _scopedFileName(String baseName, String scope) {
    final extension = p.extension(baseName);
    final stem =
        extension.isEmpty ? baseName : p.basenameWithoutExtension(baseName);
    final bytes = utf8.encode(scope);
    // Two stable 32-bit FNV-1a hashes keep account identifiers out of paths.
    final first = _fnv1a(bytes, 0x811c9dc5);
    final second = _fnv1a(bytes.reversed.toList(growable: false), 0x9e3779b9);
    final suffix = '${first.toRadixString(16).padLeft(8, '0')}'
        '${second.toRadixString(16).padLeft(8, '0')}';
    return '${stem}_$suffix${extension.isEmpty ? '.db' : extension}';
  }

  int _fnv1a(List<int> bytes, int seed) {
    var hash = seed;
    for (final byte in bytes) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final statement in DatabaseSchema.createStatements) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      final statements = DatabaseSchema.migrations[version] ?? const <String>[];
      for (final statement in statements) {
        await db.execute(statement);
      }
    }
  }

  Future<void> close() async {
    final pending = _opening;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // A failed open leaves nothing to close.
      }
    }
    final database = _database;
    _database = null;
    _databaseScope = null;
    if (database != null && database.isOpen) {
      await database.close();
    }
  }
}
