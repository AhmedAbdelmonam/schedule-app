import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'engine.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'جدولي',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2E7D5B), useMaterial3: true),
        locale: const Locale('ar'),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Task> tasks = [];
  int day = (DateTime.now().weekday + 1) % 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('tasks');
    final all = [0, 1, 2, 3, 4, 5, 6];
    setState(() => tasks = raw == null
        ? [
            Task('1', 'قيام الليل', all, 'fajr', -60, 55),
            Task('2', 'الحفظ', all, 'fajr', 40, 30),
            Task('3', 'ورد القرآن', all, 'maghrib', 30, 40),
            Task('4', 'ترفيه يومي', all, null, 1230, 30),
          ]
        : (jsonDecode(raw) as List).map((e) => Task.fromJson(e)).toList());
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('tasks', jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  Future<void> _edit(Task? old) async {
    final res = await showDialog<Task?>(
        context: context, builder: (_) => TaskDialog(old: old, all: tasks, day: day));
    if (res == null) return;
    setState(() {
      tasks.removeWhere((t) => t.id == res.id);
      if (!res.name.startsWith('\u0000')) tasks.add(res);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final blocks = blocksFor(day, tasks);
    return Scaffold(
      appBar: AppBar(title: const Text('جدولي — المنصورة')),
      floatingActionButton:
          FloatingActionButton(onPressed: () => _edit(null), child: const Icon(Icons.add)),
      body: Column(children: [
        SizedBox(
          height: 56,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i < 7; i++)
              Padding(
                padding: const EdgeInsets.all(6),
                child: ChoiceChip(
                    label: Text(dayNames[i]),
                    selected: day == i,
                    onSelected: (_) => setState(() => day = i)),
              )
          ]),
        ),
        Expanded(
          child: ListView(children: [
            for (final b in blocks)
              ListTile(
                tileColor: b.prayer ? Colors.green.shade50 : null,
                leading: Text('${fmt(b.start)}\n${fmt(b.end)}', style: const TextStyle(fontSize: 12)),
                title: Text(b.prayer ? 'صلاة ${b.name}' : b.name),
                onTap: b.task == null ? null : () => _edit(b.task),
              ),
          ]),
        ),
      ]),
    );
  }
}

class TaskDialog extends StatefulWidget {
  final Task? old;
  final List<Task> all;
  final int day;
  const TaskDialog({super.key, this.old, required this.all, required this.day});
  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  late TextEditingController name, off, dur;
  String? anchor;
  late Set<int> days;
  String? error;

  @override
  void initState() {
    super.initState();
    final o = widget.old;
    name = TextEditingController(text: o?.name ?? '');
    anchor = o?.anchor;
    off = TextEditingController(text: '${o?.offset ?? 600}');
    dur = TextEditingController(text: '${o?.dur ?? 30}');
    days = {...(o?.days ?? [widget.day])};
  }

  Task _build() => Task(widget.old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name.text.trim(), days.toList()..sort(), anchor,
      int.tryParse(off.text.trim()) ?? 0, int.tryParse(dur.text.trim()) ?? 0);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.old == null ? 'مهمة جديدة' : 'تعديل المهمة'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
            DropdownButtonFormField<String?>(
              value: anchor,
              decoration: const InputDecoration(labelText: 'مرتبطة بـ'),
              items: [
                const DropdownMenuItem(value: null, child: Text('وقت ثابت')),
                for (final e in anchorNames.entries)
                  DropdownMenuItem(value: e.key, child: Text('بعد ${e.value}')),
              ],
              onChanged: (v) => setState(() => anchor = v),
            ),
            TextField(
                controller: off,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: InputDecoration(
                    labelText: anchor == null
                        ? 'الدقائق بعد منتصف الليل (مثال 600 = 10:00 ص)'
                        : 'الدقائق بعد الصلاة (سالب = قبلها)')),
            TextField(
                controller: dur,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المدة بالدقائق')),
            Wrap(spacing: 4, children: [
              for (var i = 0; i < 7; i++)
                FilterChip(
                    label: Text(dayNames[i]),
                    selected: days.contains(i),
                    onSelected: (s) => setState(() => s ? days.add(i) : days.remove(i))),
            ]),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red))),
          ]),
        ),
        actions: [
          if (widget.old != null)
            TextButton(
                onPressed: () => Navigator.pop(
                    context, Task(widget.old!.id, '\u0000', [], null, 0, 0)),
                child: const Text('حذف')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () {
                final t = _build();
                final err = conflict(t, widget.all);
                if (err != null) {
                  setState(() => error = 'مرفوض: $err');
                } else {
                  Navigator.pop(context, t);
                }
              },
              child: const Text('حفظ')),
        ],
      );
}
