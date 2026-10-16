import 'repeat_rule.dart';

enum HabitLevel { mini, plus, max }

extension HabitLevelLabel on HabitLevel {
  String get label => switch (this) {
        HabitLevel.mini => 'Mini',
        HabitLevel.plus => 'Plus',
        HabitLevel.max => 'Max',
      };
}

HabitLevel? habitLevelFrom(String? s) {
  for (final l in HabitLevel.values) {
    if (l.name == s) return l;
  }
  return null;
}

const habitColors = [
  '#FFE8E8', '#FFF1D6', '#FFFDE9', '#E3F7E8',
  '#DDF1FF', '#EBE4FF', '#FFE4F3', '#EFEFEF',
];

/// 루틴 한 개. 불변 객체이며 수정은 copyWith로 한다.
class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.start,
    this.emoji = '✅',
    this.time = '',
    this.context = '',
    this.color = '#E3F7E8',
    this.repeat = const RepeatRule(),
    this.levels = const {'mini': '', 'plus': '', 'max': ''},
    this.alts = const [],
    this.alarm = '',
    this.unit = '',
    this.timerMin = 0,
    this.modes = const [],
    this.archived = false,
    this.reason = '',
    this.finishedOn,
  });

  final String id;
  final String name;
  final String emoji;
  final String time; // 'HH:mm' 또는 빈 문자열
  final String context; // '출근길에' 같은 상황 텍스트
  final String color;
  final RepeatRule repeat;
  final Map<String, String> levels;
  final List<String> alts;
  final String alarm; // 'HH:mm' 또는 빈 문자열
  final String unit;
  final int timerMin;
  final List<String> modes; // 비어 있으면 모든 모드에 적용
  final bool archived;
  final String start; // 'yyyy-MM-dd'
  final String reason; // 이 루틴을 하는 이유
  final String? finishedOn; // 종료한 날. 이 날 이후에는 나타나지 않는다

  Habit copyWith({
    String? name,
    String? emoji,
    String? time,
    String? context,
    String? color,
    RepeatRule? repeat,
    Map<String, String>? levels,
    List<String>? alts,
    String? alarm,
    String? unit,
    int? timerMin,
    List<String>? modes,
    bool? archived,
    String? start,
    String? reason,
    String? finishedOn,
    bool clearFinished = false,
  }) =>
      Habit(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        time: time ?? this.time,
        context: context ?? this.context,
        color: color ?? this.color,
        repeat: repeat ?? this.repeat,
        levels: levels ?? this.levels,
        alts: alts ?? this.alts,
        alarm: alarm ?? this.alarm,
        unit: unit ?? this.unit,
        timerMin: timerMin ?? this.timerMin,
        modes: modes ?? this.modes,
        archived: archived ?? this.archived,
        start: start ?? this.start,
        reason: reason ?? this.reason,
        finishedOn: clearFinished ? null : (finishedOn ?? this.finishedOn),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'time': time,
        'context': context,
        'color': color,
        'repeat': repeat.toJson(),
        'levels': levels,
        'alts': alts,
        'alarm': alarm,
        'unit': unit,
        'timerMin': timerMin,
        'modes': modes,
        'archived': archived,
        'start': start,
        'reason': reason,
        'finishedOn': finishedOn,
      };

  factory Habit.fromJson(Map<String, dynamic> j) {
    final lv = (j['levels'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {};
    return Habit(
      id: j['id'] as String,
      name: (j['name'] as String?) ?? '',
      emoji: (j['emoji'] as String?) ?? '✅',
      time: (j['time'] as String?) ?? '',
      context: (j['context'] as String?) ?? '',
      color: (j['color'] as String?) ?? '#E3F7E8',
      repeat: RepeatRule.fromJson((j['repeat'] as Map?)?.cast<String, dynamic>()),
      levels: {'mini': '', 'plus': '', 'max': '', ...lv},
      alts: ((j['alts'] as List?) ?? const []).map((e) => '$e').toList(),
      alarm: (j['alarm'] as String?) ?? '',
      unit: (j['unit'] as String?) ?? '',
      timerMin: (j['timerMin'] as num?)?.toInt() ?? 0,
      modes: ((j['modes'] as List?) ?? const []).map((e) => '$e').toList(),
      archived: (j['archived'] as bool?) ?? false,
      start: j['start'] as String,
      reason: (j['reason'] as String?) ?? '',
      finishedOn: j['finishedOn'] as String?,
    );
  }
}
