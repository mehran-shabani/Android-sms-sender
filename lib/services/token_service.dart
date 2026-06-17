class TokenService {
  static final RegExp _spaces = RegExp(r'[\s\u200c]+');
  static final RegExp _unsafe = RegExp(r'[^\u0600-\u06FFa-zA-Z0-9_]');
  static final RegExp _multiUnderscore = RegExp(r'_+');

  String buildToken({String? fullName, String? firstName, String? lastName}) {
    final source = (fullName?.trim().isNotEmpty ?? false)
        ? fullName!.trim()
        : '${firstName ?? ''} ${lastName ?? ''}'.trim();
    var token = source.isEmpty ? 'مراجع_محترم' : source;
    token = token.replaceAll(_spaces, '_');
    token = token.replaceAll(_unsafe, '');
    token = token.replaceAll(_multiUnderscore, '_');
    token = token.replaceAll(RegExp(r'^_+|_+$'), '');
    if (token.isEmpty) token = 'مراجع_محترم';
    return token.length > 100 ? token.substring(0, 100) : token;
  }
}
