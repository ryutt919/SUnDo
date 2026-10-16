/// 날짜를 'yyyy-MM-dd' 문자열로 다룬다. 웹앱 백업 JSON과 같은 형식이다.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String todayKey() => dateKey(DateTime.now());

String addDaysKey(String key, int n) {
  final d = parseDateKey(key);
  return dateKey(DateTime(d.year, d.month, d.day + n));
}

/// 월요일 시작 주의 첫날.
String weekStartKey(String key) {
  final d = parseDateKey(key);
  return addDaysKey(key, -(d.weekday - 1));
}

/// 일요일=0 ... 토요일=6 (웹앱과 같은 요일 번호).
int sundayZero(DateTime d) => d.weekday % 7;

int daysBetween(String fromKey, String toKey) {
  final a = parseDateKey(fromKey);
  final b = parseDateKey(toKey);
  return DateTime.utc(b.year, b.month, b.day)
      .difference(DateTime.utc(a.year, a.month, a.day))
      .inDays;
}

const koWeekdays = ['일', '월', '화', '수', '목', '금', '토'];
