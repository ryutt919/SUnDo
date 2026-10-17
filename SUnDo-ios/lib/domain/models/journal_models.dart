/// 하루 단위 루틴 기록.
class HabitLog {
  const HabitLog({
    this.done = false,
    this.level,
    this.alt = '',
    this.value,
    this.photo,
  });

  final bool done;
  final String? level; // 'mini' | 'plus' | 'max'
  final String alt; // 오늘 쓴 대체 이름
  final double? value; // 수치형 기록
  final String? photo; // 인증 사진 파일 경로

  HabitLog copyWith({
    bool? done,
    String? level,
    bool clearLevel = false,
    String? alt,
    double? value,
    bool clearValue = false,
    String? photo,
    bool clearPhoto = false,
  }) =>
      HabitLog(
        done: done ?? this.done,
        level: clearLevel ? null : (level ?? this.level),
        alt: alt ?? this.alt,
        value: clearValue ? null : (value ?? this.value),
        photo: clearPhoto ? null : (photo ?? this.photo),
      );

  Map<String, dynamic> toJson() => {
        'done': done,
        if (level != null) 'level': level,
        if (alt.isNotEmpty) 'alt': alt,
        if (value != null) 'value': value,
        if (photo != null) 'photo': photo,
      };

  factory HabitLog.fromJson(Map<String, dynamic> j) => HabitLog(
        done: (j['done'] as bool?) ?? false,
        level: (j['level'] as String?)?.isEmpty ?? true ? null : j['level'] as String,
        alt: (j['alt'] as String?) ?? '',
        value: j['value'] is num ? (j['value'] as num).toDouble() : null,
        photo: j['photo'] as String?,
      );
}

class RoutineMode {
  const RoutineMode({required this.id, required this.name});
  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory RoutineMode.fromJson(Map<String, dynamic> j) =>
      RoutineMode(id: j['id'] as String, name: j['name'] as String);
}

/// 날짜 순, 같은 날이면 시간이 있는 투두를 시간 순으로 앞에 두고 종일 투두를 뒤에 둔다.
/// 같은 조건이면 원래 순서를 지킨다.
List<Todo> sortTodos(Iterable<Todo> todos, {bool newestFirst = false}) {
  final indexed = todos.toList().asMap().entries.toList();
  indexed.sort((a, b) {
    var c = a.value.date.compareTo(b.value.date);
    if (newestFirst) c = -c;
    if (c != 0) return c;
    final ta = a.value.time, tb = b.value.time;
    if (ta.isNotEmpty && tb.isNotEmpty) {
      c = ta.compareTo(tb);
      if (c != 0) return c;
    } else if (ta.isNotEmpty != tb.isNotEmpty) {
      return ta.isNotEmpty ? -1 : 1;
    }
    return a.key.compareTo(b.key);
  });
  return [for (final e in indexed) e.value];
}

/// 투두의 날짜와 시간을 사람이 읽는 문구로. 시간이 없으면 날짜만(종일).
String todoWhenLabel(Todo t, {bool showDate = true}) {
  if (!t.hasTime) return t.date;
  return showDate ? '${t.date} ${t.time}' : t.time;
}

class Todo {
  const Todo({required this.id, required this.text, required this.date, this.done = false, this.time = ''});
  final String id;
  final String text;
  final String date;
  final bool done;
  final String time; // 'HH:mm' 또는 빈 문자열(종일)

  bool get hasTime => time.isNotEmpty;

  Todo copyWith({String? text, String? date, bool? done, String? time}) => Todo(
        id: id,
        text: text ?? this.text,
        date: date ?? this.date,
        done: done ?? this.done,
        time: time ?? this.time,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'date': date,
        'done': done,
        if (time.isNotEmpty) 'time': time,
      };
  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'] as String,
        text: (j['text'] as String?) ?? '',
        date: j['date'] as String,
        done: (j['done'] as bool?) ?? false,
        time: (j['time'] as String?) ?? '',
      );
}

class DayReview {
  const DayReview({this.mood = 0, this.best = '', this.msg = ''});
  final int mood; // 0은 미선택, 1~5
  final String best;
  final String msg;

  DayReview copyWith({int? mood, String? best, String? msg}) =>
      DayReview(mood: mood ?? this.mood, best: best ?? this.best, msg: msg ?? this.msg);

  bool get isEmpty => mood == 0 && best.isEmpty && msg.isEmpty;

  Map<String, dynamic> toJson() => {'mood': mood, 'best': best, 'msg': msg};
  factory DayReview.fromJson(Map<String, dynamic> j) => DayReview(
        mood: (j['mood'] as num?)?.toInt() ?? 0,
        best: (j['best'] as String?) ?? '',
        msg: (j['msg'] as String?) ?? '',
      );
}

enum MemoKind { short, long }

