import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'core.dart';

/// تنبيهات محلية (بدون إنترنت) قبل مواعيد الحلقات.
class Notifier {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _busy = false;
  static bool _again = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'sessions',
      'تنبيهات الحلقات',
      channelDescription: 'تذكير قبل موعد الحلقة',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    await init();
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return (await a?.requestNotificationsPermission()) ?? false;
  }

  static Future<void> test() async {
    await init();
    await _plugin.show(0, 'وِرد', 'هكذا سيظهر تنبيه الحلقة ✔', _details);
  }

  /// يعيد جدولة التنبيهات حسب الإعدادات والجداول الحالية.
  static Future<void> sync() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        final on = await Repo.setting('notify_enabled') == '1';
        final mins = int.tryParse(await Repo.setting('notify_minutes') ?? '') ?? 15;
        await _reschedule(on, mins);
      } while (_again);
    } catch (_) {
      // التنبيهات ميزة مساعدة؛ فشلها لا يجب أن يعطّل التطبيق.
    } finally {
      _busy = false;
    }
  }

  static Future<void> _reschedule(bool on, int minutes) async {
    await init();
    await _plugin.cancelAll();
    if (!on) return;
    final now = DateTime.now();
    final utc = tz.getLocation('UTC');
    var id = 1;
    for (var i = 0; i < 14; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      final byTime = <String, List<String>>{};
      for (final x in await Repo.scheduledOn(day)) {
        byTime.putIfAbsent(sv(x['time']), () => []).add(sv((x['student'] as M)['full_name']));
      }
      for (final e in byTime.entries) {
        final p = e.key.split(':');
        if (p.length != 2) continue;
        final start = DateTime(day.year, day.month, day.day, int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0);
        final at = start.subtract(Duration(minutes: minutes));
        if (!at.isAfter(now)) continue;
        final names = e.value;
        final shown = names.length <= 3
            ? names.join('، ')
            : '${names.take(3).join('، ')} و${names.length - 3} آخرين';
        await _plugin.zonedSchedule(
          id++,
          'حلقة بعد $minutes دقيقة',
          '${e.key} — $shown',
          tz.TZDateTime.from(at, utc),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }
}
