import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}

/// Rezervna kopija svih podataka vozača u jednom JSON fajlu: tarife,
/// praznici, fiksne relacije, podešavanja, vožnje (sa rutom i prekidima
/// signala), smene i slike logoa.
///
/// Uvoz ZAMENJUJE sve postojeće podatke, u jednoj transakciji: ako bilo šta
/// ne uspe, baza ostaje kakva je bila. Kopija iz novije verzije aplikacije
/// se odbija; iz starije se prima (migracije samo dodaju kolone, a kolone
/// kojih nema u kopiji dobijaju podrazumevanu vrednost).
class BackupService {
  static const String app = 'taksimetar_balkan';
  static const int format = 1;

  /// Tabele u kopiji. `ride_snapshots` se ne čuva (služi samo vožnji u toku).
  static const List<String> tables = [
    'app_settings',
    'tariffs',
    'holidays',
    'fixed_routes',
    'rides',
    'ride_gaps',
    'ride_points',
    'shifts',
  ];

  /// Ključevi podešavanja koji pokazuju na sliku (fajl ide u kopiju).
  static const List<String> imageKeys = ['receipt_logo', 'background_logo'];

  static Future<Map<String, dynamic>> export(Database db, {DateTime? now}) async {
    final data = <String, dynamic>{};
    for (final table in tables) {
      data[table] = await db.query(table);
    }
    final files = <String, dynamic>{};
    for (final row in data['app_settings'] as List) {
      final key = row['key'];
      final path = row['value'];
      if (!imageKeys.contains(key) || path is! String || path.isEmpty) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      files[key as String] = {
        'name': p.basename(path),
        'data': base64Encode(await file.readAsBytes()),
      };
    }
    return {
      'app': app,
      'format': format,
      'schema': await db.getVersion(),
      'exported_at': (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
      'tables': data,
      'files': files,
    };
  }

  static String encode(Map<String, dynamic> backup) => jsonEncode(backup);

  /// Čita fajl kopije; baca [BackupException] ako nije ispravan.
  static Map<String, dynamic> decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const BackupException('Fajl nije rezervna kopija ove aplikacije.');
    }
    if (json is! Map<String, dynamic> || json['app'] != app) {
      throw const BackupException('Fajl nije rezervna kopija ove aplikacije.');
    }
    return json;
  }

  /// Vraća podatke iz kopije. Slike se upisuju u [filesDir], a putanje u
  /// podešavanjima se prepravljaju na nove fajlove.
  static Future<void> restore(
    Database db,
    Map<String, dynamic> backup, {
    required String filesDir,
  }) async {
    final schema = backup['schema'];
    if (backup['format'] != format || schema is! int) {
      throw const BackupException('Fajl nije rezervna kopija ove aplikacije.');
    }
    if (schema > await db.getVersion()) {
      throw const BackupException(
        'Kopija je napravljena novijom verzijom aplikacije. Prvo ažuriraj aplikaciju.',
      );
    }
    final data = backup['tables'];
    if (data is! Map<String, dynamic> ||
        tables.any((t) => data[t] is! List) ||
        tables.any((t) => (data[t] as List).any((r) => r is! Map))) {
      throw const BackupException('Rezervna kopija je oštećena.');
    }

    final active = await db.query(
      'rides',
      where: 'status = ?',
      whereArgs: ['active'],
      limit: 1,
    );
    if (active.isNotEmpty) {
      throw const BackupException('Vožnja je u toku. Završi je pa vrati kopiju.');
    }

    // Slike prvo (nova imena, stari fajlovi ostaju); ako baza ne uspe, brišemo ih.
    final written = <File>[];
    final newPaths = <String, String>{};
    try {
      final files = backup['files'];
      if (files is Map<String, dynamic>) {
        for (final key in imageKeys) {
          final f = files[key];
          if (f is! Map || f['data'] is! String) continue;
          final name = p.basename('${f['name'] ?? 'logo.png'}');
          final stamp = DateTime.now().millisecondsSinceEpoch;
          final file = File(p.join(filesDir, 'restored_${stamp}_${key}_$name'));
          await file.writeAsBytes(base64Decode(f['data'] as String), flush: true);
          written.add(file);
          newPaths[key] = file.path;
        }
      }

      await db.transaction((txn) async {
        await txn.delete('ride_snapshots');
        for (final table in tables) {
          final columns = (await txn.rawQuery('PRAGMA table_info($table)'))
              .map((c) => c['name'] as String)
              .toSet();
          await txn.delete(table);
          for (final raw in data[table] as List) {
            final row = <String, Object?>{
              for (final e in (raw as Map).entries)
                if (columns.contains(e.key)) e.key as String: e.value as Object?,
            };
            if (table == 'app_settings' && imageKeys.contains(row['key'])) {
              // putanja sa starog telefona ne postoji; nova ili prazno
              row['value'] = newPaths[row['key']] ?? '';
            }
            await txn.insert(table, row);
          }
        }
      });
    } catch (e) {
      for (final f in written) {
        try {
          await f.delete();
        } catch (_) {}
      }
      if (e is BackupException) rethrow;
      throw BackupException('Vraćanje kopije nije uspelo, podaci nisu menjani: $e');
    }
  }
}
