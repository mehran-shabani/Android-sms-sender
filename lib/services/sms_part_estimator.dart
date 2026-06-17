import 'dart:math' as math;

class SmsPartEstimator {
  int estimate(String message) {
    final length = message.length;
    if (length == 0) return 0;
    if (length <= 70) return 1;
    return math.max(1, (length / 67).ceil());
  }
}
