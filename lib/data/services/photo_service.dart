import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 습관 인증 사진을 고르거나 찍어 앱 전용 폴더에 복사한다.
class PhotoService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> pick(ImageSource source) async {
    final x = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (x == null) return null;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/proofs');
    await dir.create(recursive: true);
    final dest = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy(dest);
    return dest;
  }

  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
