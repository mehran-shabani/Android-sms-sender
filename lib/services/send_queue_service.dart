import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/contact_record.dart';
import 'local_db_service.dart';
import 'sms_service.dart';

enum SendQueueState { idle, preparing, running, paused, stopped, completed }

enum SendQueueMode { testTwo, nextTen, nextFifty, selected, allUnsent }

class SendQueueSummary {
  const SendQueueSummary({
    required this.sent,
    required this.failed,
    required this.skipped,
    required this.stopped,
  });
  final int sent;
  final int failed;
  final int skipped;
  final bool stopped;
}

class SendQueueService extends ChangeNotifier {
  SendQueueService._();
  static final SendQueueService instance = SendQueueService._();

  final _db = LocalDbService.instance;
  SendQueueState state = SendQueueState.idle;
  List<ContactRecord> _queue = const [];
  String currentRecipient = 'هنوز شروع نشده';
  String lastError = '—';
  String capabilitySummary = 'هنوز بررسی نشده';
  int sentCount = 0;
  int failedCount = 0;
  int skippedCount = 0;
  int processedCount = 0;
  SendQueueSummary? lastSummary;
  bool _stopRequested = false;
  Completer<void>? _resumeCompleter;

  int get totalCount => _queue.length;
  int get remainingCount => (totalCount - processedCount).clamp(0, totalCount);
  double get progress => totalCount == 0 ? 0 : processedCount / totalCount;
  bool get isActive =>
      state == SendQueueState.running ||
      state == SendQueueState.paused ||
      state == SendQueueState.preparing;

  Future<List<ContactRecord>> prepareQueue(SendQueueMode mode) async {
    final contacts = switch (mode) {
      SendQueueMode.testTwo =>
        await _db.getEligibleContacts(onlyPendingOrFailed: true, limit: 2),
      SendQueueMode.nextTen =>
        await _db.getEligibleContacts(onlyPendingOrFailed: true, limit: 10),
      SendQueueMode.nextFifty =>
        await _db.getEligibleContacts(onlyPendingOrFailed: true, limit: 50),
      SendQueueMode.selected =>
        await _db.getSelectedContacts(onlyPendingOrFailed: true),
      SendQueueMode.allUnsent =>
        await _db.getEligibleContacts(onlyPendingOrFailed: true),
    };
    return contacts;
  }

  Future<SendQueueSummary> start(SendQueueMode mode) async {
    if (isActive) throw StateError('Queue is already running.');
    _reset();
    state = SendQueueState.preparing;
    currentRecipient = 'در حال آماده‌سازی';
    notifyListeners();

    final settings = await _db.getSettings();
    final delaySeconds = _safeDelay(settings);
    _queue = await prepareQueue(mode);
    if (_queue.isEmpty) {
      return _finish(stopped: false, current: 'مخاطب واجد شرایطی وجود ندارد');
    }

    final permission = await SmsService.requestSmsPermission();
    if (permission != SmsPermissionState.granted) {
      lastError = permission == SmsPermissionState.permanentlyDenied
          ? 'SMS permission permanently denied'
          : 'permission denied';
      await _markPreparedFailed(lastError);
      return _finish(stopped: false, current: 'ارسال انجام نشد');
    }

    try {
      final capability = await SmsService.requestSmsCapabilityInfo();
      capabilitySummary = capability.persianSummary;
      if (!capability.hasSmsFeature) {
        throw StateError('device does not support SMS');
      }
      if (!capability.defaultSmsAvailable) {
        throw StateError('no SIM if detected');
      }
    } catch (error) {
      lastError = error is StateError ? error.message : 'unknown error: $error';
      await _markPreparedFailed(lastError);
      return _finish(stopped: false, current: 'ارسال انجام نشد');
    }

    state = SendQueueState.running;
    notifyListeners();
    for (var i = 0; i < _queue.length; i++) {
      if (_stopRequested) break;
      await _waitIfPaused();
      if (_stopRequested) break;
      final contact = _queue[i];
      currentRecipient = contact.displayNameOrPhone;
      notifyListeners();
      final skipReason = _skipReason(contact, settings);
      if (skipReason != null) {
        skippedCount++;
        processedCount++;
        lastError = skipReason;
        notifyListeners();
      } else {
        await _sendOne(contact, settings);
      }
      if (i < _queue.length - 1 && !_stopRequested) {
        await _waitDelayOrStop(Duration(seconds: delaySeconds));
      }
    }
    return _finish(
        stopped: _stopRequested,
        current: _stopRequested ? 'ارسال متوقف شد' : 'پایان ارسال');
  }

