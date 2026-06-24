import 'package:flutter/material.dart';

import '../services/local_db_service.dart';
import '../services/send_queue_service.dart';
import '../theme/brand_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, int>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = LocalDbService.instance.getStats();
    SendQueueService.instance.addListener(_refreshStats);
  }

  @override
  void dispose() {
    SendQueueService.instance.removeListener(_refreshStats);
    super.dispose();
  }

  void _refreshStats() {
    if (mounted) {
      setState(() => _statsFuture = LocalDbService.instance.getStats());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('داشبورد')),
      body: FutureBuilder<Map<String, int>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          final stats = snapshot.data ?? const <String, int>{};
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async => _refreshStats(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _BrandHeader(),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width >= 840
                        ? 4
                        : width >= 560
                            ? 3
                            : 2;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: width >= 560 ? 1.45 : 1.15,
                      children: [
                        _StatCard(
                          label: 'کل مخاطبین',
                          value: stats['total'] ?? 0,
                          icon: Icons.groups,
                          color: BrandColors.red,
                        ),
                        _StatCard(
                          label: 'معتبر',
                          value: stats['valid'] ?? 0,
                          icon: Icons.verified,
                          color: const Color(0xFF188038),
                        ),
                        _StatCard(
                          label: 'نامعتبر',
                          value: stats['invalid'] ?? 0,
                          icon: Icons.warning,
                          color: BrandColors.amber,
                        ),
                        _StatCard(
                          label: 'تکراری',
                          value: stats['duplicates'] ?? 0,
                          icon: Icons.copy_all,
                          color: BrandColors.deepRed,
                        ),
                        _StatCard(
                          label: 'ارسال‌شده',
                          value: stats['sent'] ?? 0,
                          icon: Icons.check_circle,
                          color: const Color(0xFF2E7D32),
                        ),
                        _StatCard(
                          label: 'ناموفق',
                          value: stats['failed'] ?? 0,
                          icon: Icons.error,
                          color: BrandColors.red,
                        ),
                        _StatCard(
                          label: 'در انتظار',
                          value: stats['pending'] ?? 0,
                          icon: Icons.schedule,
                          color: const Color(0xFF1967D2),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [BrandColors.orange, BrandColors.yellow, BrandColors.red],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/sms_sender_logo.png',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ارسال پیامک محلی',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'مدیریت مخاطبین، پیش‌نمایش و ارسال کنترل‌شده پیامک',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: color),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
