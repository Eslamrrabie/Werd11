import 'dart:convert';

import 'package:flutter/material.dart';

import 'core.dart';
import 'ui.dart';

// ───────────── مدخل نطاق (سورة + من آية + إلى آية) ─────────────
class RangeCtl {
  String? surah;
  final TextEditingController fromC = TextEditingController();
  final TextEditingController toC = TextEditingController();

  RangeCtl([this.surah, int? from, int? to]) {
    if (from != null && from > 0) fromC.text = '$from';
    if (to != null && to > 0) toC.text = '$to';
  }

  int? get from => int.tryParse(fromC.text.trim());
  int? get to => int.tryParse(toC.text.trim());

  void setAll(String? s, int? f, int? t) {
    surah = s;
    fromC.text = (f == null || f < 1) ? '' : '$f';
    toC.text = (t == null || t < 1) ? '' : '$t';
  }

  void dispose() {
    fromC.dispose();
    toC.dispose();
  }
}

class RangeInput extends StatefulWidget {
  final RangeCtl c;
  final String label;
  final bool required;
  final VoidCallback? onHistory;
  const RangeInput({
    super.key,
    required this.c,
    required this.label,
    this.required = false,
    this.onHistory,
  });
  @override
  State<RangeInput> createState() => _RangeInputState();
}

class _RangeInputState extends State<RangeInput> {
  String? _check(String? v, {required bool isTo}) {
    final s = widget.c.surah;
    if (s == null) return null;
    final si = surahIndex(s);
    if (si < 1) return null;
    final max = surahs[si - 1].$2;
    final txt = (v ?? '').trim();
    if (txt.isEmpty) return widget.required ? '1 - $max' : null;
    final n = int.tryParse(txt);
    if (n == null || n < 1 || n > max) return '1 - $max';
    if (isTo) {
      final f = widget.c.from;
      if (f != null && n < f) return 'أقل من البداية';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(widget.label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: emerald)),
        ),
        if (widget.onHistory != null)
          TextButton.icon(
            onPressed: widget.onHistory,
            icon: const Icon(Icons.history, size: 18),
            label: const Text('من الحفظ السابق'),
          ),
      ]),
      DropdownButtonFormField<String?>(
        value: c.surah,
        isExpanded: true,
        decoration: InputDecoration(labelText: widget.required ? 'السورة *' : 'السورة'),
        items: [
          if (!widget.required) const DropdownMenuItem<String?>(value: null, child: Text('— بدون —')),
          for (var i = 0; i < 114; i++)
            DropdownMenuItem<String?>(value: surahs[i].$1, child: Text('${i + 1}. ${surahs[i].$1}')),
        ],
        validator: (v) => (widget.required && v == null) ? 'اختر السورة' : null,
        onChanged: (v) => setState(() => c.surah = v),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: c.fromC,
            enabled: c.surah != null,
            decoration: const InputDecoration(labelText: 'من آية'),
            keyboardType: TextInputType.number,
            validator: (v) => _check(v, isTo: false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: c.toC,
            enabled: c.surah != null,
            decoration: const InputDecoration(labelText: 'إلى آية'),
            keyboardType: TextInputType.number,
            validator: (v) => _check(v, isTo: true),
          ),
        ),
      ]),
    ]);
  }
}

