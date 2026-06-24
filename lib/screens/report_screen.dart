import 'package:flutter/material.dart';

import '../services/report_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _service = ReportService();
  bool _exporting = false;
  ReportExportResult? _lastExport;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final result = await _service.exportXlsx();
      if (!mounted) return;
      setState(() => _lastExport = result);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('گزارش ${result.rows} ردیف صادر شد.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطا در خروجی گزارش: $error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _open() async {
    final path = _lastExport?.path;
    if (path == null) return;
    await _service.open(path);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('گزارش')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'خروجی اکسل شامل همه ردیف‌هاست؛ حتی شماره‌های نامعتبر و تکراری هم در گزارش باقی می‌مانند.'))),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _exporting ? null : _export,
              icon: const Icon(Icons.file_download),
              label: Text(_exporting ? 'در حال ساخت...' : 'خروجی Excel')),
          if (_lastExport != null) ...[
            const SizedBox(height: 16),
            SelectableText(_lastExport!.path),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.open_in_new),
                label: const Text('باز کردن فایل')),
          ],
        ]),
      );
}
