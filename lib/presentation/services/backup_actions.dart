import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/database_helper.dart';
import '../../data/services/backup_service.dart';
import '../l10n/tr.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tariffs_provider.dart';
import '../providers/taximeter_provider.dart';
import 'device_service.dart';

/// Podaci pre poslednjeg vraćanja kopije (za „Poništi vraćanje”).
const String _undoFileName = 'pre_vracanja_kopije.json';

Future<File> _undoFile() async =>
    File(p.join((await getApplicationDocumentsDirectory()).path, _undoFileName));

Future<bool> hasUndoBackup() async => (await _undoFile()).exists();

String _stamp(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}_${two(d.hour)}${two(d.minute)}';
}

void _say(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

/// Automatska kopija (E15): jednom dnevno, pri otvaranju aplikacije, u
/// Download/TaksimetarBalkan. Greška ne smeta radu (sledeći put opet).
Future<void> autoBackupIfDue(WidgetRef ref) async {
  try {
    final settings = await ref.read(appSettingsProvider.future);
    if (!settings.autoBackup) return;
    final now = DateTime.now();
    final today = _stamp(now).substring(0, 10);
    if (settings.lastAutoBackup == today) return;
    final db = await DatabaseHelper.instance.database;
    final text = BackupService.encode(await BackupService.export(db));
    final ok = await DeviceService.saveToDownloads(
      'taksimetar_kopija_${_stamp(now)}.json',
      Uint8List.fromList(utf8.encode(text)),
    );
    if (!ok) return;
    await ref
        .read(appSettingsProvider.notifier)
        .change((s) => s.copyWith(lastAutoBackup: today));
  } catch (_) {
    // kopija ne sme da ometa vožnju
  }
}

/// Pravi kopiju svih podataka i nudi slanje (Viber, Drive, e-mail…).
Future<void> exportBackup(BuildContext context, WidgetRef ref) async {
  final t = ref.read(trProvider);
  try {
    final db = await DatabaseHelper.instance.database;
    final backup = await BackupService.export(db);
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'taksimetar_kopija_${_stamp(DateTime.now())}.json'),
    );
    await file.writeAsString(BackupService.encode(backup), flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Taksimetar Balkan',
      ),
    );
  } catch (e) {
    if (context.mounted) _say(context, t('Kopija nije napravljena: {0}', [e]));
  }
}

/// Vraća podatke iz izabranog fajla kopije. Vraća true ako su podaci
/// zamenjeni (ekran podešavanja tada treba zatvoriti bez snimanja).
Future<bool> restoreBackup(BuildContext context, WidgetRef ref) async {
  final t = ref.read(trProvider);
  if (ref.read(taximeterProvider).isRunning) {
    _say(context, t('Vožnja je u toku. Završi je pa vrati kopiju.'));
    return false;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(t('Vrati podatke iz kopije?'), style: const TextStyle(color: Colors.white)),
      content: Text(
        t('Sve tarife, relacije, vožnje i podešavanja na ovom telefonu biće zamenjeni podacima iz kopije. Trenutni podaci se čuvaju, pa vraćanje možeš da poništiš.'),
        style: const TextStyle(color: Colors.white70, height: 1.4),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Otkaži'))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t('IZABERI FAJL'), style: const TextStyle(color: Colors.amberAccent)),
        ),
      ],
    ),
  );
  if (ok != true) return false;

  try {
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty) return false;
    final text = utf8.decode(await picked.first.xFile.readAsBytes(), allowMalformed: true);
    final backup = BackupService.decode(text);
    if (!context.mounted) return false;
    return await _restore(context, ref, backup, saveUndo: true);
  } catch (e) {
    if (context.mounted) _say(context, t.message('$e'));
    return false;
  }
}

/// Vraća podatke kakvi su bili pre poslednjeg vraćanja kopije.
Future<bool> undoRestore(BuildContext context, WidgetRef ref) async {
  final t = ref.read(trProvider);
  if (ref.read(taximeterProvider).isRunning) {
    _say(context, t('Vožnja je u toku. Završi je pa vrati kopiju.'));
    return false;
  }
  try {
    final file = await _undoFile();
    final backup = BackupService.decode(await file.readAsString());
    if (!context.mounted) return false;
    final done = await _restore(context, ref, backup, saveUndo: false);
    if (done) await file.delete();
    return done;
  } catch (e) {
    if (context.mounted) _say(context, t.message('$e'));
    return false;
  }
}

Future<bool> _restore(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> backup, {
  required bool saveUndo,
}) async {
  final t = ref.read(trProvider);
  final db = await DatabaseHelper.instance.database;
  final docs = await getApplicationDocumentsDirectory();
  if (saveUndo) {
    final current = await BackupService.export(db);
    await (await _undoFile()).writeAsString(BackupService.encode(current), flush: true);
  }
  await BackupService.restore(db, backup, filesDir: docs.path);

  ref.invalidate(appSettingsProvider);
  ref.invalidate(tariffsProvider);
  ref.invalidate(holidaysProvider);
  ref.invalidate(fixedRoutesProvider);
  ref.invalidate(rideHistoryProvider);
  ref.invalidate(shiftsProvider);
  ref.invalidate(reportRidesProvider);

  if (context.mounted) _say(context, t('Podaci su vraćeni iz kopije.'));
  return true;
}