Future<void> pickMemorized(BuildContext context, int studentId, RangeCtl target) async {
  final list = await Repo.memorizedRanges(studentId);
  if (!context.mounted) return;
  if (list.isEmpty) {
    toast(context, 'لا يوجد حفظ جديد مسجَّل لهذا الطالب بعد');
    return;
  }
  final picked = await showDialog<M>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('اختر من الحفظ السابق'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(shrinkWrap: true, children: [
          for (final x in list)
            ListTile(
              dense: true,
              title: Text('${sv(x['surah_name'])} ${iv(x['start_verse'])}–${iv(x['end_verse'])}'),
              subtitle: Text(arDateShort(sv(x['recitation_date']))),
              onTap: () => Navigator.pop(ctx, x),
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ),
  );
  if (picked != null) {
    target.setAll(sv(picked['surah_name']), iv(picked['start_verse']), iv(picked['end_verse']));
  }
}

M _assignMap(RangeCtl n, RangeCtl r) => {
      'next_new_surah': n.surah ?? '',
      'next_new_from': n.from,
      'next_new_to': n.to,
      'next_rev_surah': r.surah ?? '',
      'next_rev_from': r.from,
      'next_rev_to': r.to,
    };

class _Part {
  String type;
  String? rating;
  final RangeCtl range;
  final TextEditingController mistakes = TextEditingController();
  final TextEditingController notes = TextEditingController();
  _Part(this.type, {String? surah, int? from, int? to}) : range = RangeCtl(surah, from, to);
  void dispose() {
    range.dispose();
    mistakes.dispose();
    notes.dispose();
  }
}

// ═════════════════ جلسة تسميع (عدة أجزاء في نفس الحصة) ═════════════════
class SessionFormPage extends StatefulWidget {
  final int? studentId;
  final DateTime? date;
  const SessionFormPage({super.key, this.studentId, this.date});
  @override
  State<SessionFormPage> createState() => _SessionFormPageState();
}

class _SessionFormPageState extends State<SessionFormPage> {
  final form = GlobalKey<FormState>();
  List<M> students = [];
  int? studentId;
  DateTime date = DateTime.now();
  DateTime? nextDate;
  final List<_Part> parts = [];
  final List<_Part> trash = [];
  final RangeCtl newA = RangeCtl();
  final RangeCtl revA = RangeCtl();
  M? lastAssign;
  bool updatePos = true;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    for (final p in [...parts, ...trash]) {
      p.dispose();
    }
    newA.dispose();
    revA.dispose();
    super.dispose();
  }

  Future<void> init() async {
    date = widget.date ?? DateTime.now();
    studentId = widget.studentId;
    students = await Repo.students(status: 'active');
    parts.add(_Part(recTypes[0]));
    if (studentId != null) await loadStudentContext(studentId!);
    if (mounted) setState(() => loading = false);
  }

  Future<void> loadStudentContext(int id) async {
    lastAssign = await Repo.lastAssignment(id);
    // اقتراح فقط: السورة والآية التالية بعد موضع الحفظ الفعلي (لا يغيّر شيئاً حتى تحفظ).
    final s = await Repo.student(id);
    final first = parts.isEmpty ? null : parts.first;
    if (s != null && first != null && first.type == 'حفظ جديد' && first.range.surah == null) {
      final si = iv(s['pos_surah']);
      final pv = iv(s['pos_verse']);
      if (si >= 1 && si <= 114) {
        if (pv < surahs[si - 1].$2) {
          first.range.setAll(surahs[si - 1].$1, pv + 1, null);
        } else if (si < 114) {
          first.range.setAll(surahs[si].$1, 1, null);
        }
      }
    }
  }

  void fillFromAssignment() {
    final a = lastAssign;
    if (a == null) return;
    final fresh = <_Part>[];
    if (sv(a['next_new_surah']).isNotEmpty) {
      fresh.add(_Part('حفظ جديد',
          surah: sv(a['next_new_surah']), from: iv(a['next_new_from']), to: iv(a['next_new_to'])));
    }
    if (sv(a['next_rev_surah']).isNotEmpty) {
      fresh.add(_Part('مراجعة',
          surah: sv(a['next_rev_surah']), from: iv(a['next_rev_from']), to: iv(a['next_rev_to'])));
    }
    if (fresh.isEmpty) return;
    setState(() {
      trash.addAll(parts);
      parts
        ..clear()
        ..addAll(fresh);
    });
  }

  void addPart() {
    final used = parts.map((p) => p.type).toSet();
    final next = recTypes.firstWhere((t) => !used.contains(t), orElse: () => 'مراجعة');
    setState(() => parts.add(_Part(next)));
  }

  _Part? get confirmPart {
    for (final p in parts.reversed) {
      if (p.type == 'حفظ جديد' &&
          p.rating != null &&
          p.rating != kNotRecited &&
          p.range.surah != null &&
          p.range.to != null) {
        return p;
      }
    }
    return null;
  }

  Future<void> save() async {
    if (studentId == null) {
      toast(context, 'اختر الطالب أولاً');
      return;
    }
    if (parts.any((p) => p.rating == null)) {
      toast(context, 'اختر تقييماً لكل جزء');
      return;
    }
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final assign = _assignMap(newA, revA);
      final rows = <M>[];
      for (var i = 0; i < parts.length; i++) {
        final p = parts[i];
        final first = i == 0;
        rows.add({
          'student_id': studentId,
          'recitation_date': iso(date),
          'recitation_type': p.type,
          'surah_name': p.range.surah ?? '',
          'start_verse': p.range.from,
          'end_verse': p.range.to,
          'rating': p.rating,
          'mistakes': p.mistakes.text.trim(),
          'notes': p.notes.text.trim(),
          // التكليف القادم يُخزَّن مع أول جزء فقط
          'next_assignment': first ? assignText(assign) : '',
          'next_session_date': (first && nextDate != null) ? iso(nextDate!) : '',
          if (first) ...assign,
        });
      }
      final cp = confirmPart;
      await Repo.saveSession(
        rows,
        studentId: (updatePos && cp != null) ? studentId : null,
        posSurah: cp?.range.surah,
        posVerse: cp?.range.to,
      );
      bump();
      if (!mounted) return;
      toast(context, 'تم حفظ التسميع (${rows.length} ${rows.length == 1 ? 'جزء' : 'أجزاء'})');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, 'تعذّر الحفظ: $e');
      }
    }
  }

  Widget partCard(int i) {
    final p = parts[i];
    final notRec = p.rating == kNotRecited;
    return AppCard(
      key: ObjectKey(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('الجزء ${i + 1}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: emerald)),
          const Spacer(),
          if (parts.length > 1)
            IconButton(
              tooltip: 'حذف الجزء',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => trash.add(parts.removeAt(i))),
            ),
        ]),
        Wrap(spacing: 6, children: [
          for (final t in recTypes)
            ChoiceChip(
              label: Text(t),
              selected: p.type == t,
              onSelected: (_) => setState(() => p.type = t),
            ),
        ]),
        const SizedBox(height: 10),
        RangeInput(
          c: p.range,
          label: 'المقطع',
          required: !notRec,
          onHistory: (studentId != null && (p.type == 'مراجعة' || p.type == 'تثبيت'))
              ? () async {
                  await pickMemorized(context, studentId!, p.range);
                  if (mounted) setState(() {});
                }
              : null,
        ),
        const SizedBox(height: 10),
        const Text('التقييم', style: TextStyle(fontWeight: FontWeight.bold, color: emerald)),
        Wrap(spacing: 6, children: [
          for (final r in ratings)
            ChoiceChip(
              label: Text(r),
              selected: p.rating == r,
              selectedColor: ratingColor(r).withOpacity(.22),
              onSelected: (_) => setState(() => p.rating = r),
            ),
        ]),
        const SizedBox(height: 10),
        TextFormField(
          controller: p.mistakes,
          decoration: const InputDecoration(labelText: 'الأخطاء (عدد أو وصف)'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: p.notes,
          decoration: const InputDecoration(labelText: 'ملاحظات المعلّم'),
          maxLines: 2,
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = confirmPart;
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل تسميع')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : students.isEmpty
              ? const EmptyState(Icons.person_off, 'أضف طالباً أولاً من قسم «الطلاب»')
              : Form(
                  key: form,
                  child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: DropdownButtonFormField<int>(
                        value: studentId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'الطالب *'),
                        items: [
                          for (final s in students)
                            DropdownMenuItem(value: iv(s['id']), child: Text(sv(s['full_name']))),
                        ],
                        onChanged: (v) async {
                          setState(() {
                            studentId = v;
                            lastAssign = null;
                          });
                          if (v != null) {
                            await loadStudentContext(v);
                            if (mounted) setState(() {});
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event),
                        label: Text('التاريخ: ${arDate(date)}'),
                        onPressed: () async {
                          final d = await pickDate(context, date);
                          if (d != null) setState(() => date = d);
                        },
                      ),
                    ),
                    if (lastAssign != null)
                      AppCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('تكليف الجلسة السابقة',
                              style: TextStyle(fontWeight: FontWeight.bold, color: emerald)),
                          const SizedBox(height: 4),
                          Text(assignText(lastAssign!)),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: fillFromAssignment,
                              icon: const Icon(Icons.playlist_add_check),
                              label: const Text('تعبئة الأجزاء من هذا التكليف'),
                            ),
                          ),
                        ]),
                      ),
                    for (var i = 0; i < parts.length; i++) partCard(i),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: OutlinedButton.icon(
                        onPressed: addPart,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة جزء (حفظ / مراجعة / تثبيت / تلاوة)'),
                      ),
                    ),
                    const SectionTitle('التكليف القادم (مخطَّط فقط)'),
                    AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        RangeInput(c: newA, label: 'حفظ جديد — المرة القادمة'),
                        const SizedBox(height: 14),
                        RangeInput(c: revA, label: 'مراجعة (حفظ قديم) — المرة القادمة'),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.event_available),
                              label: Text(nextDate == null ? 'موعد الجلسة القادمة' : arDate(nextDate!)),
                              onPressed: () async {
                                final d = await pickDate(context, nextDate ?? date);
                                if (d != null) setState(() => nextDate = d);
                              },
                            ),
                          ),
                          if (nextDate != null)
                            IconButton(
                                icon: const Icon(Icons.clear), onPressed: () => setState(() => nextDate = null)),
                        ]),
                      ]),
                    ),
                    if (cp != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: updatePos,
                          onChanged: (v) => setState(() => updatePos = v ?? false),
                          title: Text('أؤكد أن الطالب سمّع فعلاً — حدّث موضع حفظه إلى ${cp.range.surah} آية ${cp.range.to}'),
                          subtitle: const Text('لا يتغيّر موضع الحفظ بالتكليف، فقط بتأكيدك هنا'),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: FilledButton.icon(
                        onPressed: saving ? null : save,
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ'),
                      ),
                    ),
                  ]),
                ),
    );
  }
}

