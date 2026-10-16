import '../../../../data/repositories/routine_repository.dart';
import '../../../../domain/models/journal_models.dart';
import '../../../core/repo_view_model.dart';

/// 루틴 모드 선택과 관리.
class ModesViewModel extends RepoViewModel {
  ModesViewModel(this._routine) : super([_routine]);

  final RoutineRepository _routine;

  List<RoutineMode> get modes => _routine.modes;
  String get activeModeId => _routine.activeModeId;
  bool get canDelete => modes.length > 1;

  Future<void> apply(String id) => _routine.setActiveMode(id);

  Future<bool> add(String name) => _routine.addMode(name);

  Future<void> rename(String id, String name) => _routine.renameMode(id, name);

  Future<void> delete(String id) => _routine.deleteMode(id);
}
