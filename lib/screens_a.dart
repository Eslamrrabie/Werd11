import 'package:flutter/material.dart';

import 'core.dart';
import 'screens_b.dart';
import 'screens_c.dart';
import 'ui.dart';

// ═════════════════════════ الرئيسية ═════════════════════════
class HomePage extends StatefulWidget {
  final void Function(int) goTab;
  const HomePage({super.key, required this.goTab});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loading = true;
  int active = 0, attended = 0, absent = 0, excused = 0, pending = 0;
  List<M> sessions = [];
  Map<int, M> att = {};

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
    final today = DateTime.now();
    final ds = iso(today);
    final sch = await Repo.scheduledOn(today);
    final a = await Repo.attendanceOn(ds);
    final rec = await Repo.recitedIds(ds);
    final act = (await Repo.students(status: 'active')).length;
    int at = 0, ab = 0, ex = 0, pend = 0;
    for (final x in a.values) {
      switch (sv(x['status'])) {
        case 'حاضر':
        case 'متأخر':
          at++;
          break;
        case 'غائب':
          ab++;
          break;
        case 'اعتذار':
          ex++;
          break;
      }
    }
    for (final x in sch) {
      final id = iv((x['student'] as M)['id']);
      final st = a[id] == null ? '' : sv(a[id]!['status']);
      if (st != 'غائب' && st != 'اعتذار' && !rec.contains(id)) pend++;
    }
    if (!mounted) return;
    setState(() {
      active = act;
      sessions = sch;
      att = a;
      attended = at;
      absent = ab;
      excused = ex;
      pending = pend;
      loading = false;
    });
  }

  Widget stat(String label, int value, IconData icon, {String? sub}) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(icon, color: gold, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: emerald)),
              Text(label, style: const TextStyle(fontSize: 12.5)),
              if (sub != null) Text(sub, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('وِرد'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'الإعدادات',
            onPressed: () => push(context, const SettingsPage()),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(arDate(DateTime.now()),
                      style: const TextStyle(fontSize: 15, color: Colors.black54)),
                ),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.1,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  children: [
                    stat('طلاب نشطون', active, Icons.groups),
                    stat('مجدولون اليوم', sessions.length, Icons.event),
                    stat('حضروا اليوم', attended, Icons.check_circle_outline),
                    stat('غابوا اليوم', absent + excused, Icons.cancel_outlined,
                        sub: excused > 0 ? 'منهم $excused اعتذار' : null),
                    stat('لم يُسجَّل تسميعهم', pending, Icons.menu_book),
                  ],
                ),
                const SectionTitle('إجراءات سريعة'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(
                        onPressed: () => push(context, const StudentFormPage()),
                        icon: const Icon(Icons.person_add),
                        label: const Text('إضافة طالب')),
                    FilledButton.icon(
                        onPressed: () => push(context, const AttendancePage()),
                        icon: const Icon(Icons.fact_check),
                        label: const Text('تسجيل الحضور')),
                    FilledButton.icon(
                        onPressed: () => push(context, const SessionFormPage()),
                        icon: const Icon(Icons.record_voice_over),
                        label: const Text('تسجيل تسميع')),
                    FilledButton.tonalIcon(
                        onPressed: () => widget.goTab(1),
                        icon: const Icon(Icons.people),
                        label: const Text('عرض الطلاب')),
                    FilledButton.tonalIcon(
                        onPressed: () => widget.goTab(4),
                        icon: const Icon(Icons.bar_chart),
                        label: const Text('عرض التقارير')),
                  ]),
                ),
                const SectionTitle('حلقات اليوم'),
                if (sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: EmptyState(Icons.event_busy, 'لا توجد حلقات مجدولة اليوم'),
                  ),
                for (final x in sessions) _sessionTile(x),
              ]),
            ),
    );
  }

  Widget _sessionTile(M x) {
    final s = x['student'] as M;
    final id = iv(s['id']);
    final st = att[id] == null ? null : sv(att[id]!['status']);
    return AppCard(
      onTap: () => push(context, StudentProfilePage(id: id)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Text(sv(x['time']), style: const TextStyle(fontWeight: FontWeight.bold, color: emerald)),
        const SizedBox(width: 14),
        Expanded(child: Text(sv(s['full_name']), style: const TextStyle(fontSize: 15.5))),
        st == null ? const Pill('لم يُسجَّل', Colors.grey) : Pill(st, statusColor(st)),
      ]),
    );
  }
}

