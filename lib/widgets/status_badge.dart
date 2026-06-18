import 'package:flutter/material.dart';

import '../models/contact_record.dart';
import '../theme/brand_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ContactStatus status;

  @override
  Widget build(BuildContext context) {
    final data = _statusData(status);
    return Chip(
      label: Text(data.label),
      avatar: Icon(data.icon, size: 18, color: data.color),
      side: BorderSide(color: data.color.withValues(alpha: 0.4)),
      backgroundColor: data.color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: data.color, fontWeight: FontWeight.w600),
    );
  }

  _BadgeData _statusData(ContactStatus status) {
    return switch (status) {
      ContactStatus.pending =>
        const _BadgeData('در انتظار', Icons.schedule, BrandColors.orange),
      ContactStatus.sent =>
        const _BadgeData('ارسال‌شده', Icons.check_circle, Color(0xFF2E7D32)),
      ContactStatus.failed =>
        const _BadgeData('ناموفق', Icons.error, BrandColors.red),
      ContactStatus.invalid =>
        const _BadgeData('نامعتبر', Icons.warning, BrandColors.amber),
      ContactStatus.duplicate =>
        const _BadgeData('تکراری', Icons.copy, BrandColors.deepRed),
      ContactStatus.skipped =>
        const _BadgeData('ردشده', Icons.skip_next, Color(0xFF6D4C41)),
    };
  }
}

class _BadgeData {
  const _BadgeData(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}
