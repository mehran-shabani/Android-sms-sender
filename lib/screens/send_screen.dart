import 'package:flutter/material.dart';

import '../models/contact_record.dart';
import '../services/local_db_service.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  List<ContactRecord> _preparedQueue = const [];
  String _currentRecipient = 'هنوز شروع نشده';
  String _lastError = '—';
  int _sentCount = 0;
  bool _loading = false;

  Future<void> _prepareQueue({required String label, int? limit, bool selectedOnly = false}) async {
    setState(() => _loading = true);
    final contacts = selectedOnly
        ? await LocalDbService.instance.getSelectedContacts(onlyPendingOrFailed: true)
        : await LocalDbService.instance.getEligibleContacts(onlyPendingOrFailed: true, limit: limit);
    if (!mounted) return;
    setState(() {
      _preparedQueue = contacts;
      _currentRecipient = contacts.isEmpty ? 'مخاطب واجد شرایطی وجود ندارد' : contacts.first.displayNameOrPhone;
      _lastError = 'ارسال واقعی هنوز پیاده‌سازی نشده است.';
      _sentCount = 0;
      _loading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label: ${contacts.length} مخاطب برای صف آماده شد. ارسال واقعی انجام نشد.')),
    );
  }

  Future<void> _confirmAndPrepareAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأیید آماده‌سازی همه'),
        content: const Text(
          'همه مخاطبین ارسال‌نشده واجد شرایط فقط برای صف ارسال آماده می‌شوند. '
          'ارسال واقعی پیامک در این نسخه انجام نمی‌شود و در آینده نیز باید با تأیید دستی و قابل مشاهده کاربر آغاز شود.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأیید')),
        ],
      ),
    );
    if (confirmed == true) {
      await _prepareQueue(label: 'همه ارسال‌نشده‌ها');
    }
  }

  void _notActiveYet() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('کنترل صف هنوز فعال نیست و در کار بعدی پیاده‌سازی می‌شود.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingCount = _preparedQueue.length - _sentCount;
    return Scaffold(
      appBar: AppBar(title: const Text('ارسال')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'ارسال واقعی پیامک عمداً در این مرحله پیاده‌سازی نشده است. '
                'این صفحه فقط مخاطبین واجد شرایط را برای صف ارسال قابل مشاهده و تأییدشده آماده می‌کند.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _preparedQueue.isEmpty ? 0 : _sentCount / _preparedQueue.length),
          const SizedBox(height: 12),
          _InfoRow(label: 'گیرنده فعلی', value: _currentRecipient),
          _InfoRow(label: 'آخرین خطا', value: _lastError),
          _InfoRow(label: 'ارسال‌شده', value: '$_sentCount'),
          _InfoRow(label: 'باقی‌مانده', value: '${remainingCount < 0 ? 0 : remainingCount}'),
          const SizedBox(height: 16),
          FilledButton(onPressed: _loading ? null : () => _prepareQueue(label: 'ارسال تست به ۲ مخاطب', limit: 2), child: const Text('ارسال تست به ۲ مخاطب')),
          FilledButton(onPressed: _loading ? null : () => _prepareQueue(label: 'ارسال ۱۰ مخاطب بعدی', limit: 10), child: const Text('ارسال ۱۰ مخاطب بعدی')),
          FilledButton(onPressed: _loading ? null : () => _prepareQueue(label: 'ارسال ۵۰ مخاطب بعدی', limit: 50), child: const Text('ارسال ۵۰ مخاطب بعدی')),
          FilledButton(onPressed: _loading ? null : () => _prepareQueue(label: 'ارسال مخاطبین انتخاب‌شده', selectedOnly: true), child: const Text('ارسال مخاطبین انتخاب‌شده')),
          FilledButton.tonal(onPressed: _loading ? null : _confirmAndPrepareAll, child: const Text('ارسال همه ارسال‌نشده‌ها')),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: null, child: const Text('توقف موقت')),
              OutlinedButton(onPressed: null, child: const Text('ادامه')),
              OutlinedButton(onPressed: _notActiveYet, child: const Text('توقف')),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
