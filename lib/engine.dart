import 'prayer.dart';

const dayNames = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
const dayShort = ['سبت', 'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'];
const anchorNames = {'fajr': 'الفجر', 'sunrise': 'الشروق', 'dhuhr': 'الظهر', 'asr': 'العصر', 'maghrib': 'المغرب', 'isha': 'العشاء'};
const prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
const prayerLen = 25;
Map<String, int> adj = {};
Map<String, List<String>> done = {};
Map<String, String> notes = {};
List<String> modes = ['عادي'];
String curMode = 'عادي';

Map<String, int> times(DateTime d) {
  final p = prayerTimes(d);
  return {for (final e in p.entries) e.key: e.value + (adj[e.key] ?? 0)};
}

int dayIdx(DateTime d) => (d.weekday + 1) % 7;
bool weekA(DateTime d) =>
    (DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2026, 11, 28)).inDays / 7).floor().isEven;
String dkey(DateTime d) => '${d.year}-${d.month}-${d.day}';
String fmt(int m) {
  final h = (m ~/ 60) % 24, mi = m % 60;
  return '${h % 12 == 0 ? 12 : h % 12}:${mi.toString().padLeft(2, '0')} ${h < 12 ? 'ص' : 'م'}';
}

class Task {
  String id, name, note, mode;
  List<int> days;
  String? anchor;
  int offset, dur, bi; // bi: 0 every week, 1 week A only, 2 week B only
  bool over; // may overlap prayer blocks (e.g. college)
  Task(this.id, this.name, this.days, this.anchor, this.offset, this.dur, {this.note = '', this.bi = 0, this.over = false, this.mode = ''});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'days': days, 'anchor': anchor, 'offset': offset, 'dur': dur, 'note': note, 'bi': bi, 'over': over, 'mode': mode};
  factory Task.fromJson(Map<String, dynamic> j) => Task(j['id'], j['name'], List<int>.from(j['days']), j['anchor'], j['offset'], j['dur'],
      note: j['note'] ?? '', bi: j['bi'] ?? 0, over: j['over'] ?? false, mode: j['mode'] ?? '');
  int startOn(Map<String, int> p) => anchor == null ? offset : p[anchor]! + offset;
  bool occursOn(DateTime d) => (mode.isEmpty || mode == curMode) && days.contains(dayIdx(d)) && (bi == 0 || (bi == 1) == weekA(d));
}

class Block {
  final String name;
  final int start, end;
  final bool prayer;
  final Task? task;
  Block(this.name, this.start, this.end, this.prayer, this.task);
}

List<Block> blocksFor(DateTime date, List<Task> ts) {
  final p = times(date);
  final out = <Block>[for (final k in prayerKeys) Block('صلاة ${anchorNames[k]}', p[k]!, p[k]! + prayerLen, true, null)];
  for (final t in ts.where((t) => t.occursOn(date))) {
    final s = t.startOn(p);
    out.add(Block(t.name, s, s + t.dur, false, t));
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

bool _ov(int a, int b, int c, int d) => a < d && c < b;
DateTime _day(int i) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + i);
}

String? conflict(Task t, List<Task> all) {
  if (t.name.trim().isEmpty) return 'اكتب اسم المهمة';
  if (t.days.isEmpty) return 'اختر يومًا واحدًا على الأقل';
  if (t.dur <= 0) return 'المدة يجب أن تكون أكبر من صفر';
  final others = all.where((x) => x.id != t.id).toList();
  for (var i = 0; i < 14; i++) {
    final d = _day(i);
    if (!t.occursOn(d)) continue;
    final s = t.startOn(times(d));
    if (s < 0 || s + t.dur > 1440) return '${dayNames[dayIdx(d)]}: المهمة تخرج عن حدود اليوم';
    for (final b in blocksFor(d, others)) {
      if (b.prayer && t.over) continue;
      if (_ov(s, s + t.dur, b.start, b.end)) return '${dayNames[dayIdx(d)]}: تتعارض مع "${b.name}" (${fmt(b.start)} – ${fmt(b.end)})';
    }
  }
  return null;
}

