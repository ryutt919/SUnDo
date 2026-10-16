import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/date_key.dart';

/// 백업 JSON 파일을 내보내고(공유 시트) 불러온다(파일 선택).
class BackupService {
  Future<void> share(Map<String, dynamic> data) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/myroutine-backup-${todayKey()}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: '내 루틴 백업'));
  }

  /// 사용자가 고른 JSON 파일을 읽는다. 취소하면 null, 형식이 틀리면 FormatException.
  Future<Map<String, dynamic>?> pick() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException('백업 파일 형식이 아니에요');
    return decoded;
  }
}
