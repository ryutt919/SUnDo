import 'package:my_routine/data/repositories/routine_repository.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:my_routine/domain/models/habit.dart';
import 'package:my_routine/domain/models/repeat_rule.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 테스트용 저장소. 시드 루틴 없이 빈 상태로 시작한다.
Future<RoutineRepository> emptyRoutine({Map<String, Object> initial = const {}}) async {
  SharedPreferences.setMockInitialValues({'habits': '[]', ...initial});
  final store = await StorageService.create();
  final repo = RoutineRepository(store);
  await repo.load();
  return repo;
}

Habit habit(
  String id, {
  String start = '2026-01-01',
  RepeatRule repeat = const RepeatRule(),
  String name = '테스트',
  List<String> modes = const [],
}) =>
    Habit(id: id, name: name, start: start, repeat: repeat, modes: modes);