// ═════════════════════════ الحضور ═════════════════════════
class AttendancePage extends StatefulWidget {
  final DateTime? date;
  const AttendancePage({super.key, this.date});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late DateTime date = widget.date ?? DateTime.now();
  List<M> rows = [];
  Map<int, M> att = {};
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
    final sch = await Repo.scheduledOn(date);
    final a = await Repo.attendanceOn(iso(date));
    final list = [...sch];
    // سجلات موجودة لطلاب لم يعودوا مجدولين في هذا اليوم: تبقى ظاهرة للتعديل.
    for (final e in a.entries) {
      if (!list.any((x) => iv((x['student'] as M)['id']) == e.key)) {
        final s = await Repo.student(e.key);
        if (s != null) list.add({'student': s, 'time': e.value['session_start_time'] ?? ''});
      }
    }
    if (!mounted) return;
    setState(() {
      rows = list;
      att = a;
      loading = false;
    });
  }

  Future<void> setStatus(M x, String st) async {
    final id = iv((x['student'] as M)['id']);
    await Repo.setAttendance(id, iso(date), sv(x['time']), st);
    bump();
  }

  Future<void> markAllPresent() async {
    int n = 0;
    for (final x in rows) {
      final id = iv((x['student'] as M)['id']);
      if (att[id] == null) {
        await Repo.setAttendance(id, iso(date), sv(x['time']), 'حاضر');
        n++;
      }
    }
    bump();
    if (mounted) toast(context, n == 0 ? 'كل الطلاب مسجَّلون بالفعل' : 'تم تسجيل $n طالب حاضراً');
  }

  Future<void> markRestAbsent() async {
    final rest = rows.where((x) => att[iv((x['student'] as M)['id'])] == null).toList();
    if (rest.isEmpty) {
      toast(context, 'لا يوجد طلاب بدون تسجيل');
      return;
    }
    final ok = await confirmDialog(
      context,
      'تسجيل الباقي غائبين',
      'سيُسجَّل ${rest.length} طالب (غير المسجَّلين) كـ«غائب» في ${arDate(date)}. يمكنك تعديل أي واحد بعدها.',
      ok: 'تسجيلهم غائبين',
    );
    if (!ok) return;
    for (final x in rest) {
      await Repo.setAttendance(iv((x['student'] as M)['id']), iso(date), sv(x['time']), 'غائب');
    }
    bump();
    if (mounted) toast(context, 'تم تسجيل ${rest.length} غائباً');
  }

  Future<void> editNote(M record) async {
    final c = TextEditingController(text: sv(record['notes']));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ملاحظة على الحضور'),
        content: TextField(controller: c, maxLines: 3, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true) {
      await Repo.setAttendanceNote(iv(record['id']), c.text.trim());
      bump();
      if (mounted) toast(context, 'تم حفظ الملاحظة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final a in att.values) {
      counts[sv(a['status'])] = (counts[sv(a['status'])] ?? 0) + 1;
    }
    final unrecorded = rows.where((x) => att[iv((x['student'] as M)['id'])] == null).length;
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الحضور')),
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
        if (!loading && rows.isNotEmpty)
          Container(
            width: double.infinity,
            color: const Color(0xFFF1EBD6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'حاضر ${counts['حاضر'] ?? 0} • متأخر ${counts['متأخر'] ?? 0} • غائب ${counts['غائب'] ?? 0} • اعتذار ${counts['اعتذار'] ?? 0} • لم يُسجَّل $unrecorded',
                style: const TextStyle(fontSize: 12.5),
              ),
              Row(children: [
                TextButton(onPressed: markAllPresent, child: const Text('الكل حاضر')),
                TextButton(onPressed: markRestAbsent, child: const Text('الباقي غائب')),
              ]),
            ]),
          ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : rows.isEmpty
                  ? const EmptyState(Icons.event_busy,
                      'لا يوجد طلاب مجدولون في هذا اليوم.\nحدّد أيام الحلقات من قسم «الحلقات» أو من بيانات الطالب.')
                  : ListView(padding: const EdgeInsets.only(top: 6, bottom: 24), children: [
                      for (final x in rows) _tile(x),
                    ]),
        ),
      ]),
    );
  }

  Widget _tile(M x) {
    final s = x['student'] as M;
    final id = iv(s['id']);
    final rec = att[id];
    final cur = rec == null ? null : sv(rec['status']);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(sv(s['full_name']),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          Text(sv(x['time']), style: const TextStyle(color: Colors.black54)),
          if (rec != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(sv(rec['notes']).isEmpty ? Icons.note_add_outlined : Icons.sticky_note_2,
                  color: sv(rec['notes']).isEmpty ? Colors.black45 : gold),
              onPressed: () => editNote(rec),
            ),
        ]),
        if (rec != null && sv(rec['notes']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(sv(rec['notes']), style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
          ),
        Wrap(spacing: 6, children: [
          for (final st in attStatuses)
            ChoiceChip(
              label: Text(st),
              selected: cur == st,
              selectedColor: statusColor(st).withOpacity(.22),
              onSelected: (_) => setStatus(x, st),
            ),
        ]),
      ]),
    );
  }
}

