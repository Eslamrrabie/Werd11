import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'core.dart';
import 'notify.dart';
import 'screens_a.dart';
import 'screens_c.dart';
import 'ui.dart';

// ═════════════════════════ عنصر سجل تسميع ═════════════════════════
Widget recTile(BuildContext context, M x, {bool showName = true}) {
  final rating = sv(x['rating']);
  final verses = iv(x['start_verse']) > 0 ? '${iv(x['start_verse'])}–${iv(x['end_verse'])}' : '';
  return AppCard(
    onTap: () => push(context, RecitationEditPage(id: iv(x['id']))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(
            showName ? sv(x['full_name']) : arDateShort(sv(x['recitation_date'])),
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
          ),
        ),
        Pill(rating, ratingColor(rating)),
      ]),
      const SizedBox(height: 4),
      Text('${sv(x['recitation_type'])} • ${sv(x['surah_name'])} $verses'),
      if (sv(x['mistakes']).isNotEmpty)
        Text('الأخطاء: ${sv(x['mistakes'])}', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
      if (sv(x['notes']).isNotEmpty)
        Text(sv(x['notes']), style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
      if (assignText(x).isNotEmpty)
        Text('التكليف القادم: ${assignText(x)}',
            style: const TextStyle(fontSize: 12.5, color: emerald)),
    ]),
  );
}

// ═════════════════════════ التسميع (تبويب) ═════════════════════════
class RecitationPage extends StatefulWidget {
  const RecitationPage({super.key});
  @override
  State<RecitationPage> createState() => _RecitationPageState();
}

class _RecitationPageState extends State<RecitationPage> {
  DateTime date = DateTime.now();
  List<M> recs = [];
  List<M> waiting = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
    dataVersion.addListener(load);
  }

  @override
  void dispose() {
    dataVersion.removeListener(load);
    super.dispose();
  }

  Future<void> load() async {
    final ds = iso(date);
    final r = await Repo.recitationsOn(ds);
    final sch = await Repo.scheduledOn(date);
    final att = await Repo.attendanceOn(ds);
    final done = r.map((x) => iv(x['student_id'])).toSet();
    final w = <M>[];
    for (final x in sch) {
      final s = x['student'] as M;
      final id = iv(s['id']);
      final st = att[id] == null ? '' : sv(att[id]!['status']);
      if (st != 'غائب' && st != 'اعتذار' && !done.contains(id)) w.add(s);
    }
    if (!mounted) return;
    setState(() {
      recs = r;
      waiting = w;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التسميع')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => push(context, SessionFormPage(date: date)),
        icon: const Icon(Icons.add),
        label: const Text('تسجيل تسميع'),
      ),
      body: Column(children: [
        DateBar(
          date: date,
          onChanged: (d) {
            setState(() {
              date = d;
              loading = true;
            });
            load();
          },
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                  if (waiting.isNotEmpty) ...[
                    const SectionTitle('بانتظار التسميع'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(spacing: 8, runSpacing: 4, children: [
                        for (final s in waiting)
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 16),
                            label: Text(sv(s['full_name'])),
                            onPressed: () =>
                                push(context, SessionFormPage(studentId: iv(s['id']), date: date)),
                          ),
                      ]),
                    ),
                  ],
                  const SectionTitle('سجلات هذا اليوم'),
                  if (recs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: EmptyState(Icons.menu_book, 'لا توجد سجلات تسميع في هذا اليوم'),
                    ),
                  for (final x in recs) recTile(context, x),
                ]),
        ),
      ]),
    );
  }
}

