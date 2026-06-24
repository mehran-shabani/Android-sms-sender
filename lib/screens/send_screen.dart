import 'package:flutter/material.dart';

import '../services/send_queue_service.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});
  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _queue = SendQueueService.instance;

  @override
  void initState() {
    super.initState();
    _queue.addListener(_onQueueChanged);
  }

  @override
  void dispose() {
    _queue.removeListener(_onQueueChanged);
    super.dispose();
  }

  void _onQueueChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _start(SendQueueMode mode) async {
    final count = (await _queue.prepareQueue(mode)).length;
    if (!mounted) return;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مخاطب واجد شرایطی وجود ندارد.')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأیید ارسال پیامک'),
        content: Text(
          'ارسال برای $count مخاطب آماده است. برنامه باید باز بماند و ارسال فقط با تأیید شما شروع می‌شود.\n\n'
          'هشدار اپراتور: ارسال پیام‌های مشابه یا پرتعداد ممکن است توسط اپراتور مسدود، محدود یا مشمول هزینه شود. فاصله بین پیامک‌ها رعایت می‌شود.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('شروع ارسال')),
        ],
      ),
    );
    if (confirmed != true) return;
    final summary = await _queue.start(mode);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(summary.stopped ? 'ارسال متوقف شد' : 'ارسال کامل شد'),
        content: Text(
            'ارسال‌شده: ${summary.sent}\nناموفق: ${summary.failed}\nردشده: ${summary.skipped}\nوضعیت: ${summary.stopped ? 'متوقف‌شده' : 'کامل‌شده'}'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('باشه'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final running = _queue.state == SendQueueState.running;
    final paused = _queue.state == SendQueueState.paused;
    final active = _queue.isActive;
    return Scaffold(
      appBar: AppBar(title: const Text('ارسال')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'ارسال پیامک بدون بک‌اند و بدون API اینترنتی انجام می‌شود. ارسال مخفی یا پس‌زمینه وجود ندارد؛ کاربر باید شروع ارسال را تأیید کند و برنامه هنگام ارسال باز بماند.'))),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _queue.progress),
          const SizedBox(height: 12),
          _InfoRow(label: 'گیرنده فعلی', value: _queue.currentRecipient),
          _InfoRow(
              label: 'پیشرفت',
              value: '${_queue.processedCount} / ${_queue.totalCount}'),
          _InfoRow(label: 'آخرین خطا', value: _queue.lastError),
          _InfoRow(label: 'ارسال‌شده', value: '${_queue.sentCount}'),
          _InfoRow(label: 'ناموفق', value: '${_queue.failedCount}'),
          _InfoRow(label: 'ردشده', value: '${_queue.skippedCount}'),
          _InfoRow(label: 'باقی‌مانده', value: '${_queue.remainingCount}'),
          _InfoRow(label: 'قابلیت پیامک', value: _queue.capabilitySummary),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(
                onPressed: active ? null : () => _start(SendQueueMode.testTwo),
                child: const Text('ارسال تست به ۲ مخاطب')),
            FilledButton(
                onPressed: active ? null : () => _start(SendQueueMode.nextTen),
                child: const Text('ارسال ۱۰ مخاطب بعدی')),
            FilledButton(
                onPressed:
                    active ? null : () => _start(SendQueueMode.nextFifty),
                child: const Text('ارسال ۵۰ مخاطب بعدی')),
            FilledButton(
                onPressed: active ? null : () => _start(SendQueueMode.selected),
                child: const Text('ارسال مخاطبین انتخاب‌شده')),
            FilledButton.tonal(
                onPressed:
                    active ? null : () => _start(SendQueueMode.allUnsent),
                child: const Text('ارسال همه ارسال‌نشده‌ها')),
          ]),
          const Divider(height: 32),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: running ? _queue.pause : null,
                    child: const Text('توقف موقت'))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton(
                    onPressed: paused ? _queue.resume : null,
                    child: const Text('ادامه'))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton(
                    onPressed: active ? _queue.stop : null,
                    child: const Text('توقف کامل'))),
          ]),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value))
        ]),
      );
}