// ═════════════════════════ الطلاب ═════════════════════════
class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});
  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final search = TextEditingController();
  String filter = 'active';
  List<M> list = [];
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
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final r = await Repo.students(q: search.text, status: filter == 'all' ? null : filter);
    if (!mounted) return;
    setState(() {
      list = r;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الطلاب')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => push(context, const StudentFormPage()),
        icon: const Icon(Icons.person_add),
        label: const Text('طالب جديد'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: search,
            decoration: const InputDecoration(hintText: 'ابحث بالاسم', prefixIcon: Icon(Icons.search)),
            onChanged: (_) => load(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            for (final f in const [('active', 'النشطون'), ('inactive', 'المؤرشفون'), ('all', 'الكل')])
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(f.$2),
                  selected: filter == f.$1,
                  onSelected: (_) {
                    setState(() => filter = f.$1);
                    load();
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? EmptyState(Icons.person_search,
                      search.text.isEmpty ? 'لا يوجد طلاب بعد.\nاضغط «طالب جديد» للبدء' : 'لا نتائج مطابقة')
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 6, bottom: 90),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final s = list[i];
                        final name = sv(s['full_name']);
                        final inactive = sv(s['status']) == 'inactive';
                        return AppCard(
                          onTap: () => push(context, StudentProfilePage(id: iv(s['id']))),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(children: [
                            CircleAvatar(
                              backgroundColor: emerald,
                              foregroundColor: cream,
                              child: Text(name.isEmpty ? '؟' : name.substring(0, 1)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(
                                  [
                                    if (sv(s['group_name']).isNotEmpty) sv(s['group_name']),
                                    posText(s['pos_surah'], s['pos_verse']),
                                  ].join(' • '),
                                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                                ),
                              ]),
                            ),
                            if (inactive) const Pill('مؤرشف', Colors.grey),
                          ]),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

// ═════════════════════════ نموذج الطالب ═════════════════════════
class StudentFormPage extends StatefulWidget {
  final int? id;
  const StudentFormPage({super.key, this.id});
  @override
  State<StudentFormPage> createState() => _StudentFormPageState();
}

class _StudentFormPageState extends State<StudentFormPage> {
  final form = GlobalKey<FormState>();
  final nameC = TextEditingController();
  final phoneC = TextEditingController();
  final gphoneC = TextEditingController();
  final notesC = TextEditingController();
  final verseC = TextEditingController();
  DateTime enroll = DateTime.now();
  int? groupId;
  int? posSurah;
  String status = 'active';
  bool ownSched = false;
  ScheduleDraft draft = ScheduleDraft();
  List<M> groups = [];
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    for (final c in [nameC, phoneC, gphoneC, notesC, verseC]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> init() async {
    groups = await Repo.groups();
    if (widget.id != null) {
      final s = await Repo.student(widget.id!);
      if (s != null) {
        nameC.text = sv(s['full_name']);
        phoneC.text = sv(s['phone']);
        gphoneC.text = sv(s['guardian_phone']);
        notesC.text = sv(s['notes']);
        enroll = sv(s['enrollment_date']).isEmpty ? DateTime.now() : parseIso(sv(s['enrollment_date']));
        groupId = s['group_id'] as int?;
        status = sv(s['status']);
        posSurah = s['pos_surah'] as int?;
        if (s['pos_verse'] != null) verseC.text = '${s['pos_verse']}';
        final own = await Repo.schedules(studentId: widget.id);
        if (own.isNotEmpty) {
          ownSched = true;
          draft = ScheduleDraft.fromRows(own);
        }
      }
    }
    if (mounted) setState(() => loading = false);
  }

  String? phoneValidator(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return RegExp(r'^[0-9٠-٩+\s\-]{6,20}$').hasMatch(t) ? null : 'رقم هاتف غير صالح';
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final name = nameC.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final dup = await Repo.findDuplicate(name, excludeId: widget.id);
    if (dup != null) {
      if (!mounted) return;
      final go = await confirmDialog(context, 'اسم مكرر',
          'يوجد طالب مسجَّل باسم «$dup». هل تريد المتابعة بنفس الاسم؟');
      if (!go) return;
    }
    if (ownSched && draft.days.isEmpty) {
      if (!mounted) return;
      toast(context, 'اختر يوماً واحداً على الأقل للجدول الخاص، أو أوقف الجدول الخاص');
      return;
    }
    setState(() => saving = true);
    try {
      final verse = int.tryParse(verseC.text.trim());
      final id = await Repo.saveStudent({
        'full_name': name,
        'phone': phoneC.text.trim(),
        'guardian_phone': gphoneC.text.trim(),
        'enrollment_date': iso(enroll),
        'group_id': groupId,
        'notes': notesC.text.trim(),
        'status': status,
        'pos_surah': posSurah,
        'pos_verse': posSurah == null ? null : verse,
        'memorization_position': posSurah == null ? '' : posText(posSurah, verse),
      }, id: widget.id);
      await Repo.replaceSchedules(
        studentId: id,
        days: ownSched ? draft.days : <int>{},
        time: draft.time,
        duration: draft.duration,
      );
      bump();
      if (!mounted) return;
      toast(context, widget.id == null ? 'تمت إضافة الطالب' : 'تم حفظ التعديلات');
      Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, 'تعذّر الحفظ: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'طالب جديد' : 'تعديل بيانات الطالب')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: form,
              child: ListView(padding: const EdgeInsets.all(14), children: [
                TextFormField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل *'),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneC,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  keyboardType: TextInputType.phone,
                  validator: phoneValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: gphoneC,
                  decoration: const InputDecoration(labelText: 'هاتف ولي الأمر'),
                  keyboardType: TextInputType.phone,
                  validator: phoneValidator,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text('تاريخ الالتحاق: ${arDate(enroll)}'),
                  onPressed: () async {
                    final d = await pickDate(context, enroll);
                    if (d != null) setState(() => enroll = d);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: groups.any((g) => iv(g['id']) == groupId) ? groupId : null,
                  decoration: const InputDecoration(labelText: 'الحلقة'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('بدون حلقة')),
                    for (final g in groups)
                      DropdownMenuItem<int?>(value: iv(g['id']), child: Text(sv(g['name']))),
                  ],
                  onChanged: (v) => setState(() => groupId = v),
                ),
                const SectionTitle('موضع الحفظ الحالي'),
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int?>(
                      value: posSurah,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'السورة'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('غير محدد')),
                        for (var i = 0; i < 114; i++)
                          DropdownMenuItem<int?>(value: i + 1, child: Text('${i + 1}. ${surahs[i].$1}')),
                      ],
                      onChanged: (v) => setState(() => posSurah = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: verseC,
                      enabled: posSurah != null,
                      decoration: const InputDecoration(labelText: 'آخر آية'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (posSurah == null) return null;
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n < 1 || n > surahs[posSurah! - 1].$2) {
                          return '1 - ${surahs[posSurah! - 1].$2}';
                        }
                        return null;
                      },
                    ),
                  ),
                ]),
                const SectionTitle('جدول الحضور'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('جدول خاص بهذا الطالب'),
                  subtitle: const Text('عند الإيقاف يتبع الطالب جدول حلقته'),
                  value: ownSched,
                  onChanged: (v) => setState(() => ownSched = v),
                ),
                if (ownSched) ScheduleEditor(draft: draft),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesC,
                  decoration: const InputDecoration(labelText: 'ملاحظات عامة'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'active', label: Text('نشط')),
                    ButtonSegment(value: 'inactive', label: Text('غير نشط (مؤرشف)')),
                  ],
                  selected: {status},
                  onSelectionChanged: (s) => setState(() => status = s.first),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ'),
                ),
              ]),
            ),
    );
  }
}