// ═════════════════════════ الحلقات ═════════════════════════
class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});
  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  DateTime day = DateTime.now();
  List<M> dayRows = [];
  Map<int, M> att = {};
  List<(DateTime, List<M>)> week = [];
  List<M> groups = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
    dataVersion.addListener(load);
  }

  @override
  void dispose() {
    dataVersion.removeListener(load);
    super.dispose();
  }

  Future<void> load() async {
    final rows = await Repo.scheduledOn(day);
    final a = await Repo.attendanceOn(iso(day));
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day - ((today.weekday - 6) % 7));
    final w = <(DateTime, List<M>)>[];
    for (var i = 0; i < 7; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      w.add((d, await Repo.scheduledOn(d)));
    }
    final g = await Repo.groups();
    if (!mounted) return;
    setState(() {
      dayRows = rows;
      att = a;
      week = w;
      groups = g;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الحلقات'),
          bottom: const TabBar(
            labelColor: cream,
            unselectedLabelColor: Colors.white70,
            indicatorColor: gold,
            tabs: [Tab(text: 'اليوم'), Tab(text: 'الأسبوع'), Tab(text: 'المجموعات')],
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [dayTab(), weekTab(), groupsTab()]),
      ),
    );
  }

  Widget dayTab() => Column(children: [
        DateBar(
          date: day,
          onChanged: (d) {
            setState(() => day = d);
            load();
          },
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => push(context, AttendancePage(date: day)),
              icon: const Icon(Icons.fact_check),
              label: const Text('تسجيل الحضور لهذا اليوم'),
            ),
          ),
        ),
        Expanded(
          child: dayRows.isEmpty
              ? const EmptyState(Icons.event_busy, 'لا توجد حلقات مجدولة في هذا اليوم')
              : ListView(children: [
                  for (final x in dayRows)
                    Builder(builder: (_) {
                      final s = x['student'] as M;
                      final st = att[iv(s['id'])] == null ? null : sv(att[iv(s['id'])]!['status']);
                      return AppCard(
                        onTap: () => push(context, StudentProfilePage(id: iv(s['id']))),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(children: [
                          Text('${x['time']}', style: const TextStyle(fontWeight: FontWeight.bold, color: emerald)),
                          const SizedBox(width: 14),
                          Expanded(child: Text(sv(s['full_name']))),
                          st == null ? const Pill('لم يُسجَّل', Colors.grey) : Pill(st, statusColor(st)),
                        ]),
                      );
                    }),
                ]),
        ),
      ]);

  Widget weekTab() => ListView(padding: const EdgeInsets.only(top: 6, bottom: 24), children: [
        for (final e in week)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${weekdayNames[e.$1.weekday]} — ${arDateShort(iso(e.$1))}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: emerald)),
              const SizedBox(height: 4),
              if (e.$2.isEmpty)
                const Text('لا توجد حلقات', style: TextStyle(color: Colors.black45))
              else
                for (final x in e.$2) Text('${x['time']}  •  ${sv((x['student'] as M)['full_name'])}'),
            ]),
          ),
      ]);

  Widget groupsTab() => ListView(padding: const EdgeInsets.only(top: 6, bottom: 24), children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: FilledButton.icon(
            onPressed: () => push(context, const GroupFormPage()),
            icon: const Icon(Icons.add),
            label: const Text('إضافة حلقة'),
          ),
        ),
        if (groups.isEmpty) const EmptyState(Icons.groups_2, 'لم تُنشأ أي حلقة بعد'),
        for (final g in groups)
          AppCard(
            onTap: () => push(context, GroupFormPage(id: iv(g['id']))),
            child: Row(children: [
              const Icon(Icons.groups_2, color: gold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sv(g['name']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${iv(g['cnt'])} طالب نشط', style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
                ]),
              ),
              const Icon(Icons.chevron_left),
            ]),
          ),
      ]);
}

class GroupFormPage extends StatefulWidget {
  final int? id;
  const GroupFormPage({super.key, this.id});
  @override
  State<GroupFormPage> createState() => _GroupFormPageState();
}

