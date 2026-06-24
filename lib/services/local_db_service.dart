import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/app_settings.dart';
import '../models/contact_record.dart';

enum ContactListFilter { all, valid, invalid, duplicate, pending, sent, failed }

class LocalDbService {
  LocalDbService._();
  static final LocalDbService instance = LocalDbService._();

  Database? _db;

  Future<Database> init() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'android_sms_sender.db'),
      version: 3,
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
  updated_at INTEGER NOT NULL,
  is_selected INTEGER NOT NULL DEFAULT 0
)
''');
        await _createIndexes(db);
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE contacts '
            'ADD COLUMN is_selected INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await _createIndexes(db);
        }
      },
    );
    return _db!;
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_contacts_source_row_id '
      'ON contacts(source_row, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_contacts_status_source '
      'ON contacts(status, source_row, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_contacts_selected_source '
      'ON contacts(is_selected, source_row, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_contacts_valid_source '
      'ON contacts(is_valid_phone, source_row, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_contacts_duplicate_source '
      'ON contacts(is_duplicate, source_row, id)',
    );
  }

  Future<void> insertContacts(List<ContactRecord> contacts) async {
    final db = await init();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final contact in contacts) {
        batch.insert('contacts', contact.toMap()..remove('id'));
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<ContactRecord>> getAllContacts() async {
    final db = await init();
    final rows = await db.query('contacts', orderBy: 'source_row ASC, id ASC');
    return rows.map(ContactRecord.fromMap).toList();
  }

  Future<List<ContactRecord>> getContactsPage({
    required int limit,
    required int offset,
    ContactListFilter filter = ContactListFilter.all,
    String query = '',
  }) async {
    final db = await init();
    final where = _contactsListWhere(filter: filter, query: query);
    final rows = await db.query(
      'contacts',
      where: where.clause,
      whereArgs: where.args.isEmpty ? null : where.args,
      orderBy: 'source_row ASC, id ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(ContactRecord.fromMap).toList();
  }

  _SqlWhere _contactsListWhere({
    required ContactListFilter filter,
    required String query,
  }) {
    final clauses = <String>[];
    final args = <Object?>[];

    switch (filter) {
      case ContactListFilter.all:
        break;
      case ContactListFilter.valid:
        clauses.add('is_valid_phone = 1');
        break;
      case ContactListFilter.invalid:
        clauses.add('is_valid_phone = 0');
        break;
      case ContactListFilter.duplicate:
        clauses.add('is_duplicate = 1');
        break;
      case ContactListFilter.pending:
        clauses.add('status = ?');
        args.add(ContactStatus.pending.name);
        break;
      case ContactListFilter.sent:
        clauses.add('status = ?');
        args.add(ContactStatus.sent.name);
        break;
      case ContactListFilter.failed:
        clauses.add('status = ?');
        args.add(ContactStatus.failed.name);
        break;
    }

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      final like = '%${_escapeLike(normalizedQuery)}%';
      clauses.add('''