// ═════════════════════════ ملف الطالب ═════════════════════════
Future<(int, int)?> askPosition(BuildContext c, int? s0, int? v0) async {
  int? surah = s0;
  final verseC = TextEditingController(text: v0?.toString() ?? '');
  String? err;
  final r = await showDialog<(int, int)>(
    context: c,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('تحديث موضع الحفظ'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(
            value: surah,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'السورة'),
            items: [
              for (var i = 0; i < 114; i++)
                DropdownMenuItem(value: i + 1, child: Text('${i + 1}. ${surahs[i].$1}')),
            ],
            onChanged: (v) => setS(() => surah = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: verseC,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'آخر آية محفوظة', errorText: err),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(verseC.text.trim());
              if (surah == null || n == null || n < 1 || n > surahs[surah! - 1].$2) {
                setS(() => err = surah == null ? 'اختر السورة' : 'رقم الآية غير صحيح');
                return;
              }
              Navigator.pop(ctx, (surah!, n));
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
  verseC.dispose();
  return r;
}

class StudentProfilePage extends StatefulWidget {
  final int id;
  const StudentProfilePage({super.key, required this.id});
  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  M? s;
  bool loading = true;
  String schedText = '';
  Map<String, int> counts = {};
  M? lastNew, lastRevision, lastAny, planned;
  List<M> recs = [], atts = [], pendingRev = [];

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
    final st = await Repo.student(widget.id);
    if (st == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    var own = await Repo.schedules(studentId: widget.id);
    var label = 'جدول خاص';
    if (own.isEmpty && st['group_id'] != null) {
      own = await Repo.schedules(groupId: iv(st['group_id']));
      label = 'جدول الحلقة';
    }
    final r = await Repo.recitationsOf(widget.id);
    final rec = r.where((x) => sv(x['rating']) != kNotRecited).toList();
    M? firstWhereOrNull(bool Function(M) f, List<M> l) {
      for (final x in l) {
        if (f(x)) return x;
      }
      return null;
    }

    // مراجعات معلّقة: تقييم «يحتاج إلى مراجعة» لم تتبعه مراجعة/تثبيت جيد لنفس السورة.
    final pend = <M>[];
    for (final x in r) {
      if (sv(x['rating']) != kNeedsRevision) continue;
      final later = r.any((y) =>
          iv(y['id']) > iv(x['id']) &&
          sv(y['surah_name']) == sv(x['surah_name']) &&
          (sv(y['recitation_type']) == 'مراجعة' || sv(y['recitation_type']) == 'تثبيت') &&
          ['ممتاز', 'جيد جداً', 'جيد'].contains(sv(y['rating'])));
      if (!later) pend.add(x);
    }
    final a = await Repo.attendanceOf(widget.id);
    final c = await Repo.attCounts(widget.id);
    if (!mounted) return;
    setState(() {
      s = st;
      schedText = own.isEmpty
          ? 'غير محدد'
          : '$label: ${ScheduleDraft.fromRows(own).summary}';
      recs = r;
      atts = a;
      counts = c;
      lastNew = firstWhereOrNull((x) => sv(x['recitation_type']) == 'حفظ جديد', rec);
      lastRevision = firstWhereOrNull((x) => sv(x['recitation_type']) == 'مراجعة', rec);
      lastAny = r.isEmpty ? null : r.first;
      planned = firstWhereOrNull((x) => assignText(x).isNotEmpty, r);
      pendingRev = pend;
      loading = false;
    });
  }

  Future<void> shareReport() async {
    final st = s!;
    final pct = attPct(counts);
    final b = StringBuffer()
      ..writeln('السلام عليكم ورحمة الله وبركاته')
      ..writeln('تقرير الطالب/ة: ${sv(st['full_name'])}')
      ..writeln(arDate(DateTime.now()))
      ..writeln()
      ..writeln('موضع الحفظ الحالي: ${posText(st['pos_surah'], st['pos_verse'])}');
    if (recs.isNotEmpty) {
      b.writeln('آخر التسميعات:');
      for (final x in recs.take(3)) {
        b.writeln('• ${recLine(x)} — ${sv(x['rating'])}');
      }
    }
    b
      ..writeln()
      ..writeln(
          'الحضور: ${pct == null ? 'لا جلسات بعد' : '${pct.round()}٪'} (حاضر ${counts['حاضر'] ?? 0}، متأخر ${counts['متأخر'] ?? 0}، غياب بعذر ${counts['اعتذار'] ?? 0}، بدون عذر ${counts['غائب'] ?? 0})');
    if (lastAny != null && sv(lastAny!['notes']).isNotEmpty) {
      b.writeln('ملاحظة المعلّم: ${sv(lastAny!['notes'])}');
    }
    if (planned != null) b.writeln('التكليف القادم: ${assignText(planned!)}');
    b
      ..writeln()
      ..write('جزاكم الله خيراً');
    final phone = sv(st['guardian_phone']).isNotEmpty ? sv(st['guardian_phone']) : sv(st['phone']);
    await openWhatsApp(context, phone, b.toString());
  }

  Future<void> remindParent() async {
    final st = s!;
    final now = DateTime.now();
    DateTime? when;
    String time = '';
    for (var i = 0; i < 8 && when == null; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      for (final x in await Repo.scheduledOn(day)) {
        if (iv((x['student'] as M)['id']) != widget.id) continue;
        time = sv(x['time']);
        final p = time.split(':');
        final dt = DateTime(day.year, day.month, day.day, int.tryParse(p[0]) ?? 0,
            p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
        if (dt.isAfter(now)) when = dt;
        break;
      }
    }
    if (!mounted) return;
    if (when == null) {
      toast(context, 'لا توجد حلقة قادمة مجدولة لهذا الطالب خلال الأسبوع');
      return;
    }
    final isToday = iso(when) == iso(now);
    final dayName = isToday ? 'اليوم' : 'يوم ${weekdayNames[when.weekday]}';
    final msg = 'السلام عليكم ورحمة الله وبركاته\n'
        'تذكير بحلقة ${sv(st['full_name'])} $dayName الساعة $time.\n'
        'جزاكم الله خيراً';
    final phone = sv(st['guardian_phone']).isNotEmpty ? sv(st['guardian_phone']) : sv(st['phone']);
    await openWhatsApp(context, phone, msg);
  }

  String recLine(M x) =>
      '${sv(x['surah_name'])} ${iv(x['start_verse'])}–${iv(x['end_verse'])} • ${arDateShort(sv(x['recitation_date']))}';

  Future<void> toggleArchive() async {
    final st = s!;
    final isActive = sv(st['status']) == 'active';
    final ok = await confirmDialog(
      context,
      isActive ? 'أرشفة الطالب' : 'إعادة تنشيط الطالب',
      isActive
          ? 'سيُنقل الطالب إلى الأرشيف ولن يظهر في الحضور. تبقى كل سجلاته محفوظة ويمكنك إعادته لاحقاً.'
          : 'سيعود الطالب إلى قائمة النشطين.',
      danger: isActive,
    );
    if (!ok) return;
    await Repo.setStudentStatus(widget.id, isActive ? 'inactive' : 'active');
    bump();
    if (mounted) toast(context, isActive ? 'تمت الأرشفة' : 'تمت إعادة التنشيط');
  }

  @override
  Widget build(BuildContext context) {
    if (loading || s == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final st = s!;
    final active = sv(st['status']) == 'active';
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(sv(st['full_name'])),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'واتساب',
              icon: const Icon(Icons.share),
              onSelected: (v) => v == 'report' ? shareReport() : remindParent(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('إرسال تقرير لولي الأمر (واتساب)')),
                PopupMenuItem(value: 'remind', child: Text('تذكير ولي الأمر بالحلقة القادمة')),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'تعديل',
              onPressed: () => push(context, StudentFormPage(id: widget.id)),
            ),
            IconButton(
              icon: Icon(active ? Icons.archive_outlined : Icons.unarchive_outlined),
              tooltip: active ? 'أرشفة' : 'إعادة تنشيط',
              onPressed: toggleArchive,
            ),
          ],
          bottom: const TabBar(
            labelColor: cream,
            unselectedLabelColor: Colors.white70,
            indicatorColor: gold,
            tabs: [Tab(text: 'نظرة عامة'), Tab(text: 'التسميع'), Tab(text: 'الحضور')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => push(context, SessionFormPage(studentId: widget.id)),
          icon: const Icon(Icons.record_voice_over),
          label: const Text('تسميع'),
        ),
        body: TabBarView(children: [overview(st, active), recTab(), attTab()]),
      ),
    );
  }

  Widget overview(M st, bool active) {
    final pct = attPct(counts);
    final absentTotal = (counts['غائب'] ?? 0) + (counts['اعتذار'] ?? 0);
    return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(sv(st['full_name']),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            active ? const Pill('نشط', Color(0xFF2E7D32)) : const Pill('مؤرشف', Colors.grey),
          ]),
          const SizedBox(height: 6),
          KV('الحلقة', sv(st['group_name'])),
          KV('الهاتف', sv(st['phone'])),
          KV('هاتف ولي الأمر', sv(st['guardian_phone'])),
          KV('الالتحاق', arDateShort(sv(st['enrollment_date']))),
          KV('الجدول', schedText),
          if (sv(st['notes']).isNotEmpty) KV('ملاحظات', sv(st['notes'])),
        ]),
      ),
      const SectionTitle('الحفظ الفعلي'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: KV('موضع الحفظ', posText(st['pos_surah'], st['pos_verse']))),
            TextButton(
              onPressed: () async {
                final r = await askPosition(context, st['pos_surah'] as int?, st['pos_verse'] as int?);
                if (r != null) {
                  await Repo.setPosition(widget.id, r.$1, r.$2);
                  bump();
                  if (mounted) toast(context, 'تم تحديث موضع الحفظ');
                }
              },
              child: const Text('تحديث'),
            ),
          ]),
          KV('آخر حفظ جديد', lastNew == null ? '' : recLine(lastNew!)),
          KV('آخر مراجعة', lastRevision == null ? '' : recLine(lastRevision!)),
          Row(children: [
            const SizedBox(width: 110, child: Text('آخر تقييم', style: TextStyle(color: Colors.black54))),
            lastAny == null
                ? const Text('—')
                : Pill(sv(lastAny!['rating']), ratingColor(sv(lastAny!['rating']))),
          ]),
        ]),
      ),
      const SectionTitle('التكليف المخطَّط (لم يُسمَّع بعد)'),
      AppCard(
        child: planned == null
            ? const Text('لا يوجد تكليف مخطَّط', style: TextStyle(color: Colors.black54))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final line in assignText(planned!).split(' • ')) Text(line),
                if (sv(planned!['next_session_date']).isNotEmpty)
                  Text('الموعد: ${arDateShort(sv(planned!['next_session_date']))}',
                      style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
                const SizedBox(height: 4),
                const Text('هذا تكليف فقط ولا يُحتسب حفظاً حتى يُسجَّل تسميعه.',
                    style: TextStyle(color: Colors.black45, fontSize: 12)),
              ]),
      ),
      const SectionTitle('الحضور'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KV('نسبة الحضور', pct == null ? 'لا جلسات بعد' : '${pct.toStringAsFixed(0)}٪'),
          KV('إجمالي الغياب', '$absentTotal'),
          KV('غياب بعذر (اعتذار)', '${counts['اعتذار'] ?? 0}'),
          KV('غياب بدون عذر', '${counts['غائب'] ?? 0}'),
          KV('حاضر / متأخر', '${counts['حاضر'] ?? 0} / ${counts['متأخر'] ?? 0}'),
        ]),
      ),
      const SectionTitle('مراجعات معلّقة ونقاط تحتاج تحسين'),
      if (pendingRev.isEmpty)
        const AppCard(child: Text('لا توجد مراجعات معلّقة', style: TextStyle(color: Colors.black54))),
      for (final x in pendingRev)
        AppCard(
          onTap: () => push(context, RecitationEditPage(id: iv(x['id']))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(recLine(x), style: const TextStyle(fontWeight: FontWeight.w600)),
            if (sv(x['mistakes']).isNotEmpty) Text('الأخطاء: ${sv(x['mistakes'])}'),
            if (sv(x['notes']).isNotEmpty) Text('ملاحظة: ${sv(x['notes'])}'),
          ]),
        ),
    ]);
  }

  Widget recTab() {
    if (recs.isEmpty) return const EmptyState(Icons.menu_book, 'لا توجد سجلات تسميع بعد');
    return ListView(padding: const EdgeInsets.only(top: 6, bottom: 90), children: [
      for (final x in recs) recTile(context, x, showName: false),
    ]);
  }

  Widget attTab() {
    if (atts.isEmpty) return const EmptyState(Icons.fact_check, 'لا توجد سجلات حضور بعد');
    return ListView(padding: const EdgeInsets.only(top: 6, bottom: 24), children: [
      for (final x in atts)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(arDate(parseIso(sv(x['session_date']))), style: const TextStyle(fontWeight: FontWeight.w600)),
                if (sv(x['notes']).isNotEmpty)
                  Text(sv(x['notes']), style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
              ]),
            ),
            Pill(sv(x['status']), statusColor(sv(x['status']))),
          ]),
        ),
    ]);
  }
}
