import 'dart:convert';

import '../services/backup_service.dart';
import '../services/photo_service.dart';
import 'journal_repository.dart';
import 'routine_repository.dart';
import 'settings_repository.dart';

/// 세 저장소의 데이터를 하나의 JSON으로 묶어 내보내고, 웹앱 백업까지 포함해 불러온다.
/// 인증 사진은 `photoFiles`에 base64로 함께 담는다.
class BackupRepository {
  BackupRepository(this._service, this._photos, this._routine, this._journal, this._settings);

  final BackupService _service;
  final PhotoService _photos;
  final RoutineRepository _routine;
  final JournalRepository _journal;
  final SettingsRepository _settings;

  static const _photoPrefix = 'photos/';

  Map<String, dynamic> snapshot() => {
        'version': 1,
        ..._routine.exportJson(),
        ..._journal.exportJson(),
        'settings': _settings.exportJson(),
      };

  /// 사진 파일을 포함한 내보내기용 JSON. 파일이 사라진 사진은 기록에서 뺀다.
  Future<Map<String, dynamic>> buildExport() async {
    final data = snapshot();
    final photoFiles = <String, String>{};
    final logs = data['logs'] as Map<String, dynamic>;
    for (final day in logs.values) {
      for (final log in (day as Map<String, dynamic>).values) {
        final l = log as Map<String, dynamic>;
        final path = l['photo'] as String?;
        if (path == null) continue;
        final name = path.split(RegExp(r'[\\/]')).last;
        final b64 = photoFiles[name] ?? await _photos.readBase64(path);
        if (b64 == null) {
          l.remove('photo');
        } else {
          photoFiles[name] = b64;
          l['photo'] = '$_photoPrefix$name';
        }
      }
    }
    if (photoFiles.isNotEmpty) data['photoFiles'] = photoFiles;
    return data;
  }

  Future<void> export() async => _service.share(await buildExport());

  /// 파일을 골라 현재 데이터를 덮어쓴다. 취소하면 false.
  Future<bool> importFromFile() async {
    final data = await _service.pick();
    if (data == null) return false;
    if (data['habits'] is! List || data['logs'] is! Map) {
      throw const FormatException('내 루틴 백업 파일이 아니에요');
    }
    // 어느 한쪽이라도 형식이 틀리면 아무것도 바꾸지 않도록 먼저 모두 검사한다.
    final s = data['settings'];
    if (s != null && s is! Map) throw const FormatException('설정 백업 형식이 올바르지 않아요'); // 설정이 없는 구백업만 허용
    final settingsJson = s is Map ? s.cast<String, dynamic>() : null;
    _routine.validateJson(data);
    _journal.validateJson(data);
    _settings.validateJson(settingsJson);
    final photoBytes = _decodePhotos(data);

    await _restorePhotos(data, photoBytes);
    await _routine.importJson(data);
    await _journal.importJson(data);
    await _settings.importJson(settingsJson);
    return true;
  }

  /// 사진 base64를 미리 풀어 본다. 깨져 있으면 FormatException.
  Map<String, List<int>> _decodePhotos(Map<String, dynamic> data) {
    final raw = data['photoFiles'];
    if (raw == null) return {};
    if (raw is! Map) throw const FormatException('사진 백업 형식이 올바르지 않아요');
    try {
      return {for (final e in raw.entries) '${e.key}': base64Decode(e.value as String)};
    } on FormatException {
      throw const FormatException('사진 백업이 깨져 있어요');
    } on TypeError {
      throw const FormatException('사진 백업 형식이 올바르지 않아요');
    }
  }

  /// 백업의 `photos/<이름>` 표시를 이 기기에 복원한 파일 경로로 바꾼다.
  Future<void> _restorePhotos(Map<String, dynamic> data, Map<String, List<int>> bytes) async {
    final logs = data['logs'] as Map;
    for (final day in logs.values) {
      for (final log in (day as Map).values) {
        final entry = log as Map;
        final ref = entry['photo'];
        if (ref == null) continue;
        if (ref is! String || !ref.startsWith(_photoPrefix)) {
          // 이 앱이 만든 `photos/<이름>` 표시가 아니면 믿을 수 없는 경로이므로 연결을 끊는다
          entry.remove('photo');
          continue;
        }
        final name = ref.substring(_photoPrefix.length);
        final b = bytes[name];
        if (b == null) {
          entry.remove('photo'); // 파일이 백업에 없으면 사진 연결만 끊는다
        } else {
          entry['photo'] = await _photos.restore(name, b);
        }
      }
    }
  }

  Future<void> resetAll() async {
    await _routine.resetAll();
    await _journal.resetAll();
  }
}
