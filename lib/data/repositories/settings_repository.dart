import 'package:flutter/foundation.dart';

import '../../domain/models/journal_models.dart';
import '../services/storage_service.dart';

class SettingsRepository extends ChangeNotifier {
  SettingsRepository(this._store);

  final StorageService _store;
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  Future<void> load() async {
    await _store.reload();
    final v = _store.readJson('settings');
    _settings = AppSettings.fromJson(v is Map ? v.cast<String, dynamic>() : null);
    notifyListeners();
  }

  Future<void> update(AppSettings s) async {
    _settings = s;
    await _store.writeJson('settings', s.toJson());
    notifyListeners();
  }

  Map<String, dynamic> exportJson() => _settings.toJson();

  /// 덮어쓰기 전에 형식만 검사한다. 틀리면 FormatException을 던진다.
  void validateJson(Map<String, dynamic>? j) {
    try {
      AppSettings.fromJson(j);
    } on TypeError catch (e) {
      throw FormatException('설정 백업 형식이 올바르지 않아요: $e');
    }
  }

  Future<void> importJson(Map<String, dynamic>? j) => update(AppSettings.fromJson(j));
}
