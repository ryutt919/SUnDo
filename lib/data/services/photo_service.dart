import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 습관 인증 사진을 고르거나 찍어 앱 전용 폴더에 복사한다.
class PhotoService {
  final ImagePicker _picker = ImagePicker();

  Future<Directory> _proofsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/proofs');
    await dir.create(recursive: true);
    return dir;
  }

  Future<String?> pick(ImageSource source) async {
    final x = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (x == null) return null;
    final dir = await _proofsDir();
    final dest = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy(dest);
    return dest;
  }

  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  /// 백업용으로 사진 파일을 base64로 읽는다. 파일이 없으면 null.
  Future<String?> readBase64(String path) async {
    final f = File(path);
    if (!await f.exists()) return null;
    return base64Encode(await f.readAsBytes());
  }

  /// 백업에서 꺼낸 사진을 앱 전용 폴더에 다시 저장하고 새 경로를 돌려준다.
  Future<String> restore(String name, List<int> bytes) async {
    final dir = await _proofsDir();
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dest = '${dir.path}/$safe';
    await File(dest).writeAsBytes(bytes);
    return dest;
  }
}
