import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'adhan_flag.dart';
import 'engine.dart';

final _p = FlutterLocalNotificationsPlugin();

Future<void> initNotif() async {
  await _p.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  final a = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await a?.requestNotificationsPermission();
  await a?.requestExactAlarmsPermission();
}

/// Schedules the next 7 days (prayers with adhan + task starts). Re-run on every app launch.
Future<void> reschedule(List<Task> ts, bool adhan) async {
  await _p.cancelAll();
  final now = DateTime.now();
  var id = 1;
  Future<void> add(DateTime at, String title, String body, bool pr) async {
    if (at.isBefore(now) || id > 450) return;
    final useAdhan = pr && adhan && hasAdhan;
    final d = NotificationDetails(
        android: AndroidNotificationDetails(useAdhan ? 'adhan_c' : (pr ? 'prayer_c' : 'task_c'), pr ? 'الصلاة' : 'المهام',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: useAdhan ? const RawResourceAndroidNotificationSound('adhan') : null));
    await _p.zonedSchedule(id++, title, body, tz.TZDateTime.from(at, tz.UTC), d,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
  }

  for (var i = 0; i < 7; i++) {
    final day = DateTime(now.year, now.month, now.day + i);
    final p = times(day);
    for (final k in prayerKeys) {
      await add(DateTime(day.year, day.month, day.day, 0, p[k]!), 'حان الآن وقت صلاة ${anchorNames[k]}', '', true);
    }
    for (final t in ts.where((t) => t.occursOn(day) && t.name != 'نوم')) {
      await add(DateTime(day.year, day.month, day.day, 0, t.startOn(p)), t.name, t.note.isEmpty ? 'بدأ وقت المهمة' : t.note, false);
    }
  }
}
