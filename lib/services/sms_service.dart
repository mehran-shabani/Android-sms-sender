import 'package:flutter/material.dart';
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

class SubscriptionInfo {
  const SubscriptionInfo({
    required this.subscriptionId,
    required this.displayName,
    required this.carrierName,
    required this.slotIndex,
  });

  final int subscriptionId;
  final String displayName;
  final String carrierName;
  final int slotIndex;

  factory SubscriptionInfo.fromMap(Map<dynamic, dynamic> map) {
    return SubscriptionInfo(
      subscriptionId: map['subscriptionId'] as int,
      displayName: map['displayName'] as String? ?? 'Unknown',
      carrierName: map['carrierName'] as String? ?? 'Unknown',
      slotIndex: map['slotIndex'] as int? ?? -1,
    );
  }
}

class SmsService {
  SmsService._();

  static String nativeErrorText(PlatformException error) {
    return switch (error.code) {
      'INVALID_PHONE' => 'invalid phone',
      'EMPTY_MESSAGE' => 'empty message',
      'PERMISSION_DENIED' => 'permission denied',
      'NO_SMS_FEATURE' => 'device does not support SMS',
      'NO_DEFAULT_SMS' => 'no SIM if detected',
      'NATIVE_SEND_FAILURE' =>
        'native send failure: ${error.message ?? ''}'.trim(),
      _ => 'unknown error: ${error.message ?? error.code}',
    };
  }

  static const MethodChannel _channel = MethodChannel('local_sms_sender/sms');

  static Future<SmsPermissionState> requestSmsPermission() async {
    final status = await Permission.sms.request();
    if (status.isGranted) return SmsPermissionState.granted;
    if (status.isPermanentlyDenied) return SmsPermissionState.permanentlyDenied;
    return SmsPermissionState.denied;
  }

  static Future<SmsCapabilityInfo> requestSmsCapabilityInfo() async {
    final response = await _channel
        .invokeMapMethod<String, dynamic>('requestSmsCapabilityInfo');
    return SmsCapabilityInfo.fromMap(response ?? const <String, dynamic>{});
  }

  static Future<List<SubscriptionInfo>> getSubscriptionInfo() async {
    try {
      final List<dynamic>? response =
          await _channel.invokeMethod<List<dynamic>>('getSubscriptionInfo');
      if (response == null) return [];
      return response
          .map((e) => SubscriptionInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting subscription info: $e');
      return [];
    }
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
    return SmsSendResult.fromMap(
        response ?? const <String, dynamic>{'success': false});
  }
}
