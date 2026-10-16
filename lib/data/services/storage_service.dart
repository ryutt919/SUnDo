import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences를 JSON 저장소로 감싼 서비스. 상태는 가지지 않는다.
class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static Future<StorageService> create() async =>
      StorageService(await SharedPreferences.getInstance());

  /// 다른 isolate(위젯 백그라운드 콜백)가 바꾼 값을 다시 읽어 온다.
  Future<void> reload() => _prefs.reload();

  bool contains(String key) => _prefs.containsKey(key);

  /// 저장된 JSON을 읽는다. 깨진 데이터는 `<key>.corrupt.<시각>`에 보관하고 null을 돌려준다.
  Object? readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException catch (e) {
      debugPrint('저장 데이터 "$key"를 읽지 못했다: $e');
      _prefs.setString('$key.corrupt.${DateTime.now().millisecondsSinceEpoch}', raw);
      return null;
    }
  }

  Future<void> writeJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));

  String? readString(String key) => _prefs.getString(key);

  Future<void> writeString(String key, String value) => _prefs.setString(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  Future<void> clearAll() => _prefs.clear();
}
