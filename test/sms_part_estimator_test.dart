import 'package:flutter_test/flutter_test.dart';
import 'package:android_sms_sender/services/sms_part_estimator.dart';

void main() {
  final estimator = SmsPartEstimator();

  group('SmsPartEstimator GSM-7 tests', () {
    test('Empty message', () {
      expect(estimator.estimate(''), 0);
    });

    test('Short GSM message', () {
      expect(estimator.estimate('Hello'), 1);
      expect(estimator.estimate('A' * 160), 1);
    });

    test('Multi-part GSM message', () {
      expect(estimator.estimate('A' * 161), 2);
      expect(estimator.estimate('A' * 306), 2);
      expect(estimator.estimate('A' * 307), 3);
    });
  });

  group('SmsPartEstimator Unicode tests', () {
    test('Short Unicode message (Persian)', () {
      expect(estimator.estimate('سلام'), 1);
      expect(estimator.estimate('س' * 70), 1);
    });

    test('Multi-part Unicode message', () {
      expect(estimator.estimate('س' * 71), 2);
      expect(estimator.estimate('س' * 134), 2);
      expect(estimator.estimate('س' * 135), 3);
    });
  });
}
