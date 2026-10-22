import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

typedef M = Map<String, Object?>;

/// يُزاد بعد كل عملية كتابة لتحديث الشاشات تلقائياً.
final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);
void bump() => dataVersion.value++;

// ───────────────────────── مساعدات ─────────────────────────
String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseIso(String s) {
  final x = s.split('-');
  return DateTime(int.parse(x[0]), int.parse(x[1]), int.parse(x[2]));
}

String arDate(DateTime d) => DateFormat('EEEE d MMMM y', 'ar').format(d);
String arDateShort(String isoStr) {
  if (isoStr.isEmpty) return '';
  return DateFormat('d MMM y', 'ar').format(parseIso(isoStr));
}

int iv(Object? v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String sv(Object? v) => v?.toString() ?? '';

String normName(String x) => x
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp('[\u064B-\u0652]'), '')
    .toLowerCase();

// ───────────────────────── الثوابت ─────────────────────────
const weekdayNames = {
  1: 'الإثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
  7: 'الأحد',
};
const weekOrder = [6, 7, 1, 2, 3, 4, 5];

const attStatuses = ['حاضر', 'غائب', 'اعتذار', 'متأخر'];
const recTypes = ['حفظ جديد', 'مراجعة', 'تثبيت', 'تلاوة وتجويد'];
const kNotRecited = 'لم يسمّع';
const kNeedsRevision = 'يحتاج إلى مراجعة';
const ratings = ['ممتاز', 'جيد جداً', 'جيد', kNeedsRevision, kNotRecited];

const List<(String, int)> surahs = [
  ('الفاتحة', 7), ('البقرة', 286), ('آل عمران', 200), ('النساء', 176),
  ('المائدة', 120), ('الأنعام', 165), ('الأعراف', 206), ('الأنفال', 75),
  ('التوبة', 129), ('يونس', 109), ('هود', 123), ('يوسف', 111),
  ('الرعد', 43), ('إبراهيم', 52), ('الحجر', 99), ('النحل', 128),
  ('الإسراء', 111), ('الكهف', 110), ('مريم', 98), ('طه', 135),
  ('الأنبياء', 112), ('الحج', 78), ('المؤمنون', 118), ('النور', 64),
  ('الفرقان', 77), ('الشعراء', 227), ('النمل', 93), ('القصص', 88),
  ('العنكبوت', 69), ('الروم', 60), ('لقمان', 34), ('السجدة', 30),
  ('الأحزاب', 73), ('سبأ', 54), ('فاطر', 45), ('يس', 83),
  ('الصافات', 182), ('ص', 88), ('الزمر', 75), ('غافر', 85),
  ('فصلت', 54), ('الشورى', 53), ('الزخرف', 89), ('الدخان', 59),
  ('الجاثية', 37), ('الأحقاف', 35), ('محمد', 38), ('الفتح', 29),
  ('الحجرات', 18), ('ق', 45), ('الذاريات', 60), ('الطور', 49),
  ('النجم', 62), ('القمر', 55), ('الرحمن', 78), ('الواقعة', 96),
  ('الحديد', 29), ('المجادلة', 22), ('الحشر', 24), ('الممتحنة', 13),
  ('الصف', 14), ('الجمعة', 11), ('المنافقون', 11), ('التغابن', 18),
  ('الطلاق', 12), ('التحريم', 12), ('الملك', 30), ('القلم', 52),
  ('الحاقة', 52), ('المعارج', 44), ('نوح', 28), ('الجن', 28),
  ('المزمل', 20), ('المدثر', 56), ('القيامة', 40), ('الإنسان', 31),
  ('المرسلات', 50), ('النبأ', 40), ('النازعات', 46), ('عبس', 42),
  ('التكوير', 29), ('الانفطار', 19), ('المطففين', 36), ('الانشقاق', 25),
  ('البروج', 22), ('الطارق', 17), ('الأعلى', 19), ('الغاشية', 26),
  ('الفجر', 30), ('البلد', 20), ('الشمس', 15), ('الليل', 21),
  ('الضحى', 11), ('الشرح', 8), ('التين', 8), ('العلق', 19),
  ('القدر', 5), ('البينة', 8), ('الزلزلة', 8), ('العاديات', 11),
  ('القارعة', 11), ('التكاثر', 8), ('العصر', 3), ('الهمزة', 9),
  ('الفيل', 5), ('قريش', 4), ('الماعون', 7), ('الكوثر', 3),
  ('الكافرون', 6), ('النصر', 3), ('المسد', 5), ('الإخلاص', 4),
  ('الفلق', 5), ('الناس', 6),
];