(
  LOWER(phone) LIKE ? ESCAPE '\\' OR
  LOWER(raw_phone) LIKE ? ESCAPE '\\' OR
  LOWER(full_name) LIKE ? ESCAPE '\\' OR
  LOWER(first_name) LIKE ? ESCAPE '\\' OR
  LOWER(last_name) LIKE ? ESCAPE '\\' OR
  LOWER(token) LIKE ? ESCAPE '\\'
)
''');
      args.addAll(List.filled(6, like));
    }

    return _SqlWhere(
      clause: clauses.isEmpty ? null : clauses.join(' AND '),
      args: args,
    );
  }

  String _escapeLike(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  Future<Set<int>> getSelectedContactIds() async {
    final db = await init();
    final rows = await db.query(
      'contacts',
      columns: ['id'],
      where: 'is_selected = 1',
      orderBy: 'source_row ASC, id ASC',
    );
    return rows.map((row) => row['id']).whereType<int>().toSet();
  }

  Future<int> getSelectedContactsCount() async {
    final db = await init();
    return Sqflite.firstIntValue(
          await db
              .rawQuery('SELECT COUNT(*) FROM contacts WHERE is_selected = 1'),
        ) ??
        0;
  }

  Future<void> setContactSelected(int id, bool selected) async {
    final db = await init();
    await db.update(
      'contacts',
      {
        'is_selected': selected ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearSelectedContacts() async {
    final db = await init();
    await db.update(
      'contacts',
      {
        'is_selected': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<List<ContactRecord>> getContactsByIds(Set<int> ids) async {
    if (ids.isEmpty) return const [];
    final db = await init();
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.query(
      'contacts',
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(),
      orderBy: 'source_row ASC, id ASC',
    );
    return rows.map(ContactRecord.fromMap).toList();
  }

  Future<List<ContactRecord>> getSelectedContacts({
    bool onlyPendingOrFailed = false,
  }) async {
    final db = await init();
    final rows = await db.query(
      'contacts',
      where: 'is_selected = 1',
      orderBy: 'source_row ASC, id ASC',
    );
    final contacts = rows.map(ContactRecord.fromMap).toList();
    return _filterEligibleContacts(
      contacts,
      onlyPendingOrFailed: onlyPendingOrFailed,
    );
  }

  Future<List<ContactRecord>> getEligibleContacts({
    bool onlyPendingOrFailed = true,
    int? limit,
  }) async {
    final db = await init();
    final settings = await getSettings();
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (onlyPendingOrFailed) {
      whereClauses.add('status IN (?, ?)');
      whereArgs.addAll([
        ContactStatus.pending.name,
        ContactStatus.failed.name,
      ]);
    }
    if (settings.skipInvalid) {
      whereClauses.add('is_valid_phone = 1');
    }
    if (settings.skipDuplicates) {
      whereClauses.add('is_duplicate = 0');
    }

    final rows = await db.query(
      'contacts',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'source_row ASC, id ASC',
      limit: limit,
    );
    return rows.map(ContactRecord.fromMap).toList();
  }

  Future<List<ContactRecord>> getPendingOrFailedContacts() async {
    final db = await init();
    final rows = await db.query(
      'contacts',
      where: 'status IN (?, ?)',
      whereArgs: [
        ContactStatus.pending.name,
        ContactStatus.failed.name,
      ],
      orderBy: 'source_row ASC, id ASC',
    );
    return rows.map(ContactRecord.fromMap).toList();
  }

  Future<List<ContactRecord>> _filterEligibleContacts(
    List<ContactRecord> contacts, {
    required bool onlyPendingOrFailed,
  }) async {
    final settings = await getSettings();
    return contacts.where((contact) {
      if (settings.skipInvalid && !contact.isValidPhone) return false;
      if (settings.skipDuplicates && contact.isDuplicate) return false;
      if (onlyPendingOrFailed && !contact.canBePreparedForSending) return false;
      return true;
    }).toList();
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
    await db.transaction((txn) async {
      await txn.update('contacts', {'is_selected': 0});
      await txn.delete('contacts');
    });
  }

  Future<Map<String, int>> getStats() async {
    final db = await init();
    final rows = await db.rawQuery(
      '''
SELECT
  COUNT(*) AS total,
  SUM(CASE WHEN is_valid_phone = 1 THEN 1 ELSE 0 END) AS valid,
  SUM(CASE WHEN is_valid_phone = 0 THEN 1 ELSE 0 END) AS invalid,
  SUM(CASE WHEN is_duplicate = 1 THEN 1 ELSE 0 END) AS duplicates,
  SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) AS pending,
  SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) AS sent,
  SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) AS failed,
  SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) AS invalid_status,
  SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) AS duplicate_status,
  SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) AS skipped
FROM contacts
''',
      ContactStatus.values.map((status) => status.name).toList(),
    );
    final row = rows.isEmpty ? const <String, Object?>{} : rows.first;
    final stats = <String, int>{
      'total': _aggregateInt(row['total']),
      'valid': _aggregateInt(row['valid']),
      'invalid': _aggregateInt(row['invalid']),
      'duplicates': _aggregateInt(row['duplicates']),
      ContactStatus.pending.name: _aggregateInt(row['pending']),
      ContactStatus.sent.name: _aggregateInt(row['sent']),
      ContactStatus.failed.name: _aggregateInt(row['failed']),
      ContactStatus.invalid.name: _aggregateInt(row['invalid_status']),
      ContactStatus.duplicate.name: _aggregateInt(row['duplicate_status']),
      ContactStatus.skipped.name: _aggregateInt(row['skipped']),
    };
    return stats;
  }

  int _aggregateInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Future<AppSettings> getSettings() async {
    final db = await init();
    final rows = await db.query('app_settings', where: 'id = 1', limit: 1);
    return rows.isEmpty
        ? AppSettings.defaults()
        : AppSettings.fromMap(rows.first);
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

class _SqlWhere {
  const _SqlWhere({required this.clause, required this.args});

  final String? clause;
  final List<Object?> args;
}