class Memo {
  const Memo({
    required this.id,
    required this.date,
    required this.kind,
    required this.text,
    this.hl = false,
  });
  final String id;
  final String date;
  final MemoKind kind;
  final String text;
  final bool hl; // 형광펜 표시

  Memo copyWith({String? text, bool? hl}) =>
      Memo(id: id, date: date, kind: kind, text: text ?? this.text, hl: hl ?? this.hl);

  Map<String, dynamic> toJson() =>
      {'id': id, 'date': date, 'kind': kind.name, 'text': text, 'hl': hl};
  factory Memo.fromJson(Map<String, dynamic> j) => Memo(
        id: j['id'] as String,
        date: j['date'] as String,
        kind: j['kind'] == 'long' ? MemoKind.long : MemoKind.short,
        text: (j['text'] as String?) ?? '',
        hl: (j['hl'] as bool?) ?? false,
      );
}

/// 주간/월간/연간 계획(목표).
enum GoalPeriod { week, month, year }

extension GoalPeriodLabel on GoalPeriod {
  String get label => switch (this) {
        GoalPeriod.week => '주간',
        GoalPeriod.month => '월간',
        GoalPeriod.year => '연간',
      };
}

class GoalItem {
  const GoalItem({required this.text, this.done = false});
  final String text;
  final bool done;
  GoalItem copyWith({String? text, bool? done}) =>
      GoalItem(text: text ?? this.text, done: done ?? this.done);
  Map<String, dynamic> toJson() => {'text': text, 'done': done};
  factory GoalItem.fromJson(Map<String, dynamic> j) =>
      GoalItem(text: (j['text'] as String?) ?? '', done: (j['done'] as bool?) ?? false);
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.period,
    required this.periodKey,
    this.items = const [],
    this.done = false,
  });
  final String id;
  final String title;
  final GoalPeriod period;

  /// 계획을 완료로 체크했는지. 세부 항목을 모두 끝내면 함께 완료가 된다.
  final bool done;

  /// 주간은 그 주 월요일(yyyy-MM-dd), 월간은 yyyy-MM, 연간은 yyyy.
  final String periodKey;
  final List<GoalItem> items;

  /// 완료한 계획은 항상 100%, 아니면 완료한 세부 항목의 비율.
  double get progress =>
      done ? 1 : (items.isEmpty ? 0 : items.where((i) => i.done).length / items.length);

  Goal copyWith({String? title, List<GoalItem>? items, bool? done}) => Goal(
      id: id,
      title: title ?? this.title,
      period: period,
      periodKey: periodKey,
      items: items ?? this.items,
      done: done ?? this.done);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'period': period.name,
        'periodKey': periodKey,
        'items': items.map((e) => e.toJson()).toList(),
        'done': done,
      };
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        period: GoalPeriod.values.firstWhere((p) => p.name == j['period'],
            orElse: () => GoalPeriod.week),
        periodKey: j['periodKey'] as String,
        items: ((j['items'] as List?) ?? const [])
            .map((e) => GoalItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        done: (j['done'] as bool?) ?? false,
      );
}

class AppSettings {
  const AppSettings({
    this.theme = 'auto',
    this.doneToBottom = true,
    this.rolling = true,
    this.sortByTime = false,
    this.morningAlarm = '',
    this.eveningAlarm = '',
  });
  final String theme; // auto | light | dark
  final bool doneToBottom;
  final bool rolling;
  final bool sortByTime; // 홈 목록을 시각 순서로 보기
  final String morningAlarm; // 'HH:mm', 빈 문자열이면 끔
  final String eveningAlarm;

  AppSettings copyWith({
    String? theme,
    bool? doneToBottom,
    bool? rolling,
    bool? sortByTime,
    String? morningAlarm,
    String? eveningAlarm,
  }) =>
      AppSettings(
        theme: theme ?? this.theme,
        doneToBottom: doneToBottom ?? this.doneToBottom,
        rolling: rolling ?? this.rolling,
        sortByTime: sortByTime ?? this.sortByTime,
        morningAlarm: morningAlarm ?? this.morningAlarm,
        eveningAlarm: eveningAlarm ?? this.eveningAlarm,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'doneToBottom': doneToBottom,
        'rolling': rolling,
        'sortByTime': sortByTime,
        'morningAlarm': morningAlarm,
        'eveningAlarm': eveningAlarm,
      };
  factory AppSettings.fromJson(Map<String, dynamic>? j) => j == null
      ? const AppSettings()
      : AppSettings(
          theme: (j['theme'] as String?) ?? 'auto',
          doneToBottom: (j['doneToBottom'] as bool?) ?? true,
          rolling: (j['rolling'] as bool?) ?? true,
          sortByTime: (j['sortByTime'] as bool?) ?? false,
          morningAlarm: (j['morningAlarm'] as String?) ?? '',
          eveningAlarm: (j['eveningAlarm'] as String?) ?? '',
        );
}
