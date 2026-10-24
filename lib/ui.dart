import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core.dart';

const emerald = Color(0xFF0B5D45);
const cream = Color(0xFFFAF6EC);
const gold = Color(0xFFC9A24B);
const ink = Color(0xFF1F2A26);

ThemeData buildTheme() {
  final cs = ColorScheme.fromSeed(seedColor: emerald).copyWith(
    primary: emerald,
    onPrimary: cream,
    secondary: gold,
    onSecondary: ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: emerald,
      foregroundColor: cream,
      centerTitle: true,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: gold,
      foregroundColor: ink,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: gold.withOpacity(.35),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
      fillColor: Colors.white,
    ),
  );
}

Future<T?> push<T>(BuildContext c, Widget w) =>
    Navigator.push<T>(c, MaterialPageRoute<T>(builder: (_) => w));

void toast(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

Future<bool> confirmDialog(BuildContext c, String title, String msg,
    {String ok = 'تأكيد', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<DateTime?> pickDate(BuildContext c, DateTime initial) => showDatePicker(
      context: c,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

Color statusColor(String s) {
  switch (s) {
    case 'حاضر':
      return const Color(0xFF2E7D32);
    case 'غائب':
      return const Color(0xFFC62828);
    case 'اعتذار':
      return const Color(0xFFEF6C00);
    case 'متأخر':
      return const Color(0xFF1565C0);
  }
  return Colors.grey;
}

Color ratingColor(String r) {
  switch (r) {
    case 'ممتاز':
      return const Color(0xFF2E7D32);
    case 'جيد جداً':
      return const Color(0xFF558B2F);
    case 'جيد':
      return const Color(0xFF1565C0);
    case kNeedsRevision:
      return const Color(0xFFEF6C00);
    case kNotRecited:
      return const Color(0xFFC62828);
  }
  return Colors.grey;
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );
}

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE8E0C8)),
        ),
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: emerald)),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: gold),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.black54)),
          ]),
        ),
      );
}

class KV extends StatelessWidget {
  final String k;
  final String v;
  const KV(this.k, this.v, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v.isEmpty ? '—' : v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class DateBar extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const DateBar({super.key, required this.date, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(DateTime(date.year, date.month, date.day - 1)),
          ),
          Expanded(
            child: TextButton(
              onPressed: () async {
                final d = await pickDate(context, date);
                if (d != null) onChanged(d);
              },
              child: Text(arDate(date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(DateTime(date.year, date.month, date.day + 1)),
          ),
        ]),
      );
}

// ───────────── محرر الجدول (أيام + وقت + مدة) ─────────────
class ScheduleDraft {
  Set<int> days;
  String time;
  int duration;
  ScheduleDraft({Set<int>? days, this.time = '16:00', this.duration = 30}) : days = days ?? <int>{};

  static ScheduleDraft fromRows(List<M> rows) {
    if (rows.isEmpty) return ScheduleDraft();
    return ScheduleDraft(
      days: rows.map((e) => iv(e['weekday'])).toSet(),
      time: sv(rows.first['start_time']),
      duration: iv(rows.first['duration_minutes']),
    );
  }

  String get summary => days.isEmpty
      ? 'غير محدد'
      : '${weekOrder.where(days.contains).map((d) => weekdayNames[d]).join('، ')} • $time • $duration دقيقة';
}

class ScheduleEditor extends StatefulWidget {
  final ScheduleDraft draft;
  const ScheduleEditor({super.key, required this.draft});
  @override
  State<ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<ScheduleEditor> {
  static const durations = [15, 20, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final dur = durations.contains(d.duration) ? d.duration : 30;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, children: [
        for (final w in weekOrder)
          FilterChip(
            label: Text(weekdayNames[w]!),
            selected: d.days.contains(w),
            onSelected: (v) => setState(() => v ? d.days.add(w) : d.days.remove(w)),
          ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.access_time),
          label: Text('البداية ${d.time}'),
          onPressed: () async {
            final parts = d.time.split(':');
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 16, minute: int.tryParse(parts[1]) ?? 0),
            );
            if (t != null) {
              setState(() => d.time =
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
            }
          },
        ),
        const SizedBox(width: 12),
        const Text('المدة: '),
        DropdownButton<int>(
          value: dur,
          items: [for (final x in durations) DropdownMenuItem(value: x, child: Text('$x دقيقة'))],
          onChanged: (v) => setState(() => d.duration = v ?? 30),
        ),
      ]),
    ]);
  }
}

/// يحوّل الرقم لصيغة دولية لواتساب. الرقم الذي يبدأ بـ 0 يُعامل كرقم مصري (+20).
String waNumber(String raw) {
  var n = raw.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0660}');
  n = n.replaceAll(RegExp(r'[^0-9]'), '');
  if (n.startsWith('00')) return n.substring(2);
  if (n.startsWith('0')) return '20${n.substring(1)}';
  return n;
}

Future<void> openWhatsApp(BuildContext c, String phone, String text) async {
  final n = waNumber(phone);
  final uri = Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(text)}');
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && c.mounted) toast(c, 'تعذّر فتح واتساب. تأكد أنه مثبّت على الهاتف');
  } catch (_) {
    if (c.mounted) toast(c, 'تعذّر فتح واتساب. تأكد أنه مثبّت على الهاتف');
  }
}