class _GroupFormPageState extends State<GroupFormPage> {
  final form = GlobalKey<FormState>();
  final nameC = TextEditingController();
  final notesC = TextEditingController();
  ScheduleDraft draft = ScheduleDraft();
  List<M> students = [];
  Set<int> members = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    nameC.dispose();
    notesC.dispose();
    super.dispose();
  }

  Future<void> init() async {
    students = await Repo.students(status: 'active');
    if (widget.id != null) {
      final g = await Repo.group(widget.id!);
      if (g != null) {
        nameC.text = sv(g['name']);
        notesC.text = sv(g['notes']);
      }
      draft = ScheduleDraft.fromRows(await Repo.schedules(groupId: widget.id));
      members = students.where((s) => s['group_id'] == widget.id).map((s) => iv(s['id'])).toSet();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final name = nameC.text.trim();
    if (await Repo.groupNameExists(name, excludeId: widget.id)) {
      if (mounted) toast(context, 'توجد حلقة بهذا الاسم بالفعل');
      return;
    }
    try {
      final id = await Repo.saveGroup(name, notesC.text.trim(), id: widget.id);
      await Repo.replaceSchedules(groupId: id, days: draft.days, time: draft.time, duration: draft.duration);
      await Repo.assignMembers(id, members);
      bump();
      if (!mounted) return;
      toast(context, 'تم حفظ الحلقة');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, 'تعذّر الحفظ: $e');
    }
  }

  Future<void> delete() async {
    final ok = await confirmDialog(context, 'حذف الحلقة',
        'ستُحذف الحلقة وجدولها، ويبقى طلابها بدون حلقة. لا تتأثر سجلات الحضور والتسميع.',
        ok: 'حذف', danger: true);
    if (!ok) return;
    await Repo.deleteGroup(widget.id!);
    bump();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'حلقة جديدة' : 'تعديل الحلقة'),
        actions: [
          if (widget.id != null)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'حذف', onPressed: delete),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: form,
              child: ListView(padding: const EdgeInsets.all(14), children: [
                TextFormField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'اسم الحلقة *'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesC,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                  maxLines: 2,
                ),
                const SectionTitle('أيام الحلقة ووقتها'),
                ScheduleEditor(draft: draft),
                const SectionTitle('الطلاب'),
                if (students.isEmpty) const Text('لا يوجد طلاب نشطون بعد', style: TextStyle(color: Colors.black54)),
                for (final s in students)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: members.contains(iv(s['id'])),
                    title: Text(sv(s['full_name'])),
                    onChanged: (v) => setState(() => v == true ? members.add(iv(s['id'])) : members.remove(iv(s['id']))),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: const Text('حفظ')),
              ]),
            ),
    );
  }
}

// ═════════════════════════ التقارير ═════════════════════════
class _Report {
  final List<String> headers;
  final List<List<String>> rows;
  final String? message;
  _Report(this.headers, this.rows, {this.message});
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const types = [
    'الحضور اليومي',
    'الحضور الأسبوعي',
    'الحضور الشهري',
    'غياب الطلاب',
    'تقدّم طالب',
    'نشاط الحفظ',
    'طلاب يحتاجون مراجعة',
  ];
  int type = 1;
  DateTime from = DateTime.now();
  DateTime to = DateTime.now();
  int? studentId;
  List<M> students = [];
  _Report? result;
  bool running = false;

  @override
  void initState() {
    super.initState();
    setPreset(1);
    loadStudents();
    dataVersion.addListener(loadStudents);
  }

  @override
  void dispose() {
    dataVersion.removeListener(loadStudents);
    super.dispose();
  }

  Future<void> loadStudents() async {
    final s = await Repo.students();
    if (mounted) setState(() => students = s);
  }

