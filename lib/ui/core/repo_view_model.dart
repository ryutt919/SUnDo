import 'package:flutter/foundation.dart';

/// 저장소(Listenable)가 바뀌면 함께 알림을 보내는 ViewModel 기반 클래스.
abstract class RepoViewModel extends ChangeNotifier {
  RepoViewModel(List<Listenable> sources) : _sources = sources {
    for (final s in sources) {
      s.addListener(notifyListeners);
    }
  }

  final List<Listenable> _sources;

  @override
  void dispose() {
    for (final s in _sources) {
      s.removeListener(notifyListeners);
    }
    super.dispose();
  }
}
