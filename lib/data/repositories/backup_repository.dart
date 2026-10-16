import '../services/backup_service.dart';
import 'journal_repository.dart';
import 'routine_repository.dart';
import 'settings_repository.dart';

/// 세 저장소의 데이터를 하나의 JSON으로 묶어 내보내고, 웹앱 백업까지 포함해 불러온다.
class BackupRepository {
  BackupRepository(this._service, this._routine, this._journal, this._settings);

  final BackupService _service;
  final RoutineRepository _routine;
  final JournalRepository _journal;
  final SettingsRepository _settings;

  Map<String, dynamic> snapshot() => {
        'version': 1,
        ..._routine.exportJson(),
        ..._journal.exportJson(),
        'settings': _settings.exportJson(),
      };

  Future<void> export() => _service.share(snapshot());

  /// 파일을 골라 현재 데이터를 덮어쓴다. 취소하면 false.
  Future<bool> importFromFile() async {
    final data = await _service.pick();
    if (data == null) return false;
    if (data['habits'] is! List || data['logs'] is! Map) {
      throw const FormatException('내 루틴 백업 파일이 아니에요');
    }
    // 어느 한쪽이라도 형식이 틀리면 아무것도 바꾸지 않도록 먼저 모두 검사한다.
    _routine.validateJson(data);
    _journal.validateJson(data);
    await _routine.importJson(data);
    await _journal.importJson(data);
    final s = data['settings'];
    await _settings.importJson(s is Map ? s.cast<String, dynamic>() : null);
    return true;
  }

  Future<void> resetAll() async {
    await _routine.resetAll();
    await _journal.resetAll();
  }
}
