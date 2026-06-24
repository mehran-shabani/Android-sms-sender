class SmsPartEstimator {
  bool isUnicode(String message) {
    // GSM 7-bit default alphabet characters
    // This is a simplified check for common Persian/Unicode characters
    for (int i = 0; i < message.length; i++) {
      if (message.codeUnitAt(i) > 127) {
        return true;
      }
    }
    return false;
  }

  int estimate(String message) {
    final length = message.length;
    if (length == 0) return 0;

    final unicode = isUnicode(message);

    if (unicode) {
      if (length <= 70) return 1;
      return (length / 67).ceil();
    } else {
      if (length <= 160) return 1;
      return (length / 153).ceil();
    }
  }
}
