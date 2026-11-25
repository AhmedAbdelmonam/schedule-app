import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'adhan_flag.dart';
import 'engine.dart';
import 'notif.dart';
import 'widget.dart';

const green = Color(0xFF1F7A5C);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    title: 'جدولي',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: green, useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF6F4EF)),
    locale: const Locale('ar'),
    builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
    home: const Home(),
  ));
}

Color colorFor(String n) {
  if (n.contains('الكلية') || n.contains('دراسة')) return const Color(0xFF6A4FB3);
  if (n.contains('علم') || n.contains('مجلس')) return const Color(0xFF2F6FB0);
  if (n.contains('الجيم')) return const Color(0xFFD9822B);
  if (n.contains('ترفيه') || n.contains('أسري')) return const Color(0xFFC2456B);
  if (n.contains('غداء') || n.contains('فطور') || n.contains('استحمام')) return const Color(0xFFB59A3C);
  if (n.contains('صلة')) return const Color(0xFF1F9AA0);
  if (n == 'نوم' || n.contains('تجهيز') || n.contains('قيلولة')) return Colors.blueGrey;
  return green;
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Task> tasks = [];
  int tab = 0;
  bool adhanOn = true;
  DateTime date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('tasks');
    final d = p.getString('done'), a = p.getString('adj');
    done = d == null ? {} : (jsonDecode(d) as Map).map((k, v) => MapEntry(k as String, List<String>.from(v)));
    adj = a == null ? {} : Map<String, int>.from(jsonDecode(a));
    adhanOn = p.getBool('adhan') ?? true;
    final nt = p.getString('notes');
    notes = nt == null ? {} : Map<String, String>.from(jsonDecode(nt));
    modes = p.getStringList('modes') ?? ['عادي'];
    curMode = p.getString('mode') ?? 'عادي';
    setState(() => tasks = raw == null ? seedTasks() : (jsonDecode(raw) as List).map((e) => Task.fromJson(e)).toList());
    try { await initNotif(); await reschedule(tasks, adhanOn); } catch (_) {}
    try { await pushWidget(tasks); } catch (_) {}
  }

  Future<void> _save({bool resched = true}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('tasks', jsonEncode(tasks.map((t) => t.toJson()).toList()));
    await p.setString('done', jsonEncode(done));
    await p.setString('adj', jsonEncode(adj));
    await p.setBool('adhan', adhanOn);
    await p.setString('notes', jsonEncode(notes));
    await p.setStringList('modes', modes);
    await p.setString('mode', curMode);
    try { await pushWidget(tasks); } catch (_) {}
    if (resched) { try { await reschedule(tasks, adhanOn); } catch (_) {} }
  }

  Future<void> _edit(Task? old) async {
    final res = await showDialog<Task?>(context: context, builder: (_) => TaskDialog(old: old, all: tasks, date: date));
    if (res == null) return;
    setState(() {
      tasks.removeWhere((t) => t.id == res.id);
      if (res.name != '\u0000') tasks.add(res);
    });
    _save();
  }

  void _toggle(DateTime d, Task t) {
    setState(() {
      final l = done.putIfAbsent(dkey(d), () => []);
      l.contains(t.id) ? l.remove(t.id) : l.add(t.id);
    });
    _save(resched: false);
  }

  Future<void> _noteDialog() async {
    final c = TextEditingController(text: notes[dkey(date)] ?? '');
    final r = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
            title: const Text('ملاحظة اليوم'),
            content: TextField(controller: c, maxLines: 4, autofocus: true),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('حفظ')),
            ]));
    if (r == null) return;
    setState(() {
      if (r.isEmpty) {
        notes.remove(dkey(date));
      } else {
        notes[dkey(date)] = r;
      }
    });
    _save(resched: false);
  }

  Future<void> _newMode() async {
    final c = TextEditingController();
    final r = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
            title: const Text('نمط جديد'),
            content: TextField(controller: c, decoration: const InputDecoration(labelText: 'الاسم (مثل: اختبارات، رمضان)')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('إنشاء')),
            ]));
    if (r == null || r.isEmpty || modes.contains(r)) return;
    setState(() {
      final copy = tasks
          .where((t) => t.mode == curMode)
          .map((t) => Task(DateTime.now().microsecondsSinceEpoch.toString() + t.id, t.name, [...t.days], t.anchor, t.offset, t.dur,
              note: t.note, bi: t.bi, over: t.over, mode: r))
          .toList();
      tasks.addAll(copy);
      modes.add(r);
      curMode = r;
    });
    _save();
  }

  Widget _row(DateTime d, Block b) {
    final t = b.task;
    final c = b.prayer ? green : colorFor(b.name);
    final dn = t != null && isDone(d, t);
    return Opacity(
      opacity: dn ? .55 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 62, child: Padding(padding: const EdgeInsets.only(top: 8),
              child: Text(b.prayer ? fmt(b.start) : '${fmt(b.start)}\n${fmt(b.end)}', style: const TextStyle(fontSize: 11, color: Colors.black54)))),
          Expanded(
            child: InkWell(
              onTap: t == null ? null : () => _edit(t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: b.prayer ? const Color(0xFFE3F1EA) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border(right: BorderSide(color: c, width: 4))),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    if (t != null && t.note.isNotEmpty) Text(t.note, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    if (t != null && t.bi != 0) Text(t.bi == 1 ? 'الأسبوع الأول فقط' : 'الأسبوع الثاني فقط', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ])),
                  if (t != null && t.name != 'نوم') Checkbox(value: dn, onChanged: (_) => _toggle(d, t)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _today() {
    final now = DateTime.now(), nm = now.hour * 60 + now.minute;
    final isToday = dkey(date) == dkey(now);
    final bl = blocksFor(date, tasks);
    Block? cur, np;
    if (isToday) {
      for (final b in bl) {
        if (cur == null && b.start <= nm && nm < b.end && !(b.task?.name == 'نوم')) cur = b;
        if (np == null && b.prayer && b.start > nm) np = b;
      }
    }
    final cf = findConflicts(tasks);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('${dayNames[dayIdx(date)]}، ${date.day}/${date.month}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      SizedBox(height: 56, child: ListView(scrollDirection: Axis.horizontal, children: [
        for (var i = 0; i < 7; i++) Builder(builder: (_) {
          final d = DateTime(now.year, now.month, now.day + i);
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
              child: ChoiceChip(label: Text(dayShort[dayIdx(d)]), selected: dkey(d) == dkey(date), onSelected: (_) => setState(() => date = d)));
        })
      ])),
      if (cf.isNotEmpty)
        Card(color: const Color(0xFFFBE9E7), child: ListTile(
            leading: const Icon(Icons.warning_amber, color: Color(0xFF8A2418)),
            title: Text('تعارض في ${cf.length} موضع بعد تغير المواقيت', style: const TextStyle(color: Color(0xFF8A2418), fontSize: 13)),
            onTap: () => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('تحتاج مراجعة'), content: SingleChildScrollView(child: Text(cf.join('\n'))))))),
      if (isToday)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF17352B), borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('الآن', style: TextStyle(color: Colors.white70, fontSize: 12)),
              if (np != null) Text('${np.name} بعد ${np.start - nm} د', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            Text(cur?.name ?? 'لا توجد مهمة الآن', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
            if (cur != null) ...[
              Text('${fmt(cur.start)} – ${fmt(cur.end)} · متبقي ${cur.end - nm} د', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: ((nm - cur.start) / (cur.end - cur.start)).clamp(0.0, 1.0), color: const Color(0xFF7BD3A8), backgroundColor: Colors.white24),
            ],
          ]),
        ),
      Card(child: ListTile(
          leading: const Icon(Icons.edit_note, color: green),
          title: Text((notes[dkey(date)] ?? '').isNotEmpty ? notes[dkey(date)]! : 'ملاحظة اليوم', style: TextStyle(fontSize: 13, color: (notes[dkey(date)] ?? '').isNotEmpty ? null : Colors.black54)),
          onTap: _noteDialog)),
      for (final b in bl) _row(date, b),
    ]);
  }

  Widget _week() {
    final now = DateTime.now();
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (var i = 0; i < 7; i++) Builder(builder: (_) {
        final d = DateTime(now.year, now.month, now.day + i);
        final bl = blocksFor(d, tasks).where((b) => !b.prayer && b.name != 'نوم').toList();
        return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(onTap: () => setState(() { date = d; tab = 0; }),
              child: Text('${dayNames[dayIdx(d)]} ${d.day}/${d.month}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          const SizedBox(height: 6),
          for (final b in bl) InkWell(onTap: () => _edit(b.task),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
                Container(width: 4, height: 14, color: colorFor(b.name)),
                const SizedBox(width: 8),
                SizedBox(width: 64, child: Text(fmt(b.start), style: const TextStyle(fontSize: 11, color: Colors.black54))),
                Expanded(child: Text(b.name, style: const TextStyle(fontSize: 12.5))),
              ]))),
        ])));
      })
    ]);
  }

  Widget _stats() {
    final now = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
    final rs = [for (final d in days) dayRate(d, tasks)];
    final valid = rs.whereType<double>().toList();
    final avg = valid.isEmpty ? 0.0 : valid.reduce((a, b) => a + b) / valid.length;
    final today = dayRate(days.last, tasks) ?? 0.0;
    final ins = insights(tasks);
    Widget big(String t, double v) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          Text('${(v * 100).round()}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: green)),
          Text(t, style: const TextStyle(fontSize: 12))]))));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [big('إنجاز اليوم', today), big('متوسط آخر 7 أيام', avg)]),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: SizedBox(height: 110, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < 7; i++) Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Container(height: 70 * (rs[i] ?? 0) + 2, margin: const EdgeInsets.symmetric(horizontal: 6), decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 4),
          Text(dayShort[dayIdx(days[i])], style: const TextStyle(fontSize: 10)),
        ]))])))),
      const Padding(padding: EdgeInsets.fromLTRB(4, 8, 4, 4), child: Text('ملاحظات ذكية', style: TextStyle(fontWeight: FontWeight.w700))),
      if (ins.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('علّم المهام المنجزة في شاشة اليوم لتظهر هنا ملاحظات.')),
      for (final s in ins) Card(child: ListTile(dense: true, leading: const Icon(Icons.lightbulb_outline, color: green), title: Text(s))),
    ]);
  }

  Widget _settings() => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('نمط الجدول', style: TextStyle(fontWeight: FontWeight.w700)),
        Wrap(spacing: 6, children: [for (final m in modes) ChoiceChip(label: Text(m), selected: curMode == m, onSelected: (_) { setState(() => curMode = m); _save(); })]),
        TextButton.icon(icon: const Icon(Icons.add), label: const Text('نمط جديد (نسخة من الحالي)'), onPressed: _newMode),
        const Divider(),
        const Text('تعديل المواقيت بالدقائق (المنصورة)', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final k in prayerKeys) ListTile(
          title: Text(anchorNames[k]!),
          subtitle: Text(fmt(times(DateTime.now())[k]!)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () { setState(() => adj[k] = (adj[k] ?? 0) - 1); _save(); }),
            Text('${adj[k] ?? 0}'),
            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () { setState(() => adj[k] = (adj[k] ?? 0) + 1); _save(); }),
          ]),
        ),
        SwitchListTile(
          title: const Text('تشغيل الأذان مع تنبيه الصلاة'),
          subtitle: Text(hasAdhan ? 'ملف الأذان الخاص بك مضاف' : 'لا يوجد ملف أذان مضاف (يستخدم صوت التنبيه العادي)'),
          value: adhanOn, onChanged: (v) { setState(() => adhanOn = v); _save(); }),
        ListTile(leading: const Icon(Icons.notifications_active), title: const Text('إعادة جدولة التنبيهات'), onTap: () async {
          try { await reschedule(tasks, adhanOn); } catch (_) {}
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الجدولة للأيام السبعة القادمة')));
        }),
        const Divider(),
        ListTile(leading: const Icon(Icons.upload), title: const Text('نسخ نسخة احتياطية إلى الحافظة'), onTap: () async {
          await Clipboard.setData(ClipboardData(text: jsonEncode({'tasks': tasks.map((t) => t.toJson()).toList(), 'done': done, 'adj': adj, 'notes': notes, 'modes': modes, 'mode': curMode})));
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ — الصقها في ملاحظة أو رسالة لنفسك')));
        }),
        ListTile(leading: const Icon(Icons.download), title: const Text('استيراد من الحافظة'), onTap: () async {
          final c = await Clipboard.getData('text/plain');
          try {
            final j = jsonDecode(c!.text!) as Map<String, dynamic>;
            setState(() {
              tasks = (j['tasks'] as List).map((e) => Task.fromJson(e)).toList();
              done = (j['done'] as Map).map((k, v) => MapEntry(k as String, List<String>.from(v)));
              adj = Map<String, int>.from(j['adj']);
              notes = Map<String, String>.from(j['notes'] ?? {});
              modes = List<String>.from(j['modes'] ?? ['عادي']);
              curMode = j['mode'] ?? 'عادي';
            });
            _save();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاستيراد')));
          } catch (_) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الحافظة لا تحتوي نسخة صالحة')));
          }
        }),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('جدولي'), backgroundColor: Colors.transparent),
        floatingActionButton: tab < 2 ? FloatingActionButton(onPressed: () => _edit(null), child: const Icon(Icons.add)) : null,
        body: [_today, _week, _stats, _settings][tab](),
        bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'اليوم'),
          NavigationDestination(icon: Icon(Icons.view_week), label: 'الأسبوع'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'الإحصائيات'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ]),
      );
}