// ═════════════════ تعديل سجل تسميع واحد ═════════════════
class RecitationEditPage extends StatefulWidget {
  final int id;
  const RecitationEditPage({super.key, required this.id});
  @override
  State<RecitationEditPage> createState() => _RecitationEditPageState();
}

class _RecitationEditPageState extends State<RecitationEditPage> {
  final form = GlobalKey<FormState>();
  final mistakesC = TextEditingController();
  final notesC = TextEditingController();
  final RangeCtl range = RangeCtl();
  final RangeCtl newA = RangeCtl();
  final RangeCtl revA = RangeCtl();
  int studentId = 0;
  String studentName = '';
  DateTime date = DateTime.now();
  DateTime? nextDate;
  String type = recTypes[0];
  String? rating;
  bool updatePos = false;
  int editCount = 0;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    mistakesC.dispose();
    notesC.dispose();
    range.dispose();
    newA.dispose();
    revA.dispose();
    super.dispose();
  }

  Future<void> init() async {
    final r = await Repo.recitation(widget.id);
    if (r == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    studentId = iv(r['student_id']);
    studentName = sv((await Repo.student(studentId))?['full_name']);
    date = parseIso(sv(r['recitation_date']));
    type = sv(r['recitation_type']);
    rating = sv(r['rating']);
    range.setAll(sv(r['surah_name']).isEmpty ? null : sv(r['surah_name']), iv(r['start_verse']), iv(r['end_verse']));
    mistakesC.text = sv(r['mistakes']);
    notesC.text = sv(r['notes']);
    newA.setAll(sv(r['next_new_surah']).isEmpty ? null : sv(r['next_new_surah']), iv(r['next_new_from']), iv(r['next_new_to']));
    revA.setAll(sv(r['next_rev_surah']).isEmpty ? null : sv(r['next_rev_surah']), iv(r['next_rev_from']), iv(r['next_rev_to']));
    nextDate = sv(r['next_session_date']).isEmpty ? null : parseIso(sv(r['next_session_date']));
    editCount = (await Repo.recitationHistory(widget.id)).length;
    if (mounted) setState(() => loading = false);
  }

  bool get notRecited => rating == kNotRecited;
  bool get canUpdatePos =>
      type == 'حفظ جديد' && !notRecited && range.surah != null && range.to != null;

  Future<void> save() async {
    if (rating == null) {
      toast(context, 'اختر التقييم');
      return;
    }
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final assign = _assignMap(newA, revA);
      await Repo.saveRecitation({
        'student_id': studentId,
        'recitation_date': iso(date),
        'recitation_type': type,
        'surah_name': range.surah ?? '',
        'start_verse': range.from,
        'end_verse': range.to,
        'rating': rating,
        'mistakes': mistakesC.text.trim(),
        'notes': notesC.text.trim(),
        'next_assignment': assignText(assign),
        'next_session_date': nextDate == null ? '' : iso(nextDate!),
        ...assign,
      }, id: widget.id, updatePosition: updatePos && canUpdatePos);
      bump();
      if (!mounted) return;
      toast(context, 'تم حفظ التعديل (والنسخة السابقة محفوظة)');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, 'تعذّر الحفظ: $e');
      }
    }
  }

  Future<void> delete() async {
    final ok = await confirmDialog(context, 'حذف السجل',
        'سيُحذف سجل التسميع هذا نهائياً مع سجل تعديلاته. لن يتغير موضع حفظ الطالب.',
        ok: 'حذف', danger: true);
    if (!ok) return;
    await Repo.deleteRecitation(widget.id);
    bump();
    if (mounted) {
      toast(context, 'تم الحذف');
      Navigator.pop(context);
    }
  }

  Future<void> showHistory() async {
    final h = await Repo.recitationHistory(widget.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('النسخ السابقة لهذا السجل'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(shrinkWrap: true, children: [
            for (final x in h)
              Builder(builder: (_) {
                final o = jsonDecode(sv(x['snapshot'])) as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  title: Text('${o['recitation_type']} • ${o['surah_name']} ${o['start_verse'] ?? ''}–${o['end_verse'] ?? ''} • ${o['rating']}'),
                  subtitle: Text('عُدّل في ${sv(x['edited_at']).split('T').first}'
                      '${sv(o['notes']).isEmpty ? '' : '\n${o['notes']}'}'),
                );
              }),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل التسميع'),
        actions: [IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'حذف', onPressed: delete)],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: form,
              child: ListView(padding: const EdgeInsets.all(14), children: [
                Text(studentName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text('التاريخ: ${arDate(date)}'),
                  onPressed: () async {
                    final d = await pickDate(context, date);
                    if (d != null) setState(() => date = d);
                  },
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 6, children: [
                  for (final t in recTypes)
                    ChoiceChip(label: Text(t), selected: type == t, onSelected: (_) => setState(() => type = t)),
                ]),
                const SizedBox(height: 10),
                RangeInput(
                  c: range,
                  label: 'المقطع',
                  required: !notRecited,
                  onHistory: (type == 'مراجعة' || type == 'تثبيت')
                      ? () async {
                          await pickMemorized(context, studentId, range);
                          if (mounted) setState(() {});
                        }
                      : null,
                ),
                const SectionTitle('التقييم'),
                Wrap(spacing: 6, children: [
                  for (final r in ratings)
                    ChoiceChip(
                      label: Text(r),
                      selected: rating == r,
                      selectedColor: ratingColor(r).withOpacity(.22),
                      onSelected: (_) => setState(() => rating = r),
                    ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: mistakesC,
                  decoration: const InputDecoration(labelText: 'الأخطاء (عدد أو وصف)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesC,
                  decoration: const InputDecoration(labelText: 'ملاحظات المعلّم'),
                  maxLines: 3,
                ),
                const SectionTitle('التكليف القادم (مخطَّط فقط)'),
                RangeInput(c: newA, label: 'حفظ جديد — المرة القادمة'),
                const SizedBox(height: 12),
                RangeInput(c: revA, label: 'مراجعة (حفظ قديم) — المرة القادمة'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_available),
                      label: Text(nextDate == null ? 'موعد الجلسة القادمة' : arDate(nextDate!)),
                      onPressed: () async {
                        final d = await pickDate(context, nextDate ?? date);
                        if (d != null) setState(() => nextDate = d);
                      },
                    ),
                  ),
                  if (nextDate != null)
                    IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => nextDate = null)),
                ]),
                if (canUpdatePos)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: updatePos,
                    onChanged: (v) => setState(() => updatePos = v ?? false),
                    title: const Text('حدّث موضع حفظ الطالب إلى نهاية هذا التسميع'),
                    subtitle: const Text('لا يتغيّر الموضع إلا بتأكيدك'),
                  ),
                if (editCount > 0)
                  TextButton.icon(
                    onPressed: showHistory,
                    icon: const Icon(Icons.history),
                    label: Text('عُدّل هذا السجل $editCount مرة — عرض النسخ السابقة'),
                  ),
                const SizedBox(height: 16),
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