int surahIndex(String name) => surahs.indexWhere((e) => e.$1 == name) + 1; // 0 إذا لم توجد

String posText(Object? surah, Object? verse) {
  final s = iv(surah);
  if (s < 1 || s > 114) return 'لم يُحدَّد';
  return '${surahs[s - 1].$1} - آية ${iv(verse)}';
}

/// نسبة الحضور = (حاضر + متأخر) ÷ (إجمالي الجلسات − الاعتذارات). null عند عدم وجود جلسات.
double? attPct(Map<String, int> c) {
  final total = c.values.fold<int>(0, (a, b) => a + b);
  final denom = total - (c['اعتذار'] ?? 0);
  if (denom <= 0) return null;
  return ((c['حاضر'] ?? 0) + (c['متأخر'] ?? 0)) * 100 / denom;
}

// ───────────────────────── قاعدة البيانات ─────────────────────────
class AppDb {
  static Database? _db;
  static const fileName = 'werd.db';
  static const version = 1;

  static Future<String> path() async => p.join(await getDatabasesPath(), fileName);

  static Future<Database> get db async => _db ??= await _open();

  static Future<Database> _open() async {
    return openDatabase(
      await path(),
      version: version,
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        for (final s in _schema) {
          await d.execute(s);
        }
      },
      // عند التحديثات المستقبلية: أضف هنا ALTER TABLE فقط، ولا تحذف أي بيانات.
    );
  }

  static Future<void> close() async {
    final d = _db;
    _db = null;
    await d?.close();
  }

  static const _schema = [
    '''CREATE TABLE study_groups(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      notes TEXT)''',
    '''CREATE TABLE students(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      full_name TEXT NOT NULL,
      phone TEXT,
      guardian_phone TEXT,
      enrollment_date TEXT NOT NULL,
      group_id INTEGER REFERENCES study_groups(id) ON DELETE SET NULL,
      pos_surah INTEGER,
      pos_verse INTEGER,
      memorization_position TEXT,
      notes TEXT,
      status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','inactive')),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL)''',
    '''CREATE TABLE schedules(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER REFERENCES students(id) ON DELETE CASCADE,
      group_id INTEGER REFERENCES study_groups(id) ON DELETE CASCADE,
      weekday INTEGER NOT NULL CHECK(weekday BETWEEN 1 AND 7),
      start_time TEXT NOT NULL,
      duration_minutes INTEGER NOT NULL DEFAULT 30,
      is_active INTEGER NOT NULL DEFAULT 1,
      CHECK((student_id IS NULL) <> (group_id IS NULL)))''',
    '''CREATE TABLE attendance(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE RESTRICT,
      session_date TEXT NOT NULL,
      session_start_time TEXT,
      status TEXT NOT NULL CHECK(status IN ('حاضر','غائب','اعتذار','متأخر')),
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE(student_id, session_date))''',
    '''CREATE TABLE recitations(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE RESTRICT,
      recitation_date TEXT NOT NULL,
      recitation_type TEXT NOT NULL,
      surah_name TEXT,
      start_verse INTEGER,
      end_verse INTEGER,
      rating TEXT NOT NULL,
      mistakes TEXT,
      notes TEXT,
      next_assignment TEXT,
      next_session_date TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL)''',
    '''CREATE TABLE recitation_history(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      recitation_id INTEGER NOT NULL REFERENCES recitations(id) ON DELETE CASCADE,
      snapshot TEXT NOT NULL,
      edited_at TEXT NOT NULL)''',
    'CREATE INDEX idx_att_date ON attendance(session_date)',
    'CREATE INDEX idx_rec_student ON recitations(student_id, recitation_date)',
    'CREATE INDEX idx_sched_weekday ON schedules(weekday)',
    'CREATE INDEX idx_students_group ON students(group_id)',
  ];
}

// ───────────────────────── المستودع ─────────────────────────
class Repo {
  static Future<Database> get _d => AppDb.db;
  static String _now() => DateTime.now().toIso8601String();

  // الطلاب
  static Future<List<M>> students({String q = '', String? status}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (q.trim().isNotEmpty) {
      where.add('s.full_name LIKE ?');
      args.add('%${q.trim()}%');
    }
    if (status != null) {
      where.add('s.status = ?');
      args.add(status);
    }
    return (await _d).rawQuery(
      'SELECT s.*, g.name AS group_name FROM students s '
      'LEFT JOIN study_groups g ON g.id = s.group_id '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY s.full_name',
      args,
    );
  }