class TaskDialog extends StatefulWidget {
  final Task? old;
  final List<Task> all;
  final DateTime date;
  const TaskDialog({super.key, this.old, required this.all, required this.date});
  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  late TextEditingController name, note, off, dur;
  String? anchor, error;
  late Set<int> days;
  int bi = 0;
  String mode = '';
  int? sugg;

  @override
  void initState() {
    super.initState();
    final o = widget.old;
    name = TextEditingController(text: o?.name ?? '');
    note = TextEditingController(text: o?.note ?? '');
    anchor = o?.anchor;
    off = TextEditingController(text: '${o?.offset ?? 600}');
    dur = TextEditingController(text: '${o?.dur ?? 30}');
    days = {...(o?.days ?? [dayIdx(widget.date)])};
    bi = o?.bi ?? 0;
    mode = o?.mode ?? curMode;
  }

  Task _build() => Task(widget.old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(), name.text.trim(), days.toList()..sort(), anchor,
      int.tryParse(off.text.trim()) ?? 0, int.tryParse(dur.text.trim()) ?? 0, note: note.text.trim(), bi: bi, over: widget.old?.over ?? false, mode: mode);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.old == null ? 'مهمة جديدة' : 'تعديل المهمة (يسري على كل أيامها)'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'نشاط مرافق / ملاحظة (لا يحجز وقتًا)')),
          DropdownButtonFormField<String?>(
            value: anchor,
            decoration: const InputDecoration(labelText: 'مرتبطة بـ'),
            items: [const DropdownMenuItem(value: null, child: Text('وقت ثابت')), for (final e in anchorNames.entries) DropdownMenuItem(value: e.key, child: Text('بعد ${e.value}'))],
            onChanged: (v) => setState(() => anchor = v),
          ),
          TextField(controller: off, keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(labelText: anchor == null ? 'الدقائق بعد منتصف الليل (600 = 10:00 ص)' : 'الدقائق بعد الصلاة (سالب = قبلها)')),
          TextField(controller: dur, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المدة بالدقائق')),
          DropdownButtonFormField<int>(
            value: bi,
            decoration: const InputDecoration(labelText: 'التكرار'),
            items: const [DropdownMenuItem(value: 0, child: Text('كل أسبوع')), DropdownMenuItem(value: 1, child: Text('أسبوع وأسبوع: الأسبوع الأول')), DropdownMenuItem(value: 2, child: Text('أسبوع وأسبوع: الأسبوع الثاني'))],
            onChanged: (v) => setState(() => bi = v ?? 0),
          ),
          DropdownButtonFormField<String>(
            value: mode,
            decoration: const InputDecoration(labelText: 'تظهر في'),
            items: [const DropdownMenuItem(value: '', child: Text('كل الأنماط')), DropdownMenuItem(value: curMode, child: Text('النمط: $curMode'))],
            onChanged: (v) => setState(() => mode = v ?? ''),
          ),
          Wrap(spacing: 4, children: [
            for (var i = 0; i < 7; i++) FilterChip(label: Text(dayShort[i]), selected: days.contains(i), onSelected: (s) => setState(() => s ? days.add(i) : days.remove(i))),
          ]),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.red))),
          if (sugg != null) OutlinedButton(onPressed: () => setState(() { off.text = '$sugg'; error = null; sugg = null; }), child: const Text('تطبيق أقرب وقت متاح')),
        ])),
        actions: [
          if (widget.old != null) TextButton(onPressed: () => Navigator.pop(context, Task(widget.old!.id, '\u0000', [], null, 0, 0)), child: const Text('حذف')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () {
                final t = _build();
                final err = conflict(t, widget.all);
                if (err != null) {
                  setState(() { error = 'مرفوض: $err'; sugg = suggestOffset(t, widget.all); });
                } else {
                  Navigator.pop(context, t);
                }
              },
              child: const Text('حفظ')),
        ],
      );
}
