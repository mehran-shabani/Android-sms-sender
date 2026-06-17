class AppSettings {
  const AppSettings({
    required this.smsTemplate,
    required this.delaySeconds,
    required this.skipDuplicates,
    required this.skipInvalid,
    this.selectedSubscriptionId,
  });

  static const defaultSmsTemplate = '''{token} عزیز
لطفا اطلاعات پرونده سلامت خود را از نشانی زیر بررسی و تکمیل کنید:
helssa.ir
لغو11''';

  factory AppSettings.defaults() => const AppSettings(
        smsTemplate: defaultSmsTemplate,
        delaySeconds: 30,
        skipDuplicates: true,
        skipInvalid: true,
      );

  final String smsTemplate;
  final int delaySeconds;
  final bool skipDuplicates;
  final bool skipInvalid;
  final int? selectedSubscriptionId;

  factory AppSettings.fromMap(Map<String, Object?> map) {
    return AppSettings(
      smsTemplate: map['sms_template'] as String? ?? defaultSmsTemplate,
      delaySeconds: map['delay_seconds'] as int? ?? 30,
      skipDuplicates: (map['skip_duplicates'] as int? ?? 1) == 1,
      skipInvalid: (map['skip_invalid'] as int? ?? 1) == 1,
      selectedSubscriptionId: map['selected_subscription_id'] as int?,
    );
  }

  Map<String, Object?> toMap() => {
        'id': 1,
        'sms_template': smsTemplate,
        'delay_seconds': delaySeconds,
        'skip_duplicates': skipDuplicates ? 1 : 0,
        'skip_invalid': skipInvalid ? 1 : 0,
        'selected_subscription_id': selectedSubscriptionId,
      };

  AppSettings copyWith({
    String? smsTemplate,
    int? delaySeconds,
    bool? skipDuplicates,
    bool? skipInvalid,
    int? selectedSubscriptionId,
  }) {
    return AppSettings(
      smsTemplate: smsTemplate ?? this.smsTemplate,
      delaySeconds: delaySeconds ?? this.delaySeconds,
      skipDuplicates: skipDuplicates ?? this.skipDuplicates,
      skipInvalid: skipInvalid ?? this.skipInvalid,
      selectedSubscriptionId:
          selectedSubscriptionId ?? this.selectedSubscriptionId,
    );
  }
}
