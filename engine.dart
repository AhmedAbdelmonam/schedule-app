import 'prayer.dart';

const dayNames = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
const anchorNames = {
  'fajr': 'الفجر', 'sunrise': 'الشروق', 'dhuhr': 'الظهر',
  'asr': 'العصر', 'maghrib': 'المغرب', 'isha': 'العشاء',
};
const prayerLen = 25; // minutes blocked for each prayer

class Task {
  String id, name;
  List<int> days; // 0=Saturday .. 6=Friday
  String? anchor; // null = fixed clock time
  int offset; // minutes after anchor, or minutes after midnight when fixed
  int dur;
  Task(this.id, this.name, this.days, this.anchor, this.offset, this.dur);

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'days': days, 'anchor': anchor, 'offset': offset, 'dur': dur};
  factory Task.fromJson(Map<String, dynamic> j) => Task(j['id'], j['name'],
      List<int>.from(j['days']), j['anchor'], j['offset'], j['dur']);

  int startOn(Map<String, int> p) => anchor == null ? offset : p[anchor]! + offset;
}

class Block {
  final String name;
  final int start, end;
  final bool prayer;
  final Task? task;
  Block(this.name, this.start, this.end, this.prayer, this.task);
}

DateTime dateForDay(int d) {
  final wd = [6, 7, 1, 2, 3, 4, 5][d];
  var t = DateTime.now();
  while (t.weekday != wd) { t = t.add(const Duration(days: 1)); }
  return t;
}

List<Block> blocksFor(int day, List<Task> tasks) {
  final p = prayerTimes(dateForDay(day));
  final out = <Block>[];
  for (final k in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
    out.add(Block(anchorNames[k]!, p[k]!, p[k]! + prayerLen, true, null));
  }
  for (final t in tasks.where((t) => t.days.contains(day))) {
    final s = t.startOn(p);
    out.add(Block(t.name, s, s + t.dur, false, t));
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// Returns a rejection message, or null if [t] can be saved (no overlap on any of its days).
String? conflict(Task t, List<Task> all) {
  if (t.name.trim().isEmpty) return 'اكتب اسم المهمة';
  if (t.days.isEmpty) return 'اختر يومًا واحدًا على الأقل';
  if (t.dur <= 0) return 'المدة يجب أن تكون أكبر من صفر';
  final others = all.where((x) => x.id != t.id).toList();
  for (final d in t.days) {
    final s = t.startOn(prayerTimes(dateForDay(d)));
    if (s < 0 || s + t.dur > 1440) return '${dayNames[d]}: المهمة تخرج عن حدود اليوم';
    for (final b in blocksFor(d, others)) {
      if (s < b.end && b.start < s + t.dur) {
        return '${dayNames[d]}: تتعارض مع "${b.name}" (${fmt(b.start)} – ${fmt(b.end)})';
      }
    }
  }
  return null;
}

String fmt(int m) {
  final h = (m ~/ 60) % 24, mi = m % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${mi.toString().padLeft(2, '0')} ${h < 12 ? 'ص' : 'م'}';
}
