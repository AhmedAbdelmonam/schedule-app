import 'package:home_widget/home_widget.dart';
import 'engine.dart';

/// Sends the next ~36h of blocks to the Android home-screen widget.
Future<void> pushWidget(List<Task> ts) async {
  final now = DateTime.now();
  final sb = StringBuffer();
  for (var i = 0; i < 2; i++) {
    final d = DateTime(now.year, now.month, now.day + i);
    for (final b in blocksFor(d, ts)) {
      if (b.task?.name == 'نوم') continue;
      final s = DateTime(d.year, d.month, d.day, 0, b.start).millisecondsSinceEpoch;
      final e = DateTime(d.year, d.month, d.day, 0, b.end).millisecondsSinceEpoch;
      sb.writeln('$s|$e|${b.name}');
    }
  }
  await HomeWidget.saveWidgetData<String>('w_blocks', sb.toString());
  await HomeWidget.updateWidget(androidName: 'ScheduleWidget');
}
