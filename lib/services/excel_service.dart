import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/app_settings.dart';
import '../models/contact_record.dart';
import 'phone_normalizer_service.dart';
import 'sms_part_estimator.dart';
import 'token_service.dart';

class ExcelImportData {
  const ExcelImportData({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  factory ExcelImportData.fromMap(Map<String, Object?> map) {
    return ExcelImportData(
      headers: (map['headers'] as List).cast<String>(),
      rows: (map['rows'] as List)
          .map((row) => (row as List).cast<String>())
          .toList(),
    );
  }

  Map<String, Object?> toMap() => {
        'headers': headers,
        'rows': rows,
      };
}

class ExcelColumnMapping {
  const ExcelColumnMapping({
    required this.phoneIndex,
    this.firstNameIndex,
    this.lastNameIndex,
    this.fullNameIndex,
  });

  final int? phoneIndex;
  final int? firstNameIndex;
  final int? lastNameIndex;
  final int? fullNameIndex;

  bool get hasRequiredPhone => phoneIndex != null;

  factory ExcelColumnMapping.fromMap(Map<String, Object?> map) {
    return ExcelColumnMapping(
      phoneIndex: map['phoneIndex'] as int?,
      firstNameIndex: map['firstNameIndex'] as int?,
      lastNameIndex: map['lastNameIndex'] as int?,
      fullNameIndex: map['fullNameIndex'] as int?,
    );
  }

  Map<String, Object?> toMap() => {
        'phoneIndex': phoneIndex,
        'firstNameIndex': firstNameIndex,
        'lastNameIndex': lastNameIndex,
        'fullNameIndex': fullNameIndex,
      };
}

class ImportSummary {
  const ImportSummary({
    required this.totalRows,
    required this.validPhones,
    required this.invalidPhones,
    required this.duplicates,
    required this.pending,
  });

  final int totalRows;
  final int validPhones;
  final int invalidPhones;
  final int duplicates;
  final int pending;

  factory ImportSummary.fromContacts(List<ContactRecord> contacts) {
    return ImportSummary(
      totalRows: contacts.length,
      validPhones: contacts.where((contact) => contact.isValidPhone).length,
      invalidPhones: contacts.where((contact) => !contact.isValidPhone).length,
      duplicates: contacts.where((contact) => contact.isDuplicate).length,
      pending: contacts
          .where((contact) => contact.status == ContactStatus.pending)
          .length,
    );
  }
}

Map<String, Object?> readFirstWorksheetInIsolate(Uint8List bytes) {
  return ExcelService().readFirstWorksheet(bytes).toMap();
}

List<Map<String, Object?>> buildContactsInIsolate(
    Map<dynamic, dynamic> message) {
  final data = ExcelImportData.fromMap(
      Map<String, Object?>.from(message['data'] as Map));
  final mapping = ExcelColumnMapping.fromMap(
    Map<String, Object?>.from(message['mapping'] as Map),
  );
  final settings = AppSettings.fromMap(
    Map<String, Object?>.from(message['settings'] as Map),
  );

  return ExcelService()
      .buildContacts(data: data, mapping: mapping, settings: settings)
      .map((contact) => contact.toMap())
      .toList();
}

class ExcelService {
  ExcelService({
    PhoneNormalizerService? phoneNormalizer,
    TokenService? tokenService,
    SmsPartEstimator? smsPartEstimator,
  })  : _phoneNormalizer = phoneNormalizer ?? PhoneNormalizerService(),
        _tokenService = tokenService ?? TokenService(),
        _smsPartEstimator = smsPartEstimator ?? SmsPartEstimator();

  final PhoneNormalizerService _phoneNormalizer;
  final TokenService _tokenService;
  final SmsPartEstimator _smsPartEstimator;

  static const _phoneHeaders = {
    'موبایل',
    'شماره موبایل',
    'شماره همراه',
    'تلفن همراه',
    'mobile',
    'phone',
    'cellphone',
  };
  static const _firstNameHeaders = {'نام', 'first_name', 'firstname', 'name'};
  static const _lastNameHeaders = {
    'نام خانوادگی',
    'نام‌خانوادگی',
    'فامیلی',
    'family',
    'last_name',
    'lastname',
    'surname',
  };
  static const _fullNameHeaders = {
    'نام و نام خانوادگی',
    'نام کامل',
    'fullname',
    'full_name',
  };

  ExcelImportData readFirstWorksheet(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      throw const FormatException('فایل اکسل هیچ کاربرگی ندارد.');
    }
    final sheet = workbook.tables.values.first;
    if (sheet.rows.isEmpty) {
      throw const FormatException('کاربرگ اول خالی است.');
    }
    final headers = sheet.rows.first.map(_cellToText).toList();
    final rows = sheet.rows.skip(1).map((row) {
      return List<String>.generate(headers.length, (index) {
        if (index >= row.length) return '';
        return _cellToText(row[index]);
      });
    }).toList();
    return ExcelImportData(headers: headers, rows: rows);
  }

  ExcelColumnMapping detectMapping(List<String> headers) {
    int? find(Set<String> candidates) {
      for (var i = 0; i < headers.length; i++) {
        if (candidates
            .map(normalizeHeader)
            .contains(normalizeHeader(headers[i]))) {
          return i;
        }
      }
      return null;
    }

    return ExcelColumnMapping(
      phoneIndex: find(_phoneHeaders),
      firstNameIndex: find(_firstNameHeaders),
      lastNameIndex: find(_lastNameHeaders),
      fullNameIndex: find(_fullNameHeaders),
    );
  }

  List<ContactRecord> buildContacts({
    required ExcelImportData data,
    required ExcelColumnMapping mapping,
    required AppSettings settings,
  }) {
    if (!mapping.hasRequiredPhone) {
      throw ArgumentError('ستون موبایل الزامی است.');
    }

    final seenPhones = <String>{};
    final now = DateTime.now();
    return data.rows.asMap().entries.map((entry) {
      final row = entry.value;
      final rawPhone = _valueAt(row, mapping.phoneIndex);
      final phone = _phoneNormalizer.normalize(rawPhone);
      final isValidPhone = _phoneNormalizer.isValid(rawPhone);
      final isDuplicate =
          isValidPhone && phone.isNotEmpty && !seenPhones.add(phone);
      final status = !isValidPhone
          ? ContactStatus.invalid
          : isDuplicate
              ? ContactStatus.duplicate
              : ContactStatus.pending;
      final firstName = _valueAt(row, mapping.firstNameIndex);
      final lastName = _valueAt(row, mapping.lastNameIndex);
      final fullName = _valueAt(row, mapping.fullNameIndex);
      final token = _tokenService.buildToken(
        fullName: fullName,
        firstName: firstName,
        lastName: lastName,
      );
      final message = settings.smsTemplate.replaceAll('{token}', token);
      return ContactRecord(
        sourceRow: entry.key + 2,
        firstName: firstName,
        lastName: lastName,
        fullName: fullName,
        token: token,
        phone: phone,
        rawPhone: rawPhone,
        message: message,
        isValidPhone: isValidPhone,
        isDuplicate: isDuplicate,
        status: status,
        smsPartCount: _smsPartEstimator.estimate(message),
        createdAt: now,
        updatedAt: now,
      );
    }).toList();
  }

  String normalizeHeader(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'[\u200c\s]+'), ' ')
        .replaceAll(RegExp(r'[_\-]+'), '_')
        .trim();
  }

  static String _valueAt(List<String> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return '';
    return row[index].trim();
  }

  static String _cellToText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    Object? raw;
    try {
      raw = (value as dynamic).value as Object?;
    } catch (_) {
      raw = value;
    }
    return (raw ?? value).toString().trim();
  }
}
