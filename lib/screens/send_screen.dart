import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/contact_record.dart';
import '../services/local_db_service.dart';
import '../services/sms_service.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  List<ContactRecord> _preparedQueue = const [];
  String _currentRecipient = 'هنوز شروع نشده';
  String _lastError = '—';
  String _capabilitySummary = 'هنوز بررسی نشده';
  int _sentCount = 0;
  int _failedCount = 0;
  int _processedCount = 0;
  bool _loading = false;

  Future<void> _sendTestToTwoContacts() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _lastError = '—';
      _sentCount = 0;
      _failedCount = 0;
      _processedCount = 0;
      _currentRecipient = 'در حال آماده‌سازی';
    });

    final db = LocalDbService.instance;
    final settings = await db.getSettings();
    final contacts = await db.getEligibleContacts(onlyPendingOrFailed: true, limit: 2);
    if (!mounted) return;
    setState(() {
      _preparedQueue = contacts;
      _currentRecipient = contacts.isEmpty ? 'مخاطب واجد شرایطی وجود ندارد' : contacts.first.displayNameOrPhone;
    });
    if (contacts.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final permission = await SmsService.requestSmsPermission();
    if (permission != SmsPermissionState.granted) {
      final error = permission == SmsPermissionState.permanentlyDenied
          ? 'SMS permission permanently denied'
          : 'permission denied';
      await _markContactsFailed(contacts, error);
      _finishWithError(error);
      return;
    }

    SmsCapabilityInfo capability;
    try {
      capability = await SmsService.requestSmsCapabilityInfo();
    } catch (error) {
      await _markContactsFailed(contacts, 'unknown error: $error');
      _finishWithError('unknown error: $error');
      return;
    }
    if (!mounted) return;
    setState(() => _capabilitySummary = capability.persianSummary);
    if (!capability.hasSmsFeature) {
      await _markContactsFailed(contacts, 'device does not support SMS');
      _finishWithError('device does not support SMS');
      return;
    }
    if (!capability.defaultSmsAvailable) {
      await _markContactsFailed(contacts, 'no SIM if detected');
      _finishWithError('no SIM if detected');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأیید نهایی ارسال تست'),
        content: Text(
          'ارسال فقط برای ${contacts.length} مخاطب اول انجام می‌شود و برنامه باید باز بماند.\n\n'
          '${capability.persianSummary}\n\n'
          'محدودیت: انتخاب سیم‌کارت در این نسخه پیاده‌سازی نشده است.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ارسال')),
        ],
      ),
    );
    if (confirmed != true) {
      setState(() {
        _loading = false;
        _currentRecipient = 'ارسال لغو شد';
      });
      return;
    }

    for (var i = 0; i < contacts.length; i++) {
      final contact = contacts[i];
      if (!mounted) return;
      setState(() => _currentRecipient = contact.displayNameOrPhone);
      final validationError = _validateContact(contact);
      if (validationError != null) {
        await _recordFailure(contact, validationError);
      } else {
        try {
          final result = await SmsService.sendSms(
            phone: contact.phone,
            message: contact.message,
            subscriptionId: settings.selectedSubscriptionId,
          );
          if (result.success) {
            await db.updateContactStatus(contact.id!, ContactStatus.sent, sentAt: DateTime.now());
            if (!mounted) return;
            setState(() {
              _sentCount++;
              _processedCount++;
            });
          } else {
            await _recordFailure(contact, result.message ?? 'native send failure');
          }
        } on PlatformException catch (error) {
          await _recordFailure(contact, _nativeErrorText(error));
        } catch (error) {
          await _recordFailure(contact, 'unknown error: $error');
        }
      }
      if (i < contacts.length - 1 && settings.delaySeconds > 0) {
        await Future<void>.delayed(Duration(seconds: settings.delaySeconds));
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _currentRecipient = 'پایان ارسال تست';
    });
  }

  String? _validateContact(ContactRecord contact) {
    if (contact.id == null) return 'unknown error: missing contact id';
    if (contact.phone.trim().isEmpty || !contact.isValidPhone) return 'invalid phone';
    if (contact.message.trim().isEmpty) return 'empty message';
    return null;
  }

  String _nativeErrorText(PlatformException error) {
    return switch (error.code) {
      'INVALID_PHONE' => 'invalid phone',
      'EMPTY_MESSAGE' => 'empty message',
      'PERMISSION_DENIED' => 'permission denied',
      'NO_SMS_FEATURE' => 'device does not support SMS',
      'NO_DEFAULT_SMS' => 'no SIM if detected',
      'NATIVE_SEND_FAILURE' => 'native send failure: ${error.message ?? ''}'.trim(),
      _ => 'unknown error: ${error.message ?? error.code}',
    };
  }

  Future<void> _recordFailure(ContactRecord contact, String error) async {
    if (contact.id != null) {
      await LocalDbService.instance.updateContactStatus(contact.id!, ContactStatus.failed, error: error);
    }
    if (!mounted) return;
    setState(() {
      _failedCount++;
      _processedCount++;
      _lastError = error;
    });
  }

  Future<void> _markContactsFailed(List<ContactRecord> contacts, String error) async {
    for (final contact in contacts) {
      if (contact.id != null) {
        await LocalDbService.instance.updateContactStatus(contact.id!, ContactStatus.failed, error: error);
      }
    }
  }

  void _finishWithError(String error) {
    if (!mounted) return;
    setState(() {
      _lastError = error;
      _failedCount = _preparedQueue.length;
      _processedCount = _preparedQueue.length;
      _currentRecipient = 'ارسال انجام نشد';
      _loading = false;
    });
  }

  void _notActiveYet() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('این نوع ارسال هنوز پیاده‌سازی نشده است. فقط ارسال تست به ۲ مخاطب فعال است.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _preparedQueue.length;
    final remainingCount = total - _processedCount;
    return Scaffold(
      appBar: AppBar(title: const Text('ارسال')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'ارسال مستقیم فقط با اقدام آشکار کاربر، هنگام باز بودن برنامه، و فعلاً فقط برای تست ۲ مخاطب انجام می‌شود. '
                'انتخاب سیم‌کارت در این نسخه پیاده‌سازی نشده است.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: total == 0 ? 0 : _processedCount / total),
          const SizedBox(height: 12),
          _InfoRow(label: 'گیرنده فعلی', value: _currentRecipient),
          _InfoRow(label: 'پیشرفت', value: '$_processedCount / $total'),
          _InfoRow(label: 'آخرین خطا', value: _lastError),
          _InfoRow(label: 'ارسال‌شده', value: '$_sentCount'),
          _InfoRow(label: 'ناموفق', value: '$_failedCount'),
          _InfoRow(label: 'باقی‌مانده', value: '${remainingCount < 0 ? 0 : remainingCount}'),
          _InfoRow(label: 'قابلیت پیامک', value: _capabilitySummary),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _sendTestToTwoContacts,
            child: Text(_loading ? 'در حال ارسال...' : 'ارسال تست به ۲ مخاطب'),
          ),
          FilledButton(onPressed: _loading ? null : _notActiveYet, child: const Text('ارسال ۱۰ مخاطب بعدی')),
          FilledButton(onPressed: _loading ? null : _notActiveYet, child: const Text('ارسال ۵۰ مخاطب بعدی')),
          FilledButton(onPressed: _loading ? null : _notActiveYet, child: const Text('ارسال مخاطبین انتخاب‌شده')),
          FilledButton.tonal(onPressed: _loading ? null : _notActiveYet, child: const Text('ارسال همه ارسال‌نشده‌ها')),
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
