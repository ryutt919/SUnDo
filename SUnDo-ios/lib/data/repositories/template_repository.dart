import '../../domain/models/date_key.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/id.dart';
import '../../domain/models/repeat_rule.dart';

class TemplateCategory {
  const TemplateCategory(this.title, this.emoji, this.habits);
  final String title;
  final String emoji;
  final List<Habit> habits;
}

/// 추천 루틴 템플릿. 앱에 내장된 고정 목록이다.
class TemplateRepository {
  List<TemplateCategory> categories() {
    Habit h(String name, String emoji, {String time = '', String context = '', int color = 3, RepeatRule? repeat, String mini = '', String plus = '', String max = ''}) =>
        Habit(
          id: newId(),
          name: name,
          emoji: emoji,
          time: time,
          context: context,
          color: habitColors[color],
          repeat: repeat ?? const RepeatRule(),
          levels: {'mini': mini, 'plus': plus, 'max': max},
          start: todayKey(),
        );
    const weekdays = RepeatRule(type: RepeatType.weekdays, days: [1, 2, 3, 4, 5]);
    return [
      TemplateCategory('아침 루틴', '🌅', [
        h('기상 후 물 한 잔', '💧', context: '기상 직후', color: 4),
        h('이부자리 정리', '🛏️', context: '일어나서', color: 7),
        h('아침 스트레칭', '🧘', time: '07:10', mini: '1분', plus: '5분', max: '15분'),
        h('아침 식사', '🍳', time: '08:00', color: 1),
      ]),
      TemplateCategory('건강', '💪', [
        h('걷기 8000보', '🚶', context: '퇴근길에', color: 3),
        h('운동 30분', '🏃', repeat: const RepeatRule(type: RepeatType.weekly, times: 3), mini: '스트레칭', plus: '30분', max: '1시간'),
        h('비타민 챙겨 먹기', '💊', context: '점심 먹고', color: 1),
        h('물 2리터 마시기', '🚰', color: 4),
        h('11시 전에 잠들기', '😴', time: '23:00', color: 5),
      ]),
      TemplateCategory('공부와 성장', '📚', [
        h('독서 10쪽', '📖', time: '22:00', color: 5),
        h('외국어 20분', '🔤', repeat: weekdays, color: 2),
        h('오전 20분 성장 시간', '🌱', time: '09:00', repeat: weekdays),
        h('관심 분야 콘텐츠 1개 읽기', '📰', context: '출근길에', color: 4),
      ]),
      TemplateCategory('마음 챙기기', '🌿', [
        h('감사한 일 한 줄', '🙏', time: '21:30', color: 6),
        h('명상 5분', '🧠', time: '07:30', mini: '1분', plus: '5분', max: '15분', color: 5),
        h('컨디션 체크', '📝', context: '자기 전에', color: 7),
        h('SNS 줄이기', '📵', color: 0),
      ]),
      TemplateCategory('정리와 살림', '🏠', [
        h('설거지 바로 하기', '🍽️', context: '식사 후에', color: 4),
        h('5분 정리', '🧹', time: '20:00', color: 7),
        h('내일 할 일 적기', '✍️', time: '22:30', color: 2),
        h('가계부 쓰기', '💰', time: '22:00', repeat: const RepeatRule(type: RepeatType.weekly, times: 5)),
      ]),
    ];
  }
}
