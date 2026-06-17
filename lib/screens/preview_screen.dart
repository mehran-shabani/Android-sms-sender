import 'package:flutter/material.dart';

import '../models/contact_record.dart';
import '../services/local_db_service.dart';
import '../services/sms_part_estimator.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, this.selectedOnly = false});

  final bool selectedOnly;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late Future<_PreviewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PreviewData> _load() async {
    final db = LocalDbService.instance;
    final contacts = widget.selectedOnly
        ? await db.getSelectedContacts(onlyPendingOrFailed: false)
        : await db.getEligibleContacts(onlyPendingOrFailed: true);
    return _PreviewData.fromContacts(contacts);
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectedOnly ? 'پیش‌نمایش انتخاب‌شده‌ها' : 'پیش‌نمایش آماده ارسال'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<_PreviewData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? _PreviewData.empty();
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.contacts.length + 2,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return _SummaryCard(data: data);
                if (index == 1) return const _SafetyWarningCard();
                final contact = data.contacts[index - 2];
                return _PreviewContactCard(contact: contact);
              },
            ),
          );
        },
      ),
    );
  }
}

class _PreviewData {
  const _PreviewData({
    required this.contacts,
    required this.validCount,
    required this.invalidCount,
    required this.duplicateCount,
    required this.totalSmsParts,
  });

  final List<ContactRecord> contacts;
  final int validCount;
  final int invalidCount;
  final int duplicateCount;
  final int totalSmsParts;

  factory _PreviewData.fromContacts(List<ContactRecord> contacts) {
    final estimator = SmsPartEstimator();
    return _PreviewData(
      contacts: contacts,
      validCount: contacts.where((contact) => contact.isValidPhone).length,
      invalidCount: contacts.where((contact) => !contact.isValidPhone).length,
      duplicateCount: contacts.where((contact) => contact.isDuplicate).length,
      totalSmsParts: contacts.fold<int>(
        0,
        (sum, contact) => sum + estimator.estimate(contact.message),
      ),
    );
  }

  factory _PreviewData.empty() => const _PreviewData(
        contacts: [],
        validCount: 0,
        invalidCount: 0,
        duplicateCount: 0,
        totalSmsParts: 0,
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _PreviewData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryChip(label: 'تعداد انتخاب‌شده', value: data.contacts.length),
            _SummaryChip(label: 'معتبر', value: data.validCount),
            _SummaryChip(label: 'نامعتبر', value: data.invalidCount),
            _SummaryChip(label: 'تکراری', value: data.duplicateCount),
            _SummaryChip(label: 'کل بخش‌های پیامک', value: data.totalSmsParts),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _SafetyWarningCard extends StatelessWidget {
  const _SafetyWarningCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'پیامک فقط باید برای مخاطبین مجاز و شناخته‌شده ارسال شود.\n'
          'ارسال تعداد زیاد پیامک مشابه با سیم‌کارت شخصی ممکن است توسط اپراتور محدود شود.\n'
          'ارسال‌ها مخفی یا پس‌زمینه نیستند و فقط با تأیید دستی کاربر شروع می‌شوند.',
        ),
      ),
    );
  }
}

class _PreviewContactCard extends StatelessWidget {
  const _PreviewContactCard({required this.contact});

  final ContactRecord contact;

  @override
  Widget build(BuildContext context) {
    final displayName = contact.displayName;
    final parts = SmsPartEstimator().estimate(contact.message);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName.isEmpty ? 'بدون نام' : displayName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('شماره: ${contact.phone.isEmpty ? contact.rawPhone : contact.phone}'),
            Text('توکن: ${contact.token}'),
            Text('تعداد تقریبی بخش پیامک: $parts'),
            const Divider(height: 24),
            Text(contact.message),
          ],
        ),
      ),
    );
  }
}
