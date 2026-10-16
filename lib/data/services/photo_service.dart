import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 습관 인증 사진을 고르거나 찍어 앱 전용 폴더에 복사한다.
/// 읽기와 삭제는 앱 전용 사진 폴더 안의 파일에만 허용한다(변조된 백업의 경로로 다른 파일을 건드리지 못하게).
class PhotoService {
  final ImagePicker _picker = ImagePicker();

  Future<Directory> _proofsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/proofs');
    await dir.create(recursive: true);
    return dir;
  }

  /// [path]가 앱 전용 사진 폴더 안의 실제 파일이면 true.
  Future<bool> _isOwnPhoto(String path) async {
    final f = File(path);
    if (!await f.exists()) return false;
    final root = await (await _proofsDir()).resolveSymbolicLinks();
    final real = await f.resolveSymbolicLinks();
    return real.startsWith('$root${Platform.pathSeparator}');
  }

  Future<String?> pick(ImageSource source) async {
    final x = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (x == null) return null;
    final dir = await _proofsDir();
    final dest = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy(dest);
    return dest;
  }

  /// 앱 전용 폴더 안의 사진만 지운다. 그 밖의 경로는 무시한다.
  Future<void> delete(String path) async {
    if (await _isOwnPhoto(path)) await File(path).delete();
  }

  /// 백업용으로 사진 파일을 base64로 읽는다. 앱 전용 폴더 밖이거나 파일이 없으면 null.
  Future<String?> readBase64(String path) async {
    if (!await _isOwnPhoto(path)) return null;
    return base64Encode(await File(path).readAsBytes());
  }

  /// 백업에서 꺼낸 사진을 앱 전용 폴더에 다시 저장하고 새 경로를 돌려준다.
  /// 이미 있는 사진을 덮어쓰지 않도록 항상 새 파일 이름을 만든다(가져오기가 중간에 실패해도 기존 사진이 상하지 않게).
  Future<String> restore(String name, List<int> bytes) async {
    final dir = await _proofsDir();
    var safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_'); // 점도 제거해 '.', '..'를 막는다
    if (safe.isEmpty) safe = 'photo';
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final dest = '${dir.path}/restored_${stamp}_$safe.jpg';
    await File(dest).writeAsBytes(bytes);
    return dest;
  }
}