  void setPreset(int t) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    if (t == 0) {
      from = today;
      to = today;
    } else if (t == 1) {
      from = DateTime(today.year, today.month, today.day - ((today.weekday - 6) % 7));
      to = DateTime(from.year, from.month, from.day + 6);
    } else if (t == 2) {
      from = DateTime(today.year, today.month, 1);
      to = DateTime(today.year, today.month + 1, 0);
    }
  }

  Future<void> run() async {
    if (type == 4 && studentId == null) {
      setState(() => result = _Report([], [], message: 'اختر طالباً لعرض تقرير تقدّمه'));
      return;
    }
    setState(() => running = true);
    try {
      final rep = await compute();
      if (mounted) setState(() => result = rep);
    } catch (e) {
      if (mounted) toast(context, 'تعذّر إنشاء التقرير: $e');
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  Future<_Report> compute() async {
    final db = await AppDb.db;
    final f = iso(from), t = iso(to);
    final sid = studentId;
    final sFilter = sid == null ? '' : ' AND a.student_id = $sid';
    String pct(int pr, int total, int ex) {
      final d = total - ex;
      return d <= 0 ? '—' : '${(pr * 100 / d).round()}٪';
    }

    switch (type) {
      case 0:
        final r1 = await db.rawQuery(
            'SELECT a.session_date d, s.full_name n, a.status st, COALESCE(a.notes, \'\') nt '
            'FROM attendance a JOIN students s ON s.id = a.student_id '
            'WHERE a.session_date BETWEEN ? AND ? $sFilter ORDER BY a.session_date, s.full_name',
            [f, t]);
        return _Report(['التاريخ', 'الطالب', 'الحالة', 'ملاحظة'],
            [for (final x in r1) [sv(x['d']), sv(x['n']), sv(x['st']), sv(x['nt'])]]);
      case 1:
      case 2:
        final r3 = await db.rawQuery(
            'SELECT s.full_name n, '
            "SUM(a.status = 'حاضر') p, SUM(a.status = 'متأخر') l, SUM(a.status = 'غائب') ab, "
            "SUM(a.status = 'اعتذار') ex, COUNT(a.id) total "
            'FROM students s JOIN attendance a ON a.student_id = s.id '
            'AND a.session_date BETWEEN ? AND ? ${sid == null ? '' : 'AND s.id = $sid'} '
            'GROUP BY s.id ORDER BY s.full_name',
            [f, t]);
        return _Report(['الطالب', 'حاضر', 'متأخر', 'غائب', 'اعتذار', 'النسبة'], [
          for (final x in r3)
            [
              sv(x['n']),
              '${iv(x['p'])}',
              '${iv(x['l'])}',
              '${iv(x['ab'])}',
              '${iv(x['ex'])}',
              pct(iv(x['p']) + iv(x['l']), iv(x['total']), iv(x['ex'])),
            ]
        ]);
      case 3:
        final r4 = await db.rawQuery(
            'SELECT a.session_date d, s.full_name n, a.status st, COALESCE(a.notes, \'\') nt '
            'FROM attendance a JOIN students s ON s.id = a.student_id '
            "WHERE a.status IN ('غائب','اعتذار') AND a.session_date BETWEEN ? AND ? $sFilter "
            'ORDER BY s.full_name, a.session_date',
            [f, t]);
        return _Report(['الطالب', 'التاريخ', 'نوع الغياب', 'ملاحظة'], [
          for (final x in r4)
            [sv(x['n']), sv(x['d']), sv(x['st']) == 'اعتذار' ? 'بعذر' : 'بدون عذر', sv(x['nt'])]
        ]);
      case 4:
        final r5 = await db.query('recitations',
            where: 'student_id = ? AND recitation_date BETWEEN ? AND ?',
            whereArgs: [sid, f, t],
            orderBy: 'recitation_date, id');
        return _Report(['التاريخ', 'النوع', 'السورة', 'من', 'إلى', 'التقييم', 'الأخطاء', 'ملاحظات'], [
          for (final x in r5)
            [
              sv(x['recitation_date']),
              sv(x['recitation_type']),
              sv(x['surah_name']),
              sv(x['start_verse']),
              sv(x['end_verse']),
              sv(x['rating']),
              sv(x['mistakes']),
              sv(x['notes']),
            ]
        ]);
      case 5:
        final r6 = await db.rawQuery(
            'SELECT s.full_name n, COUNT(r.id) c, '
            "SUM(r.recitation_type = 'حفظ جديد') nw, SUM(r.recitation_type = 'مراجعة') rv, "
            "SUM(r.recitation_type = 'تثبيت') fx, SUM(r.recitation_type = 'تلاوة وتجويد') tj, "
            'MAX(r.recitation_date) last FROM students s JOIN recitations r ON r.student_id = s.id '
            "AND r.recitation_date BETWEEN ? AND ? AND r.rating <> '$kNotRecited' "
            '${sid == null ? '' : 'AND s.id = $sid'} GROUP BY s.id ORDER BY s.full_name',
            [f, t]);
        return _Report(['الطالب', 'الإجمالي', 'حفظ جديد', 'مراجعة', 'تثبيت', 'تلاوة وتجويد', 'آخر تسميع'], [
          for (final x in r6)
            [sv(x['n']), '${iv(x['c'])}', '${iv(x['nw'])}', '${iv(x['rv'])}', '${iv(x['fx'])}', '${iv(x['tj'])}', sv(x['last'])]
        ]);
      default:
        final rows = <List<String>>[];
        for (final s in await Repo.students(status: 'active')) {
          if (sid != null && iv(s['id']) != sid) continue;
          final r7 = await db.query('recitations',
              where: 'student_id = ? AND recitation_date <= ?',
              whereArgs: [s['id'], t],
              orderBy: 'recitation_date DESC, id DESC',
              limit: 1);
          if (r7.isNotEmpty && sv(r7.first['rating']) == kNeedsRevision) {
            final x = r7.first;
            rows.add([
              sv(s['full_name']),
              sv(x['surah_name']),
              '${sv(x['start_verse'])}–${sv(x['end_verse'])}',
              sv(x['recitation_date']),
              sv(x['mistakes']),
            ]);
          }
        }
        return _Report(['الطالب', 'السورة', 'الآيات', 'التاريخ', 'الأخطاء'], rows);
    }
  }

  Future<void> exportCsv() async {
    final r = result;
    if (r == null || r.rows.isEmpty) return;
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ التقرير',
        fileName: 'تقرير_${iso(DateTime.now())}.csv',
        bytes: csvBytes(r.headers, r.rows),
      );
      if (mounted) toast(context, path == null ? 'أُلغي التصدير' : 'تم تصدير التقرير');
    } catch (e) {
      if (mounted) toast(context, 'فشل التصدير: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: DropdownButtonFormField<int>(
            value: type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'نوع التقرير'),
            items: [for (var i = 0; i < types.length; i++) DropdownMenuItem(value: i, child: Text(types[i]))],
            onChanged: (v) => setState(() {
              type = v ?? type;
              if (type <= 2) setPreset(type);
              result = null;
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: DropdownButtonFormField<int?>(
            value: students.any((s) => iv(s['id']) == studentId) ? studentId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: type == 4 ? 'الطالب *' : 'الطالب (اختياري)'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('كل الطلاب')),
              for (final s in students) DropdownMenuItem<int?>(value: iv(s['id']), child: Text(sv(s['full_name']))),
            ],
            onChanged: (v) => setState(() => studentId = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final d = await pickDate(context, from);
                  if (d != null) setState(() => from = d);
                },
                child: Text('من ${arDateShort(iso(from))}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final d = await pickDate(context, to);
                  if (d != null) setState(() => to = d);
                },
                child: Text('إلى ${arDateShort(iso(to))}'),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Wrap(spacing: 8, children: [
            ActionChip(label: const Text('اليوم'), onPressed: () => setState(() => setPreset(0))),
            ActionChip(label: const Text('هذا الأسبوع'), onPressed: () => setState(() => setPreset(1))),
            ActionChip(label: const Text('هذا الشهر'), onPressed: () => setState(() => setPreset(2))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: running ? null : run,
                icon: const Icon(Icons.play_arrow),
                label: const Text('عرض التقرير'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: (r == null || r.rows.isEmpty) ? null : exportCsv,
              icon: const Icon(Icons.file_download),
              label: const Text('CSV'),
            ),
          ]),
        ),
        if (running) const Center(child: CircularProgressIndicator()),
        if (r != null && r.message != null) EmptyState(Icons.info_outline, r.message!),
        if (r != null && r.message == null && r.rows.isEmpty)
          const EmptyState(Icons.inbox, 'لا توجد بيانات في هذه الفترة'),
        if (r != null && r.rows.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1EBD6)),
              columnSpacing: 22,
              columns: [for (final h in r.headers) DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold)))],
              rows: [
                for (final row in r.rows) DataRow(cells: [for (final c in row) DataCell(Text(c))]),
              ],
            ),
          ),
      ]),
    );
  }
}