  static Future<M?> student(int id) async {
    final r = await (await _d).rawQuery(
        'SELECT s.*, g.name AS group_name FROM students s LEFT JOIN study_groups g ON g.id = s.group_id WHERE s.id = ?',
        [id]);
    return r.isEmpty ? null : r.first;
  }

  static Future<String?> findDuplicate(String name, {int? excludeId}) async {
    final key = normName(name);
    final all = await (await _d).query('students', columns: ['id', 'full_name']);
    for (final r in all) {
      if (excludeId != null && iv(r['id']) == excludeId) continue;
      if (normName(sv(r['full_name'])) == key) return sv(r['full_name']);
    }
    return null;
  }

  static Future<int> saveStudent(M v, {int? id}) async {
    final d = await _d;
    final t = _now();
    if (id == null) {
      return d.insert('students', {...v, 'created_at': t, 'updated_at': t});
    }
    await d.update('students', {...v, 'updated_at': t}, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  static Future<void> setStudentStatus(int id, String status) async {
    await (await _d).update('students', {'status': status, 'updated_at': _now()},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> setPosition(int id, int surah, int verse) async {
    await (await _d).update(
        'students',
        {
          'pos_surah': surah,
          'pos_verse': verse,
          'memorization_position': posText(surah, verse),
          'updated_at': _now(),
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  // المجموعات
  static Future<List<M>> groups() async => (await _d).rawQuery(
      "SELECT g.*, (SELECT COUNT(*) FROM students s WHERE s.group_id = g.id AND s.status = 'active') AS cnt "
      'FROM study_groups g ORDER BY g.name');

  static Future<M?> group(int id) async {
    final r = await (await _d).query('study_groups', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  static Future<bool> groupNameExists(String name, {int? excludeId}) async {
    final r = await (await _d).query('study_groups', columns: ['id', 'name']);
    final key = normName(name);
    return r.any((x) => normName(sv(x['name'])) == key && iv(x['id']) != (excludeId ?? -1));
  }

  static Future<int> saveGroup(String name, String notes, {int? id}) async {
    final d = await _d;
    if (id == null) return d.insert('study_groups', {'name': name, 'notes': notes});
    await d.update('study_groups', {'name': name, 'notes': notes}, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  static Future<void> assignMembers(int groupId, Set<int> ids) async {
    final d = await _d;
    await d.transaction((txn) async {
      await txn.rawUpdate(
          "UPDATE students SET group_id = NULL WHERE group_id = ? AND status = 'active'", [groupId]);
      for (final id in ids) {
        await txn.update('students', {'group_id': groupId, 'updated_at': _now()},
            where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  static Future<void> deleteGroup(int id) async {
    await (await _d).delete('study_groups', where: 'id = ?', whereArgs: [id]);
  }

  // الجداول
  static Future<List<M>> schedules({int? studentId, int? groupId}) async =>
      (await _d).query('schedules',
          where: studentId != null ? 'student_id = ?' : 'group_id = ?',
          whereArgs: [studentId ?? groupId],
          orderBy: 'weekday');

  static Future<void> replaceSchedules(
      {int? studentId,
      int? groupId,
      required Set<int> days,
      required String time,
      required int duration}) async {
    final d = await _d;
    final col = studentId != null ? 'student_id' : 'group_id';
    final id = studentId ?? groupId;
    await d.transaction((txn) async {
      await txn.delete('schedules', where: '$col = ?', whereArgs: [id]);
      for (final w in days) {
        await txn.insert('schedules', {
          col: id,
          'weekday': w,
          'start_time': time,
          'duration_minutes': duration,
          'is_active': 1,
        });
      }
    });
  }

  /// الطلاب المجدولون في يوم معيّن. الجدول الخاص بالطالب يتقدّم على جدول مجموعته.
  /// الطالب غير المجدول لا يظهر (وبالتالي لا يُحتسب غائباً أبداً).
  static Future<List<M>> scheduledOn(DateTime date) async {
    final d = await _d;
    final studs = await d.query('students', where: "status = 'active'", orderBy: 'full_name');
    final all = await d.query('schedules', where: 'is_active = 1');
    final ds = iso(date);
    final res = <M>[];
    for (final s in studs) {
      final enr = sv(s['enrollment_date']);
      if (enr.isNotEmpty && ds.compareTo(enr) < 0) continue;
      final own = all.where((x) => x['student_id'] != null && x['student_id'] == s['id']).toList();
      final eff = own.isNotEmpty
          ? own
          : all.where((x) => x['group_id'] != null && x['group_id'] == s['group_id']).toList();
      for (final x in eff) {
        if (iv(x['weekday']) == date.weekday) {
          res.add({'student': s, 'time': x['start_time'], 'duration': x['duration_minutes']});
          break;
        }
      }
    }
    res.sort((a, b) {
      final c = sv(a['time']).compareTo(sv(b['time']));
      if (c != 0) return c;
      return sv((a['student'] as M)['full_name']).compareTo(sv((b['student'] as M)['full_name']));
    });
    return res;
  }

  // الحضور
  static Future<Map<int, M>> attendanceOn(String date) async {
    final r = await (await _d).query('attendance', where: 'session_date = ?', whereArgs: [date]);
    return {for (final x in r) iv(x['student_id']): x};
  }

  static Future<void> setAttendance(int sid, String date, String? time, String status,
      {String? notes}) async {
    final d = await _d;
    final t = _now();
    final ex = await d.query('attendance',
        where: 'student_id = ? AND session_date = ?', whereArgs: [sid, date]);
    if (ex.isEmpty) {
      await d.insert('attendance', {
        'student_id': sid,
        'session_date': date,
        'session_start_time': time,
        'status': status,
        'notes': notes ?? '',
        'created_at': t,
        'updated_at': t,
      });
    } else {
      await d.update(
          'attendance',
          {'status': status, if (notes != null) 'notes': notes, 'updated_at': t},
          where: 'id = ?',
          whereArgs: [ex.first['id']]);
    }
  }

  static Future<void> setAttendanceNote(int attId, String notes) async {
    await (await _d).update('attendance', {'notes': notes, 'updated_at': _now()},
        where: 'id = ?', whereArgs: [attId]);
  }

  static Future<List<M>> attendanceOf(int sid) async => (await _d).query('attendance',
      where: 'student_id = ?', whereArgs: [sid], orderBy: 'session_date DESC');

  static Future<Map<String, int>> attCounts(int sid, {String? from, String? to}) async {
    final w = StringBuffer('student_id = ?');
    final a = <Object?>[sid];
    if (from != null) {
      w.write(' AND session_date >= ?');
      a.add(from);
    }
    if (to != null) {
      w.write(' AND session_date <= ?');
      a.add(to);
    }
    final r = await (await _d).rawQuery(
        'SELECT status, COUNT(*) c FROM attendance WHERE $w GROUP BY status', a);
    return {for (final x in r) sv(x['status']): iv(x['c'])};
  }

  // التسميع
  static Future<List<M>> recitationsOn(String date) async => (await _d).rawQuery(
      'SELECT r.*, s.full_name FROM recitations r JOIN students s ON s.id = r.student_id '
      'WHERE r.recitation_date = ? ORDER BY r.id DESC',
      [date]);

  static Future<List<M>> recitationsOf(int sid) async => (await _d).query('recitations',
      where: 'student_id = ?', whereArgs: [sid], orderBy: 'recitation_date DESC, id DESC');

  static Future<M?> recitation(int id) async {
    final r = await (await _d).query('recitations', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  static Future<Set<int>> recitedIds(String date) async {
    final r = await (await _d).query('recitations',
        columns: ['student_id'], where: 'recitation_date = ?', whereArgs: [date]);
    return r.map((x) => iv(x['student_id'])).toSet();
  }

  static Future<M?> latestRec(int sid, {String? type, bool onlyRecited = false}) async {
    final w = StringBuffer('student_id = ?');
    final a = <Object?>[sid];
    if (type != null) {
      w.write(' AND recitation_type = ?');
      a.add(type);
    }
    if (onlyRecited) {
      w.write(' AND rating <> ?');
      a.add(kNotRecited);
    }
    final r = await (await _d).query('recitations',
        where: w.toString(),
        whereArgs: a,
        orderBy: 'recitation_date DESC, id DESC',
        limit: 1);
    return r.isEmpty ? null : r.first;
  }

  /// يحفظ التسميع. تُحدَّث موضع الحفظ فقط إذا أكّد المعلّم ذلك (updatePosition).
  static Future<int> saveRecitation(M v, {int? id, bool updatePosition = false}) async {
    final d = await _d;
    final t = _now();
    return d.transaction<int>((txn) async {
      int rid;
      if (id == null) {
        rid = await txn.insert('recitations', {...v, 'created_at': t, 'updated_at': t});
      } else {
        final old = await txn.query('recitations', where: 'id = ?', whereArgs: [id]);
        if (old.isNotEmpty) {
          await txn.insert('recitation_history',
              {'recitation_id': id, 'snapshot': jsonEncode(old.first), 'edited_at': t});
        }
        await txn.update('recitations', {...v, 'updated_at': t}, where: 'id = ?', whereArgs: [id]);
        rid = id;
      }
      if (updatePosition) {
        final si = surahIndex(sv(v['surah_name']));
        final ev = iv(v['end_verse']);
        if (si > 0 && ev > 0) {
          await txn.update(
              'students',
              {
                'pos_surah': si,
                'pos_verse': ev,
                'memorization_position': posText(si, ev),
                'updated_at': t,
              },
              where: 'id = ?',
              whereArgs: [v['student_id']]);
        }
      }
      return rid;
    });
  }

  static Future<List<M>> recitationHistory(int id) async => (await _d).query(
      'recitation_history',
      where: 'recitation_id = ?',
      whereArgs: [id],
      orderBy: 'id DESC');

  static Future<void> deleteRecitation(int id) async {
    await (await _d).delete('recitations', where: 'id = ?', whereArgs: [id]);
  }

  static Future<Map<String, int>> totals() async {
    final d = await _d;
    Future<int> c(String t) async => iv((await d.rawQuery('SELECT COUNT(*) c FROM $t')).first['c']);
    return {
      'students': await c('students'),
      'attendance': await c('attendance'),
      'recitations': await c('recitations'),
      'groups': await c('study_groups'),
    };
  }
}

// ───────────────────────── النسخ الاحتياطي ─────────────────────────
class Backup {
  static Future<Uint8List> exportBytes() async {
    await AppDb.close();
    try {
      return await File(await AppDb.path()).readAsBytes();
    } finally {
      await AppDb.db; // إعادة فتح القاعدة
    }
  }

  /// يتحقق من الملف ويعيد ملخص محتوياته، أو يرمي رسالة خطأ نصية.
  static Future<Map<String, int>> validate(Uint8List bytes) async {
    if (bytes.length < 100 ||
        ascii.decode(bytes.sublist(0, 15), allowInvalid: true) != 'SQLite format 3') {
      throw 'الملف ليس نسخة احتياطية صالحة';
    }
    final tmp = p.join(await getDatabasesPath(), 'restore_check.db');
    await File(tmp).writeAsBytes(bytes, flush: true);
    Database? t;
    try {
      t = await openDatabase(tmp, readOnly: true);
      final names = (await t.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
          .map((e) => sv(e['name']))
          .toSet();
      for (final need in ['students', 'study_groups', 'schedules', 'attendance', 'recitations']) {
        if (!names.contains(need)) throw 'النسخة لا تحتوي على الجدول المطلوب: $need';
      }
      final ic = await t.rawQuery('PRAGMA integrity_check');
      if (sv(ic.first.values.first) != 'ok') throw 'الملف تالف';
      final ver = iv((await t.rawQuery('PRAGMA user_version')).first.values.first);
      if (ver > AppDb.version) throw 'النسخة أحدث من إصدار التطبيق الحالي';
      Future<int> c(String tb) async =>
          iv((await t!.rawQuery('SELECT COUNT(*) c FROM $tb')).first['c']);
      return {
        'students': await c('students'),
        'attendance': await c('attendance'),
        'recitations': await c('recitations'),
        'groups': await c('study_groups'),
      };
    } on DatabaseException {
      throw 'الملف تالف أو غير صالح';
    } finally {
      await t?.close();
      final f = File(tmp);
      if (await f.exists()) await f.delete();
    }
  }

  /// يستبدل قاعدة البيانات الحالية بالنسخة (بعد التحقق منها). يحتفظ بنسخة أمان تلقائية.
  static Future<void> restore(Uint8List bytes) async {
    await validate(bytes);
    final cur = await AppDb.path();
    final safety = p.join(await getDatabasesPath(), 'werd_before_restore.db');
    await AppDb.close();
    final hadCurrent = await File(cur).exists();
    if (hadCurrent) await File(cur).copy(safety);
    try {
      await File(cur).writeAsBytes(bytes, flush: true);
      for (final suf in ['-wal', '-shm', '-journal']) {
        final f = File('$cur$suf');
        if (await f.exists()) await f.delete();
      }
      await AppDb.db;
    } catch (_) {
      await AppDb.close();
      if (hadCurrent) await File(safety).copy(cur);
      await AppDb.db;
      rethrow;
    }
    bump();
  }
}

Uint8List csvBytes(List<String> headers, List<List<String>> rows) {
  String q(String x) => '"${x.replaceAll('"', '""')}"';
  final sb = StringBuffer()..writeln(headers.map(q).join(','));
  for (final r in rows) {
    sb.writeln(r.map(q).join(','));
  }
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(sb.toString())]);
}
