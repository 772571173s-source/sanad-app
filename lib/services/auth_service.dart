import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class AuthService {
  static final _random = Random.secure();

  static String hashPassword(String password, {String? salt}) {
    final usedSalt = salt ?? _salt();
    final digest = sha256.convert(utf8.encode('$usedSalt:$password'));
    return '$usedSalt$separator$digest';
  }

  static bool verifyPassword(String password, String storedHash) {
    if (!storedHash.contains(separator)) return false;
    final salt = storedHash.split(separator).first;
    return hashPassword(password, salt: salt) == storedHash;
  }

  static const separator = r'$';

  static String _salt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }
}
