import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsCapabilityInfo {
  const SmsCapabilityInfo({
    required this.canSendSms,
    required this.hasSmsFeature,
    required this.defaultSmsAvailable,
    this.error,
  });

  final bool canSendSms;
  final bool hasSmsFeature;
  final bool defaultSmsAvailable;
  final String? error;

  factory SmsCapabilityInfo.fromMap(Map<dynamic, dynamic> map) {
    return SmsCapabilityInfo(
      canSendSms: map['canSendSms'] == true,
      hasSmsFeature: map['hasSmsFeature'] == true,
      defaultSmsAvailable: map['defaultSmsAvailable'] == true,
      error: map['error'] as String?,
    );
  }

  String get persianSummary {
    final parts = <String>[
      'قابلیت ارسال: ${canSendSms ? 'بله' : 'خیر'}',
      'پشتیبانی SMS دستگاه: ${hasSmsFeature ? 'بله' : 'خیر'}',
      'SmsManager پیش‌فرض: ${defaultSmsAvailable ? 'موجود' : 'ناموجود'}',
    ];
    if (error != null && error!.isNotEmpty) parts.add('خطا: $error');
    return parts.join('\n');
  }
}

enum SmsPermissionState { granted, denied, permanentlyDenied }

class SmsSendResult {
  const SmsSendResult({
    required this.success,
    required this.parts,
    required this.bestEffort,
    this.message,
  });

  final bool success;
  final int parts;
  final bool bestEffort;
  final String? message;

  factory SmsSendResult.fromMap(Map<dynamic, dynamic> map) {
    return SmsSendResult(
      success: map['success'] == true,
      parts: map['parts'] as int? ?? 0,
      bestEffort: map['bestEffort'] == true,
      message: map['message'] as String?,
    );
  }
}

class SmsService {
  SmsService._();

  static const MethodChannel _channel = MethodChannel('local_sms_sender/sms');

  static Future<SmsPermissionState> requestSmsPermission() async {
    final status = await Permission.sms.request();
    if (status.isGranted) return SmsPermissionState.granted;
    if (status.isPermanentlyDenied) return SmsPermissionState.permanentlyDenied;
    return SmsPermissionState.denied;
  }

  static Future<SmsCapabilityInfo> requestSmsCapabilityInfo() async {
    final response = await _channel.invokeMapMethod<String, dynamic>('requestSmsCapabilityInfo');
    return SmsCapabilityInfo.fromMap(response ?? const <String, dynamic>{});
  }

  static Future<SmsSendResult> sendSms({
    required String phone,
    required String message,
    int? subscriptionId,
  }) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'sendSms',
      <String, dynamic>{
        'phone': phone,
        'message': message,
        if (subscriptionId != null) 'subscriptionId': subscriptionId,
      },
    );
    return SmsSendResult.fromMap(response ?? const <String, dynamic>{'success': false});
  }
}
