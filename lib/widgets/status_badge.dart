import 'package:flutter/material.dart';

import '../models/contact_record.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ContactStatus status;

  @override
  Widget build(BuildContext context) {
    final data = _statusData(status);
    return Chip(
      label: Text(data.label),
      avatar: Icon(data.icon, size: 18, color: data.color),
      side: BorderSide(color: data.color.withOpacity(0.4)),
      backgroundColor: data.color.withOpacity(0.1),
      labelStyle: TextStyle(color: data.color, fontWeight: FontWeight.w600),
    );
  }

  _BadgeData _statusData(ContactStatus status) {
    return switch (status) {
      ContactStatus.pending => const _BadgeData('در انتظار', Icons.schedule, Colors.blueGrey),
      ContactStatus.sent => const _BadgeData('ارسال‌شده', Icons.check_circle, Colors.green),
      ContactStatus.failed => const _BadgeData('ناموفق', Icons.error, Colors.red),
      ContactStatus.invalid => const _BadgeData('نامعتبر', Icons.warning, Colors.orange),
      ContactStatus.duplicate => const _BadgeData('تکراری', Icons.copy, Colors.purple),
      ContactStatus.skipped => const _BadgeData('ردشده', Icons.skip_next, Colors.grey),
    };
  }
}

class _BadgeData {
  const _BadgeData(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}