  void pause() {
    if (state == SendQueueState.running) {
      state = SendQueueState.paused;
      _resumeCompleter = Completer<void>();
      notifyListeners();
    }
  }

  void resume() {
    if (state == SendQueueState.paused) {
      state = SendQueueState.running;
      _resumeCompleter?.complete();
      _resumeCompleter = null;
      notifyListeners();
    }
  }

  void stop() {
    if (isActive) {
      _stopRequested = true;
      if (state == SendQueueState.paused) resume();
      state = SendQueueState.stopped;
      notifyListeners();
    }
  }

  Future<void> _waitIfPaused() async {
    if (state == SendQueueState.paused) await _resumeCompleter?.future;
  }

  Future<void> _waitDelayOrStop(Duration delay) async {
    const step = Duration(milliseconds: 500);
    var remaining = delay;

    while (remaining > Duration.zero && !_stopRequested) {
      await _waitIfPaused();
      if (_stopRequested) return;

      final waitFor = remaining < step ? remaining : step;
      final stopwatch = Stopwatch()..start();
      await Future<void>.delayed(waitFor);
      stopwatch.stop();
      remaining -= stopwatch.elapsed;
    }
  }

  int _safeDelay(AppSettings settings) => settings.delaySeconds.clamp(10, 120);

  String? _skipReason(ContactRecord c, AppSettings s) {
    if (c.id == null) return 'missing contact id';
    if (s.skipInvalid && !c.isValidPhone) return 'skipped invalid phone';
    if (s.skipDuplicates && c.isDuplicate) return 'skipped duplicate phone';
    if (c.phone.trim().isEmpty || !c.isValidPhone) return 'invalid phone';
    if (c.message.trim().isEmpty) return 'empty message';
    if (!c.canBePreparedForSending) return 'not pending or failed';
    return null;
  }

  Future<void> _sendOne(ContactRecord contact, AppSettings settings) async {
    try {
      final result = await SmsService.sendSms(
          phone: contact.phone,
          message: contact.message,
          subscriptionId: settings.selectedSubscriptionId);
      if (result.success) {
        await _db.updateContactStatus(contact.id!, ContactStatus.sent,
            sentAt: DateTime.now());
        sentCount++;
      } else {
        await _recordFailure(contact, result.message ?? 'native send failure');
      }
    } on PlatformException catch (error) {
      await _recordFailure(contact, SmsService.nativeErrorText(error));
    } catch (error) {
      await _recordFailure(contact, 'unknown error: $error');
    }
    processedCount++;
    notifyListeners();
  }

  Future<void> _recordFailure(ContactRecord contact, String error) async {
    await _db.updateContactStatus(contact.id!, ContactStatus.failed,
        error: error);
    failedCount++;
    lastError = error;
  }

  Future<void> _markPreparedFailed(String error) async {
    for (final contact in _queue) {
      if (contact.id != null) {
        await _db.updateContactStatus(contact.id!, ContactStatus.failed,
            error: error);
      }
    }
    failedCount = _queue.length;
    processedCount = _queue.length;
  }

  SendQueueSummary _finish({required bool stopped, required String current}) {
    state = stopped ? SendQueueState.stopped : SendQueueState.completed;
    currentRecipient = current;
    lastSummary = SendQueueSummary(
        sent: sentCount,
        failed: failedCount,
        skipped: skippedCount,
        stopped: stopped);
    notifyListeners();
    return lastSummary!;
  }

  void _reset() {
    _queue = const [];
    state = SendQueueState.idle;
    currentRecipient = 'هنوز شروع نشده';
    lastError = '—';
    sentCount = failedCount = skippedCount = processedCount = 0;
    _stopRequested = false;
    lastSummary = null;
  }
}
