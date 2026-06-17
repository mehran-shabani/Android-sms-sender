import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/app_settings.dart';
import '../services/local_db_service.dart';
import '../services/sms_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _templateController = TextEditingController();
  final _delayController = TextEditingController();
  bool _skipDuplicates = true;
  bool _skipInvalid = true;
  int? _selectedSubscriptionId;
  List<SubscriptionInfo> _subscriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await LocalDbService.instance.getSettings();

    // Request permission to read phone state for SIM info
    await Permission.phone.request();
    final subs = await SmsService.getSubscriptionInfo();

    setState(() {
      _templateController.text = settings.smsTemplate;
      _delayController.text = settings.delaySeconds.toString();
      _skipDuplicates = settings.skipDuplicates;
      _skipInvalid = settings.skipInvalid;
      _selectedSubscriptionId = settings.selectedSubscriptionId;
      _subscriptions = subs;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await LocalDbService.instance.saveSettings(
      AppSettings(
        smsTemplate: _templateController.text.trim(),
        delaySeconds: int.parse(_delayController.text),
        skipDuplicates: _skipDuplicates,
        skipInvalid: _skipInvalid,
        selectedSubscriptionId: _selectedSubscriptionId,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تنظیمات ذخیره شد')),
    );
  }

  @override
  void dispose() {
    _templateController.dispose();
    _delayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _templateController,
                    minLines: 5,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'قالب پیامک',
                      helperText: 'از {token} برای نام مخاطب استفاده کنید.',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'قالب پیامک الزامی است'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _delayController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'فاصله بین ارسال‌ها (ثانیه)',
                      helperText: 'در مرحله ارسال، بازه ۱۰ تا ۱۲۰ ثانیه اعمال می‌شود.',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '');
                      if (parsed == null) return 'عدد معتبر وارد کنید';
                      if (parsed < 10 || parsed > 120) {
                        return 'عدد باید بین ۱۰ تا ۱۲۰ باشد';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('رد کردن مخاطبین تکراری'),
                    value: _skipDuplicates,
                    onChanged: (value) => setState(() => _skipDuplicates = value),
                  ),
                  SwitchListTile(
                    title: const Text('رد کردن شماره‌های نامعتبر'),
                    value: _skipInvalid,
                    onChanged: (value) => setState(() => _skipInvalid = value),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('انتخاب سیم‌کارت',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  DropdownButtonFormField<int?>(
                    value: _selectedSubscriptionId,
                    decoration: const InputDecoration(
                      labelText: 'سیم‌کارت پیش‌فرض',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('پیش‌فرض سیستم'),
                      ),
                      ..._subscriptions.map((info) => DropdownMenuItem<int?>(
                            value: info.subscriptionId,
                            child: Text(
                                '${info.displayName} (${info.carrierName})'),
                          )),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedSubscriptionId = value),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('ذخیره تنظیمات'),
                  ),
                ],
              ),
            ),
    );
  }
}
