class PhoneNormalizerService {
  static final RegExp _validIranMobile = RegExp(r'^09\d{9}$');
  static const Map<String, String> _digitMap = {
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
  };

  String normalize(String input) {
    var value = input.split('').map((char) => _digitMap[char] ?? char).join();
    value = value.replaceAll(RegExp(r'\D'), '');
    if (value.startsWith('00989') && value.length == 14) {
      value = '0${value.substring(4)}';
    } else if (value.startsWith('989') && value.length == 12) {
      value = '0${value.substring(2)}';
    } else if (value.startsWith('9') && value.length == 10) {
      value = '0$value';
    }
    return value;
  }

  bool isValid(String input) => _validIranMobile.hasMatch(normalize(input));
}
