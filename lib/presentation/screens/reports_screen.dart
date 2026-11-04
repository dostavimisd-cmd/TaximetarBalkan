import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/currency_converter.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/ride_record.dart';
import '../../domain/report_export.dart';
import '../../domain/reports.dart';
import '../printing/report_pdf.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import 'history_screen.dart' show formatClock;
import '../l10n/tr.dart';

const Map<String, String> _mimeTypes = {
  'csv': 'text/csv',
  'pdf': 'application/pdf',
};

String _hm(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

String _shiftTime(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}. ${two(l.hour)}:${two(l.minute)}';
}

/// Redovi zbira izveštaja (ekran i PDF koriste isti spisak); null = razdelna linija.
List<(String, String)?> reportStatsRows(
  Tr t,
  RideStats stats, {
  int? eurRate,
  int? shiftSeconds,
}) => [
  (t('Ukupno'), t('{0} din', [stats.totalPrice])),
  if (eurRate != null)
    ('', t('{0} EUR', [CurrencyConverter.formatForeign(stats.totalPrice, eurRate)])),
  null,
  (
    t('Vožnji'),
    stats.interruptedCount > 0
        ? t('{0} (prekinuto {1})', [stats.rideCount, stats.interruptedCount])
        : '${stats.rideCount}',
  ),
  (t('Prosek po vožnji'), t('{0} din', [stats.averagePerRide])),
  (t('Po satu vožnje'), t('{0} din', [stats.perHour])),
  if (shiftSeconds != null && shiftSeconds > 0)
    (t('Po satu smene'), t('{0} din', [stats.perHourOver(shiftSeconds)])),
  (t('Po kilometru'), t('{0} din', [stats.perKm])),
  null,
  if (shiftSeconds != null) (t('Trajanje smene'), _hm(shiftSeconds)),
  (t('Vreme u vožnji'), _hm(stats.durationSeconds)),
  (t('Od toga čekanje'), formatClock(stats.waitingSeconds)),
  (t('Pređeno (GPS)'), t('{0} km', [(stats.distanceMeters / 1000).toStringAsFixed(2)])),
];

