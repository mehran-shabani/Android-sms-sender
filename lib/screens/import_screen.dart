import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/contact_record.dart';
import '../services/excel_service.dart';
import '../services/local_db_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _excelService = ExcelService();
  ExcelImportData? _data;
  ExcelColumnMapping? _mapping;
  ImportSummary? _summary;
  String? _fileName;
  bool _loading = false;
  String? _error;

  Future<void> _pickFile() async {
    setState(() {
      _loading = true;
      _error = null;
      _summary = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        withData: true,
      );
      if (!mounted) return;
      if (result == null || result.files.single.bytes == null) return;
      final dataMap = await compute(
        readFirstWorksheetInIsolate,
        result.files.single.bytes!,
      );
      if (!mounted) return;
      final data = ExcelImportData.fromMap(Map<String, Object?>.from(dataMap));
      final mapping = _excelService.detectMapping(data.headers);
      setState(() {
        _data = data;
        _mapping = mapping;
        _fileName = result.files.single.name;
      });
      if (mapping.hasRequiredPhone) {
        await _import(mapping);
        if (!mounted) return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import(ExcelColumnMapping mapping) async {
    final data = _data;
    if (data == null) return;
    if (!mapping.hasRequiredPhone) {
      setState(() => _error = 'ستون موبایل را انتخاب کنید.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await LocalDbService.instance.getSettings();
      if (!mounted) return;
      final contactMaps = await compute(buildContactsInIsolate, {
        'data': data.toMap(),
        'mapping': mapping.toMap(),
        'settings': settings.toMap(),
      });
      if (!mounted) return;
      final contacts = contactMaps
          .map(
              (m) => ContactRecord.fromMap(Map<String, Object?>.from(m as Map)))
          .toList();
      await LocalDbService.instance.clearContacts();
      if (!mounted) return;
      await LocalDbService.instance.insertContacts(contacts);
      if (!mounted) return;
      setState(() {
        _mapping = mapping;
        _summary = ImportSummary.fromContacts(contacts);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مخاطبین از فایل اکسل ذخیره شدند')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsManualMapping = _data != null &&
        !(_mapping?.hasRequiredPhone ?? false) &&
        _summary == null;
    return Scaffold(
      appBar: AppBar(title: const Text('ورود از اکسل')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      'فایل .xlsx را انتخاب کنید. ردیف اول به عنوان سرستون خوانده می‌شود.',
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_fileName == null
                        ? 'انتخاب فایل اکسل'
                        : 'انتخاب فایل دیگر'),
                  ),
                  if (_fileName != null) ...[
                    const SizedBox(height: 8),
                    Text('فایل انتخاب‌شده: $_fileName'),
                  ],
                ],
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer)),
              ),
            ),
          if (needsManualMapping)
            _ManualMappingCard(
              headers: _data!.headers,
              initialMapping: _mapping!,
              onConfirm: _import,
            ),
          if (_summary != null) _SummaryCard(summary: _summary!),
        ],
      ),
    );
  }
}

class _ManualMappingCard extends StatefulWidget {
  const _ManualMappingCard(
      {required this.headers,
      required this.initialMapping,
      required this.onConfirm});

  final List<String> headers;
  final ExcelColumnMapping initialMapping;
  final ValueChanged<ExcelColumnMapping> onConfirm;

  @override
  State<_ManualMappingCard> createState() => _ManualMappingCardState();
}

class _ManualMappingCardState extends State<_ManualMappingCard> {
  int? phoneIndex;
  int? firstNameIndex;
  int? lastNameIndex;
  int? fullNameIndex;

  @override
  void initState() {
    super.initState();
    phoneIndex = widget.initialMapping.phoneIndex;
    firstNameIndex = widget.initialMapping.firstNameIndex;
    lastNameIndex = widget.initialMapping.lastNameIndex;
    fullNameIndex = widget.initialMapping.fullNameIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                'تشخیص خودکار ستون موبایل انجام نشد. ستون‌ها را دستی انتخاب کنید.',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _ColumnDropdown(
                label: 'ستون موبایل (الزامی)',
                headers: widget.headers,
                value: phoneIndex,
                requiredField: true,
                onChanged: (value) => setState(() => phoneIndex = value)),
            _ColumnDropdown(
                label: 'ستون نام (اختیاری)',
                headers: widget.headers,
                value: firstNameIndex,
                onChanged: (value) => setState(() => firstNameIndex = value)),
            _ColumnDropdown(
                label: 'ستون نام خانوادگی (اختیاری)',
                headers: widget.headers,
                value: lastNameIndex,
                onChanged: (value) => setState(() => lastNameIndex = value)),
            _ColumnDropdown(
                label: 'ستون نام کامل (اختیاری)',
                headers: widget.headers,
                value: fullNameIndex,
                onChanged: (value) => setState(() => fullNameIndex = value)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: phoneIndex == null
                  ? null
                  : () => widget.onConfirm(ExcelColumnMapping(
                        phoneIndex: phoneIndex,
                        firstNameIndex: firstNameIndex,
                        lastNameIndex: lastNameIndex,
                        fullNameIndex: fullNameIndex,
                      )),
              icon: const Icon(Icons.check),
              label: const Text('تأیید و ورود مخاطبین'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnDropdown extends StatelessWidget {
  const _ColumnDropdown(
      {required this.label,
      required this.headers,
      required this.value,
      required this.onChanged,
      this.requiredField = false});

  final String label;
  final List<String> headers;
  final int? value;
  final bool requiredField;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int?>(
        initialValue: value,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: [
          if (!requiredField)
            const DropdownMenuItem<int?>(
                value: null, child: Text('انتخاب نشده')),
          ...headers.asMap().entries.map((entry) => DropdownMenuItem<int?>(
                value: entry.key,
                child: Text(
                    '${entry.key + 1}. ${entry.value.isEmpty ? 'بدون عنوان' : entry.value}'),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ImportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('خلاصه ورود', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            _row('کل ردیف‌های واردشده', summary.totalRows),
            _row('شماره‌های معتبر', summary.validPhones),
            _row('شماره‌های نامعتبر', summary.invalidPhones),
            _row('تکراری‌ها', summary.duplicates),
            _row('در انتظار', summary.pending),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text('$value')]),
      );
}
