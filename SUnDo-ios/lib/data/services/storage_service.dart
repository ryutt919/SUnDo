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

  /// 저장에 실패하면(플러그인이 false를 돌려주면) 예외를 던진다. 조용히 넘어가면 화면에는
  /// 저장된 것처럼 보이지만 디스크에는 남지 않기 때문이다.
  Future<void> writeJson(String key, Object value) async {
    if (!await _prefs.setString(key, jsonEncode(value))) {
      throw StorageWriteException(key);
    }
  }

  String? readString(String key) => _prefs.getString(key);

  Future<void> writeString(String key, String value) async {
    if (!await _prefs.setString(key, value)) throw StorageWriteException(key);
  }

  Future<void> remove(String key) async {
    if (!await _prefs.remove(key)) throw StorageWriteException(key);
  }

  Future<void> clearAll() async {
    if (!await _prefs.clear()) throw StorageWriteException('(전체)');
  }
}

/// 값을 디스크에 저장하지 못했을 때 던지는 예외.
class StorageWriteException implements Exception {
  StorageWriteException(this.key);
  final String key;

  @override
  String toString() => '"$key" 저장에 실패했어요';
}