/// New offset (same anchor) that moves [t] to the nearest free slot on its first conflicting day.
int? suggestOffset(Task t, List<Task> all) {
  final others = all.where((x) => x.id != t.id).toList();
  for (var i = 0; i < 14; i++) {
    final d = _day(i);
    if (!t.occursOn(d)) continue;
    final s0 = t.startOn(times(d));
    final bl = blocksFor(d, others).where((b) => !(b.prayer && t.over)).toList();
    if (!bl.any((b) => _ov(s0, s0 + t.dur, b.start, b.end))) continue;
    for (var s = s0; s + t.dur <= 1440; s += 5) {
      if (!bl.any((b) => _ov(s, s + t.dur, b.start, b.end))) return t.offset + s - s0;
    }
    return null;
  }
  return null;
}

List<String> findConflicts(List<Task> ts) {
  final out = <String>{};
  for (var i = 0; i < 14; i++) {
    final d = _day(i), bl = blocksFor(d, ts);
    for (var a = 0; a < bl.length; a++) {
      for (var b = a + 1; b < bl.length; b++) {
        final x = bl[a], y = bl[b];
        if (x.prayer && y.prayer) continue;
        if ((x.prayer && y.task!.over) || (y.prayer && x.task!.over)) continue;
        if (_ov(x.start, x.end, y.start, y.end)) out.add('${dayNames[dayIdx(d)]}: ${x.name} × ${y.name}');
      }
    }
  }
  return out.toList();
}

// ---- stats ----
List<Task> _planned(DateTime d, List<Task> ts) => ts.where((t) => !t.over && t.name != 'نوم' && t.occursOn(d)).toList();
bool isDone(DateTime d, Task t) => done[dkey(d)]?.contains(t.id) ?? false;
double? dayRate(DateTime d, List<Task> ts) {
  final p = _planned(d, ts);
  return p.isEmpty ? null : p.where((t) => isDone(d, t)).length / p.length;
}

List<String> insights(List<Task> ts) {
  final today = _day(0), out = <String>[];
  final days = [for (var i = 6; i >= 0; i--) _day(-i)];
  final rates = <DateTime, double>{for (final d in days) if (dayRate(d, ts) != null) d: dayRate(d, ts)!};
  if (rates.length >= 2) {
    final best = rates.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final worst = rates.entries.reduce((a, b) => a.value <= b.value ? a : b);
    out.add('أفضل يوم: ${dayNames[dayIdx(best.key)]} (${(best.value * 100).round()}%)');
    if (worst.key != best.key) out.add('أضعف يوم: ${dayNames[dayIdx(worst.key)]} (${(worst.value * 100).round()}%)');
  }
  final plan = <String, int>{}, dn = <String, int>{};
  for (final d in days) {
    for (final t in _planned(d, ts)) {
      plan[t.name] = (plan[t.name] ?? 0) + 1;
      if (isDone(d, t)) dn[t.name] = (dn[t.name] ?? 0) + 1;
    }
  }
  String? weak;
  var wr = 0.6;
  plan.forEach((n, c) {
    final r = (dn[n] ?? 0) / c;
    if (c >= 2 && r < wr) { wr = r; weak = n; }
  });
  if (weak != null) out.add('أكثر مهمة تتأخر فيها: $weak (${dn[weak] ?? 0} من ${plan[weak]})');
  String? sn;
  var sv = 2;
  for (final t in ts.where((t) => !t.over && t.name != 'نوم')) {
    var s = 0;
    for (var i = 0; i < 30; i++) {
      final d = _day(-i);
      if (!t.occursOn(d)) continue;
      if (isDone(d, t)) { s++; } else if (i == 0) { continue; } else { break; }
    }
    if (s > sv) { sv = s; sn = t.name; }
  }
  if (sn != null) out.add('أطول سلسلة التزام: $sn — $sv أيام متتالية');
  final rem = _planned(today, ts).where((t) => !isDone(today, t)).length;
  if (rem > 0) out.add('متبقي لك اليوم: $rem مهمة');
  return out;
}

