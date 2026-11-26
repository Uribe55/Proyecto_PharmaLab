import 'dart:convert';

import 'package:sqflite/sqflite.dart';

abstract interface class PendingCheckoutStore {
  Future<Map<String, dynamic>?> read(String uid);
  Future<void> write(String uid, Map<String, dynamic>? request);
}

/// Escribe ANTES del envío. No contiene contraseñas ni tokens.
class SqlitePendingCheckoutStore implements PendingCheckoutStore {
  Future<Database>? _opening;
  Future<Database> get _database => _opening ??= _open();
  Future<Database> _open() async => openDatabase(
    '${await getDatabasesPath()}/pharmalab_checkout.db',
    version: 1,
    onConfigure: (db) async {
      await db.execute('PRAGMA synchronous = FULL');
    },
    onCreate: (db, _) async {
      await db.execute(
        'CREATE TABLE pending_checkout (uid TEXT PRIMARY KEY, request TEXT NOT NULL)',
      );
    },
  );
  @override
  Future<Map<String, dynamic>?> read(String uid) async {
    final rows = await (await _database).query(
      'pending_checkout',
      columns: ['request'],
      where: 'uid = ?',
      whereArgs: [uid],
    );
    final raw = rows.isEmpty ? null : rows.single['request'] as String;
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<void> write(String uid, Map<String, dynamic>? request) async {
    await (await _database).transaction((tx) async {
      if (request == null) {
        await tx.delete('pending_checkout', where: 'uid = ?', whereArgs: [uid]);
      } else {
        await tx.insert('pending_checkout', {
          'uid': uid,
          'request': jsonEncode(request),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