/// Izveštaji (Faza 3): zarada i rad po danu, nedelji i mesecu.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  Tr get t => ref.read(trProvider);
  ReportRange _range = ReportRange.containing(ReportPeriod.day, DateTime.now());

  /// null = izveštaj po periodu; inače indeks smene u listi (0 = najnovija).
  int? _shiftIndex;

  void _setPeriod(ReportPeriod p) => setState(() {
    _shiftIndex = null;
    _range = ReportRange.containing(p, _range.start);
  });

  Future<void> _toggleShift(Shift? open) async {
    final repo = ref.read(shiftRepositoryProvider);
    final now = DateTime.now().toUtc();
    if (open == null) {
      await repo.start(now);
    } else {
      await repo.end(now);
    }
    ref.invalidate(shiftsProvider);
    setState(() => _shiftIndex = 0);
  }

  /// Vožnje i naslov trenutnog prikaza (period ili smena) za izvoz.
  Future<({String period, List<RideRecord> rides, int? shiftSeconds})?>
  _current() async {
    if (_shiftIndex == null) {
      return (
        period: _range.describe(),
        rides: await ref.read(reportRidesProvider(_range).future),
        shiftSeconds: null,
      );
    }
    final list = await ref.read(shiftsProvider.future);
    if (list.isEmpty) return null;
    final shift = list[_shiftIndex!.clamp(0, list.length - 1)];
    final end = shift.endOr(DateTime.now().toUtc());
    final until = shift.end == null ? t('u toku') : _shiftTime(shift.end!);
    return (
      period: '${t('Smena')} ${_shiftTime(shift.start)} – $until',
      rides: await ref.read(shiftRidesProvider(shift).future),
      shiftSeconds: end.difference(shift.start).inSeconds,
    );
  }

  Future<void> _chooseExport() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.amberAccent),
              title: Text(
                t('PDF (za štampu i slanje)'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.amberAccent),
              title: Text(
                t('CSV (Excel, za knjigovođu)'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
          ],
        ),
      ),
    );
    if (kind != null) await _export(kind);
  }

  Future<void> _export(String kind) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final current = await _current();
      if (current == null || current.rides.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(t('Nema vožnji u ovom periodu.'))),
        );
        return;
      }
      final rides = ReportExport.ordered(current.rides);
      final settings = ref.read(appSettingsProvider).value;
      final interrupted = t('prekinuta');
      final stamp = current.period.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '_');
      final dir = await getTemporaryDirectory();
      final File file;
      if (kind == 'csv') {
        file = File(p.join(dir.path, 'izvestaj_$stamp.csv'));
        await file.writeAsString(
          ReportExport.csv(
            rides,
            headers: [
              t('Datum'),
              t('Početak'),
              t('Kraj'),
              t('Trajanje'),
              t('Km'),
              t('Čekanje'),
              t('Start'),
              t('Kilometraža'),
              t('Čekanje (din)'),
              t('Dopuna do minimalne'),
              t('Ukupno (din)'),
              t('Napomena'),
              t('Broj'),
            ],
            totalLabel: t('Ukupno'),
            interruptedLabel: interrupted,
          ),
          encoding: utf8,
          flush: true,
        );
      } else {
        final fonts = await loadReportFonts();
        final logoPath = settings?.receiptLogoPath;
        final logo = logoPath != null && await File(logoPath).exists()
            ? await File(logoPath).readAsBytes()
            : null;
        final bytes = await buildReportPdf(
          title: t('Izveštaj'),
          period: current.period,
          headerLines: (settings?.receiptHeader ?? '').split('\n'),
          logo: logo,
          summary: reportStatsRows(
            t,
            RideStats.of(rides),
            eurRate: settings?.eurRateMilli,
            shiftSeconds: current.shiftSeconds,
          ),
          columns: [
            t('Datum'),
            t('Početak'),
            t('Trajanje'),
            t('Km'),
            t('Čekanje'),
            t('Ukupno (din)'),
            t('Napomena'),
          ],
          rows: [
            for (final r in rides)
              [
                ReportExport.date(r.startTime),
                ReportExport.time(r.startTime),
                ReportExport.duration(r.activeDuration),
                ReportExport.km(r.distanceMeters),
                ReportExport.clock(r.waitingSeconds),
                '${r.totalPrice}',
                ReportExport.note(r, interruptedLabel: interrupted),
              ],
          ],
          footer: t(
            'Taksimetar Balkan — pomoćni alat za evidenciju, nije fiskalni dokument.',
          ),
          regular: fonts.regular,
          bold: fonts.bold,
        );
        file = File(p.join(dir.path, 'izvestaj_$stamp.pdf'));
        await file.writeAsBytes(bytes, flush: true);
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(file.path, mimeType: _mimeTypes[kind]),
          ],
          subject: '${t('Izveštaj')} ${current.period}',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(t('Izvoz nije uspeo: {0}', [e]))),
      );
    }
  }

  Widget _shiftView(int? eurRate) {
    final shifts = ref.watch(shiftsProvider);
    return shifts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Text(t('Greška: {0}', [e]), style: const TextStyle(color: Colors.redAccent)),
      data: (list) {
        final open = list.where((s) => s.isOpen).firstOrNull;
        final index = (_shiftIndex ?? 0).clamp(
          0,
          list.isEmpty ? 0 : list.length - 1,
        );
        final shift = list.isEmpty ? null : list[index];
        String fmt(DateTime t) => _shiftTime(t);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: open == null
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFD32F2F),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => _toggleShift(open),
              icon: Icon(
                open == null ? Icons.play_arrow : Icons.stop,
                color: Colors.white,
              ),
              label: Text(
                open == null ? t('POČNI SMENU') : t('ZAVRŠI SMENU'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (shift == null)
              Text(
                t('Još nema smena.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              )
            else ...[
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.fast_rewind,
                      color: index < list.length - 1
                          ? Colors.white70
                          : Colors.white24,
                    ),
                    onPressed: index < list.length - 1
                        ? () => setState(() => _shiftIndex = index + 1)
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      '${fmt(shift.start)} – ${shift.end == null ? t('u toku') : fmt(shift.end!)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.fast_forward,
                      color: index > 0 ? Colors.white70 : Colors.white24,
                    ),
                    onPressed: index > 0
                        ? () => setState(() => _shiftIndex = index - 1)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ref
                  .watch(shiftRidesProvider(shift))
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text(
                      t('Greška: {0}', [e]),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    data: (rides) {
                      final shiftSeconds = shift
                          .endOr(DateTime.now().toUtc())
                          .difference(shift.start)
                          .inSeconds;
                      return _StatsCard(
                        stats: RideStats.of(rides),
                        eurRate: eurRate,
                        shiftSeconds: shiftSeconds,
                      );
                    },
                  ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(trProvider); // prevod se menja sa jezikom
    final rides = ref.watch(reportRidesProvider(_range));
    final eurRate = ref.watch(appSettingsProvider).value?.eurRateMilli;
    // nema smisla ići u budućnost
    final isCurrentOrFuture = _range.next().start.isAfter(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(t('Izveštaji')),
        actions: [
          IconButton(
            tooltip: t('Izvezi izveštaj'),
            icon: const Icon(Icons.ios_share),
            onPressed: _chooseExport,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ReportPeriod?>(
            segments: [
              ButtonSegment(value: ReportPeriod.day, label: Text(t('DAN'))),
              ButtonSegment(value: ReportPeriod.week, label: Text(t('NED.'))),
              ButtonSegment(value: ReportPeriod.month, label: Text(t('MESEC'))),
              ButtonSegment(value: null, label: Text(t('SMENA'))),
            ],
            selected: {_shiftIndex == null ? _range.period : null},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              final p = s.first;
              if (p == null) {
                setState(() => _shiftIndex = 0);
              } else {
                _setPeriod(p);
              }
            },
          ),
          const SizedBox(height: 12),
          if (_shiftIndex != null)
            _shiftView(eurRate)
          else ...[
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.fast_rewind, color: Colors.white70),
                  onPressed: () => setState(() => _range = _range.previous()),
                ),
                Expanded(
                  child: Text(
                    _range.describe(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.fast_forward,
                    color: isCurrentOrFuture ? Colors.white24 : Colors.white70,
                  ),
                  onPressed: isCurrentOrFuture
                      ? null
                      : () => setState(() => _range = _range.next()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            rides.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(
                t('Greška: {0}', [e]),
                style: const TextStyle(color: Colors.redAccent),
              ),
              data: (list) =>
                  _StatsCard(stats: RideStats.of(list), eurRate: eurRate),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsCard extends ConsumerWidget {
  final RideStats stats;
  final int? eurRate;

  /// Trajanje smene (za "zarada po satu smene"); null u izveštaju po periodu.
  final int? shiftSeconds;

  const _StatsCard({
    required this.stats,
    required this.eurRate,
    this.shiftSeconds,
  });

  Widget _row(String label, String value, {bool big = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 15),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontSize: big ? 24 : 16,
            fontWeight: big ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final rows = reportStatsRows(
      t,
      stats,
      eurRate: eurRate,
      shiftSeconds: shiftSeconds,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          for (final (i, r) in rows.indexed)
            r == null
                ? const Divider(color: Colors.white12)
                : _row(r.$1, r.$2, big: i == 0),
        ],
      ),
    );
  }
}