// name|days(0=Sat..6=Fri)|anchor or -|offset|dur|bi|over|note
const _seed = [
  'قيام الليل|0123456|fajr|-60|55|0|0|',
  'أذكار الصباح|0123456|fajr|25|10|0|0|',
  'الحفظ|0123456|fajr|40|30|0|0|',
  'علم شرعي (1)|02345|fajr|70|75|0|0|',
  'فطور|02345|fajr|145|25|0|0|',
  'دراسة الكلية|02345|fajr|170|60|0|0|',
  'الجيم: دفع (صدر، كتف، ترايسبس)|0|fajr|235|125|0|0|الطريق: درس صوتي — أثناء الحديد: تلاوة مسموعة — العودة: مراجعة الحفظ',
  'الجيم: سحب (ظهر، باي) + بطن|2|fajr|235|125|0|0|الطريق: درس صوتي — أثناء الحديد: تلاوة مسموعة — العودة: مراجعة الحفظ',
  'الجيم: كارديو + إطالات|3|fajr|235|125|0|0|أثناء الكارديو: كتاب مسموع أو درس فقه — الإطالات: استغفار',
  'الجيم: أرجل|4|fajr|235|125|0|0|الطريق: درس صوتي — أثناء الحديد: تلاوة مسموعة',
  'الجيم: كارديو خفيف + إطالات|5|fajr|235|125|0|0|أثناء الكارديو: كتاب مسموع',
  'استحمام + وجبة بعد التمرين|02345|fajr|360|35|0|0|',
  'الكلية|02|-|780|180|0|1|العصر في استراحة المحاضرات',
  'الكلية|1|-|480|300|0|1|الظهر في استراحة المحاضرات',
  'دراسة الكلية|1|fajr|70|55|0|0|',
  'علم شرعي (2)|345|dhuhr|85|85|0|0|',
  'غداء|345|dhuhr|30|30|0|0|',
  'قيلولة|345|dhuhr|60|20|0|0|',
  'أذكار المساء|0123456|asr|25|15|0|0|',
  'علم شرعي (3)|1234|asr|45|90|0|0|',
  'علم شرعي (3)|5|asr|45|50|0|0|',
  'ورد القرآن (جزء)|012346|maghrib|30|40|0|0|',
  'ورد القرآن (جزء)|5|maghrib|30|40|2|0|',
  'ورد القرآن (جزء)|5|asr|95|40|1|0|',
  'الجولة الدعوية|5|maghrib|25|55|1|0|',
  'تسميع القرآن|15|isha|30|60|0|0|',
  'مجلس القراءة|3|isha|30|60|0|0|',
  'علم شرعي (4)|4|isha|30|60|0|0|',
  'علم شرعي (2): مراجعة وتلخيص|02|isha|75|55|0|0|',
  'صلة الرحم (زيارة أو اتصالات)|5|isha|95|85|0|0|',
  'ترفيه يومي|01234|-|1230|30|0|0|',
  'تجهيز النوم|012346|-|1260|55|0|0|',
  'تجهيز النوم|5|-|1275|40|0|0|',
  'نوم|0123456|-|1320|120|0|0|حتى 4:00 فجرًا',
  'علم شرعي يسير|6|fajr|70|60|0|0|',
  'سورة الكهف|6|fajr|130|30|0|0|',
  'الجمعة|6|-|675|65|0|1|',
  'ترفيه الأسبوع|6|-|800|145|0|0|',
  'وقت أسري أو مع الأصحاب|6|-|1200|60|0|0|',
];

List<Task> seedTasks() {
  var i = 0;
  return _seed.map((s) {
    final p = s.split('|');
    return Task('s${i++}', p[0], p[1].split('').map(int.parse).toList(), p[2] == '-' ? null : p[2], int.parse(p[3]), int.parse(p[4]),
        bi: int.parse(p[5]), over: p[6] == '1', note: p[7], mode: 'عادي');
  }).toList();
}
