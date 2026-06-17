import 'package:flutter/material.dart';

import '../services/local_db_service.dart';
import '../services/send_queue_service.dart';

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
    if (mounted) setState(() => _statsFuture = LocalDbService.instance.getStats());
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
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _StatCard(label: 'کل مخاطبین', value: stats['total'] ?? 0),
                _StatCard(label: 'معتبر', value: stats['valid'] ?? 0),
                _StatCard(label: 'نامعتبر', value: stats['invalid'] ?? 0),
                _StatCard(label: 'تکراری', value: stats['duplicates'] ?? 0),
                _StatCard(label: 'ارسال‌شده', value: stats['sent'] ?? 0),
                _StatCard(label: 'ناموفق', value: stats['failed'] ?? 0),
                _StatCard(label: 'در انتظار', value: stats['pending'] ?? 0),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
