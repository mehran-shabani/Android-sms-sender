import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/app_settings.dart';
import '../models/contact_record.dart';

class LocalDbService {
  LocalDbService._();
  static final LocalDbService instance = LocalDbService._();

  Database? _db;

  Future<Database> init() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'android_sms_sender.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE contacts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_row INTEGER NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  full_name TEXT NOT NULL,
  token TEXT NOT NULL,
  phone TEXT NOT NULL,
  raw_phone TEXT NOT NULL,
  message TEXT NOT NULL,
  is_valid_phone INTEGER NOT NULL,
  is_duplicate INTEGER NOT NULL,
  status TEXT NOT NULL,
  error TEXT,
  sent_at INTEGER,
  delivered_at INTEGER,
  sms_part_count INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
        await db.execute('''
CREATE TABLE app_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  sms_template TEXT NOT NULL,
  delay_seconds INTEGER NOT NULL,
  skip_duplicates INTEGER NOT NULL,
  skip_invalid INTEGER NOT NULL,
  selected_subscription_id INTEGER
)
''');
        await db.insert('app_settings', AppSettings.defaults().toMap());
      },
    );
    return _db!;
  }

  Future<void> insertContacts(List<ContactRecord> contacts) async {
    final db = await init();
    await db.transaction((txn) async {
      for (final contact in contacts) {
        await txn.insert('contacts', contact.toMap()..remove('id'));
      }
    });
  }

  Future<List<ContactRecord>> getAllContacts() async {
    final db = await init();
    final rows = await db.query('contacts', orderBy: 'source_row ASC, id ASC');
    return rows.map(ContactRecord.fromMap).toList();
  }

  Future<List<ContactRecord>> getContactsByStatus(ContactStatus status) async {
    final db = await init();
    final rows = await db.query(
      'contacts',
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'source_row ASC, id ASC',
    );
    return rows.map(ContactRecord.fromMap).toList();
  }

  Future<void> updateContact(ContactRecord contact) async {
    if (contact.id == null) return;
    final db = await init();
    await db.update(
      'contacts',
      contact.copyWith(updatedAt: DateTime.now()).toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<void> updateContactStatus(
    int id,
    ContactStatus status, {
    String? error,
    DateTime? sentAt,
    DateTime? deliveredAt,
  }) async {
    final db = await init();
    await db.update(
      'contacts',
      {
        'status': status.name,
        'error': error,
        'sent_at': sentAt?.millisecondsSinceEpoch,
        'delivered_at': deliveredAt?.millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearContacts() async {
    final db = await init();
    await db.delete('contacts');
  }

  Future<Map<String, int>> getStats() async {
    final db = await init();
    final total = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM contacts'),
        ) ??
        0;
    final valid = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM contacts WHERE is_valid_phone = 1'),
        ) ??
        0;
    final invalid = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM contacts WHERE is_valid_phone = 0'),
        ) ??
        0;
    final duplicates = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM contacts WHERE is_duplicate = 1'),
        ) ??
        0;
    final stats = <String, int>{
      'total': total,
      'valid': valid,
      'invalid': invalid,
      'duplicates': duplicates,
    };
    for (final status in ContactStatus.values) {
      stats[status.name] = Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM contacts WHERE status = ?',
              [status.name],
            ),
          ) ??
          0;
    }
    return stats;
  }

  Future<AppSettings> getSettings() async {
    final db = await init();
    final rows = await db.query('app_settings', where: 'id = 1', limit: 1);
    return rows.isEmpty ? AppSettings.defaults() : AppSettings.fromMap(rows.first);
  }

  Future<void> saveSettings(AppSettings settings) async {
    final db = await init();
    await db.insert(
      'app_settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
