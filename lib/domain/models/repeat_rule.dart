enum RepeatType { daily, weekdays, weekly, interval, monthDays }

extension RepeatTypeLabel on RepeatType {
  String get label => switch (this) {
        RepeatType.daily => '매일',
        RepeatType.weekdays => '요일 지정',
        RepeatType.weekly => '주 N회',
        RepeatType.interval => 'N일마다',
        RepeatType.monthDays => '매월 특정 날짜',
      };

  String get jsonName => switch (this) {
        RepeatType.monthDays => 'monthdays',
        _ => name,
      };
}

RepeatType _typeFromJson(String? s) => RepeatType.values.firstWhere(
      (t) => t.jsonName == s,
      orElse: () => RepeatType.daily,
    );

/// 습관 반복 규칙. 요일 번호는 일요일=0 ... 토요일=6.
class RepeatRule {
  const RepeatRule({
    this.type = RepeatType.daily,
    this.days = const [1, 2, 3, 4, 5],
    this.times = 3,
    this.every = 2,
    this.monthDays = const [1],
  });

  final RepeatType type;
  final List<int> days;
  final int times;
  final int every;
  final List<int> monthDays;

  RepeatRule copyWith({
    RepeatType? type,
    List<int>? days,
    int? times,
    int? every,
    List<int>? monthDays,
  }) =>
      RepeatRule(
        type: type ?? this.type,
        days: days ?? this.days,
        times: times ?? this.times,
        every: every ?? this.every,
        monthDays: monthDays ?? this.monthDays,
      );

  String get summary => switch (type) {
        RepeatType.daily => '매일',
        RepeatType.weekdays =>
          '매주 ${(List.of(days)..sort()).map((d) => '일월화수목금토'[d]).join(' ')}',
        RepeatType.weekly => '주 $times회',
        RepeatType.interval => '$every일마다',
        RepeatType.monthDays => '매월 ${monthDays.join(', ')}일',
      };

  Map<String, dynamic> toJson() => {
        'type': type.jsonName,
        'days': days,
        'times': times,
        'every': every,
        'monthDays': monthDays,
      };

  factory RepeatRule.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const RepeatRule();
    List<int> ints(Object? v, List<int> fallback) =>
        v is List ? v.map((e) => (e as num).toInt()).toList() : fallback;
    return RepeatRule(
      type: _typeFromJson(j['type'] as String?),
      days: ints(j['days'], const [1, 2, 3, 4, 5]),
      times: (j['times'] as num?)?.toInt() ?? 3,
      every: (j['every'] as num?)?.toInt() ?? 2,
      monthDays: ints(j['monthDays'], const [1]),
    );
  }
}
