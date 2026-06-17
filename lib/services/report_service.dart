import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/contact_record.dart';
import 'local_db_service.dart';

class ReportExportResult {
  const ReportExportResult({required this.path, required this.rows});
  final String path;
  final int rows;
}

class ReportService {
  ReportService({LocalDbService? db}) : _db = db ?? LocalDbService.instance;
  final LocalDbService _db;

  Future<ReportExportResult> exportXlsx() async {
    final contacts = await _db.getAllContacts();
    final excel = Excel.createExcel();
    final sheet = excel['گزارش ارسال'];
    excel.setDefaultSheet('گزارش ارسال');
    sheet.appendRow(_headers.map(TextCellValue.new).toList());
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm:ss');
    for (final contact in contacts) {
      sheet.appendRow([
        IntCellValue(contact.sourceRow),
        TextCellValue(contact.firstName),
        TextCellValue(contact.lastName),
        TextCellValue(contact.fullName),
        TextCellValue(contact.token),
        TextCellValue(contact.phone),
        TextCellValue(contact.rawPhone),
        TextCellValue(contact.message),
        IntCellValue(contact.smsPartCount),
        TextCellValue(_statusLabel(contact.status)),
        TextCellValue(contact.error ?? ''),
        TextCellValue(contact.isDuplicate ? 'بله' : 'خیر'),
        TextCellValue(contact.isValidPhone ? 'بله' : 'خیر'),
        TextCellValue(contact.sentAt == null ? '' : dateFormat.format(contact.sentAt!)),
        TextCellValue(contact.deliveredAt == null ? '' : dateFormat.format(contact.deliveredAt!)),
      ]);
    }
    final bytes = excel.encode() ?? <int>[];
    final dir = await _exportDirectory();
    final fileName = 'sms_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return ReportExportResult(path: file.path, rows: contacts.length);
  }

  Future<OpenResult> open(String path) => OpenFilex.open(path);

  Future<Directory> _exportDirectory() async {
    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) return downloads;
    }
    return getApplicationDocumentsDirectory();
  }

  static const _headers = [
    'ردیف', 'نام', 'نام خانوادگی', 'نام کامل', 'توکن', 'موبایل', 'شماره خام', 'متن پیام',
    'تعداد بخش پیامک', 'وضعیت', 'خطا', 'تکراری', 'شماره معتبر', 'زمان ارسال', 'زمان تحویل اگر موجود بود',
  ];

  String _statusLabel(ContactStatus status) => switch (status) {
        ContactStatus.pending => 'در انتظار', ContactStatus.sent => 'ارسال‌شده', ContactStatus.failed => 'ناموفق',
        ContactStatus.invalid => 'نامعتبر', ContactStatus.duplicate => 'تکراری', ContactStatus.skipped => 'ردشده',
      };
}
