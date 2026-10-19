import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/currency_converter.dart';
import '../../domain/models/shift.dart';
import '../../domain/reports.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import 'history_screen.dart' show formatClock;
import '../l10n/tr.dart';

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

  Widget _shiftView(int? eurRate) {
    final shifts = ref.watch(shiftsProvider);
    return shifts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Text('Greška: $e', style: const TextStyle(color: Colors.redAccent)),
      data: (list) {
        final open = list.where((s) => s.isOpen).firstOrNull;
        final index = (_shiftIndex ?? 0).clamp(
          0,
          list.isEmpty ? 0 : list.length - 1,
        );
        final shift = list.isEmpty ? null : list[index];
        String fmt(DateTime t) {
          final l = t.toLocal();
          String two(int v) => v.toString().padLeft(2, '0');
          return '${two(l.day)}.${two(l.month)}. ${two(l.hour)}:${two(l.minute)}';
        }

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
                open == null ? 'POČNI SMENU' : t('ZAVRŠI SMENU'),
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
        title: const Text('Izveštaji'),
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
    String hm(int seconds) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _row(t('Ukupno'), t('{0} din', [stats.totalPrice]), big: true),
          if (eurRate != null)
            _row(
              '',
              t('{0} EUR', [CurrencyConverter.formatForeign(stats.totalPrice, eurRate!)]),
            ),
          const Divider(color: Colors.white12),
          _row(
            t('Vožnji'),
            stats.interruptedCount > 0
                ? t('{0} (prekinuto {1})', [stats.rideCount, stats.interruptedCount])
                : '${stats.rideCount}',
          ),
          _row(t('Prosek po vožnji'), t('{0} din', [stats.averagePerRide])),
          _row(t('Po satu vožnje'), t('{0} din', [stats.perHour])),
          if (shiftSeconds != null && shiftSeconds! > 0)
            _row(t('Po satu smene'), t('{0} din', [stats.perHourOver(shiftSeconds!)])),
          _row(t('Po kilometru'), t('{0} din', [stats.perKm])),
          const Divider(color: Colors.white12),
          if (shiftSeconds != null) _row(t('Trajanje smene'), hm(shiftSeconds!)),
          _row(t('Vreme u vožnji'), hm(stats.durationSeconds)),
          _row(t('Od toga čekanje'), formatClock(stats.waitingSeconds)),
          _row(
            t('Pređeno (GPS)'),
            t('{0} km', [(stats.distanceMeters / 1000).toStringAsFixed(2)]),
          ),
        ],
      ),
    );
  }
}