// ═════════════════════════ الإعدادات والنسخ الاحتياطي ═════════════════════════
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, int> totals = {};
  bool busy = false;
  bool notifyOn = false;
  int notifyMin = 15;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final t = await Repo.totals();
    final on = await Repo.setting('notify_enabled') == '1';
    final mins = int.tryParse(await Repo.setting('notify_minutes') ?? '') ?? 15;
    if (mounted) {
      setState(() {
        totals = t;
        notifyOn = on;
        notifyMin = mins;
      });
    }
  }

  Future<void> toggleNotify(bool v) async {
    if (v) {
      final ok = await Notifier.requestPermission();
      if (!ok) {
        if (mounted) toast(context, 'لم يُسمح بالإشعارات. فعّلها للتطبيق من إعدادات الهاتف');
        return;
      }
    }
    await Repo.setSetting('notify_enabled', v ? '1' : '0');
    setState(() => notifyOn = v);
    bump();
    if (mounted) toast(context, v ? 'تم تفعيل التنبيه قبل الحلقات' : 'تم إيقاف التنبيهات');
  }

  Future<void> setMinutes(int m) async {
    await Repo.setSetting('notify_minutes', '$m');
    setState(() => notifyMin = m);
    bump();
  }

  Future<void> export() async {
    setState(() => busy = true);
    try {
      final bytes = await Backup.exportBytes();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
        fileName: 'werd_backup_${iso(DateTime.now())}.db',
        bytes: bytes,
      );
      if (!mounted) return;
      toast(context, path == null ? 'أُلغي التصدير' : 'تم إنشاء النسخة الاحتياطية بنجاح');
    } catch (e) {
      if (mounted) toast(context, 'فشل إنشاء النسخة: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    try {
      final pick = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (pick == null || pick.files.isEmpty) return;
      final bytes = pick.files.first.bytes;
      if (bytes == null) throw 'تعذّرت قراءة الملف';
      setState(() => busy = true);
      final info = await Backup.validate(bytes);
      if (!mounted) return;
      setState(() => busy = false);
      final ok = await confirmDialog(
        context,
        'استعادة نسخة احتياطية',
        'النسخة صالحة وتحتوي على: ${info['students']} طالب، ${info['attendance']} سجل حضور، ${info['recitations']} سجل تسميع، ${info['groups']} حلقة.\n\n'
        'تحذير: ستُستبدل كل البيانات الحالية (${totals['students']} طالب، ${totals['attendance']} حضور، ${totals['recitations']} تسميع) بمحتوى هذه النسخة. '
        'يُحفظ تلقائياً ملف أمان بالبيانات الحالية داخل التطبيق قبل الاستبدال.',
        ok: 'استبدال واستعادة',
        danger: true,
      );
      if (!ok) return;
      setState(() => busy = true);
      await Backup.restore(bytes);
      await refresh();
      if (mounted) toast(context, 'تمت الاستعادة بنجاح');
    } catch (e) {
      if (mounted) toast(context, 'فشلت الاستعادة: ${e is String ? e : 'ملف غير صالح'}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
        const SectionTitle('التنبيهات'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تنبيه قبل موعد الحلقة'),
              subtitle: const Text('يعمل بدون إنترنت حسب جداول الحلقات والطلاب'),
              value: notifyOn,
              onChanged: toggleNotify,
            ),
            Row(children: [
              const Text('قبل الحلقة بـ '),
              DropdownButton<int>(
                value: const [5, 10, 15, 30, 60].contains(notifyMin) ? notifyMin : 15,
                items: [for (final m in const [5, 10, 15, 30, 60]) DropdownMenuItem(value: m, child: Text('$m دقيقة'))],
                onChanged: notifyOn ? (v) => setMinutes(v ?? 15) : null,
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final ok = await Notifier.requestPermission();
                  if (!ok) {
                    if (mounted) toast(context, 'فعّل الإشعارات للتطبيق من إعدادات الهاتف أولاً');
                    return;
                  }
                  await Notifier.test();
                },
                child: const Text('تجربة التنبيه'),
              ),
            ]),
            const Text(
              'ملاحظة: افتح التطبيق مرة كل أسبوعين على الأقل ليتجدد جدول التنبيهات (يُجدول ١٤ يوماً قادماً).',
              style: TextStyle(color: Colors.black54, fontSize: 12.5),
            ),
          ]),
        ),
        const SectionTitle('النسخ الاحتياطي والاستعادة'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('المحفوظ حالياً: ${totals['students'] ?? 0} طالب • ${totals['attendance'] ?? 0} سجل حضور • ${totals['recitations'] ?? 0} سجل تسميع • ${totals['groups'] ?? 0} حلقة'),
            const SizedBox(height: 10),
            const Text(
              'احفظ النسخة خارج التطبيق (الذاكرة الداخلية أو بطاقة الذاكرة أو Google Drive) '
              'لتبقى متاحة حتى لو حُذف التطبيق.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : export,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('تصدير نسخة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : restore,
                  icon: const Icon(Icons.download),
                  label: const Text('استعادة نسخة'),
                ),
              ),
            ]),
            if (busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          ]),
        ),
        const SectionTitle('حول التطبيق'),
        const AppCard(
          child: Text('وِرد — إصدار 1.0\nيعمل بالكامل بدون إنترنت، وكل البيانات محفوظة على جهازك فقط.'),
        ),
      ]),
    );
  }
}
