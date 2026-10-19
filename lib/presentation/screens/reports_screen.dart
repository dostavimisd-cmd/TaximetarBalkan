import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/currency_converter.dart';
import '../../domain/reports.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import 'history_screen.dart' show formatClock;

/// Izveštaji (Faza 3): zarada i rad po danu, nedelji i mesecu.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportRange _range = ReportRange.containing(ReportPeriod.day, DateTime.now());

  void _setPeriod(ReportPeriod p) =>
      setState(() => _range = ReportRange.containing(p, _range.start));

  @override
  Widget build(BuildContext context) {
    final rides = ref.watch(reportRidesProvider(_range));
    final eurRate = ref.watch(appSettingsProvider).value?.eurRateMilli;
    // nema smisla ići u budućnost
    final isCurrentOrFuture = _range.next().start.isAfter(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('Izveštaji')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ReportPeriod>(
            segments: const [
              ButtonSegment(value: ReportPeriod.day, label: Text('DAN')),
              ButtonSegment(value: ReportPeriod.week, label: Text('NEDELJA')),
              ButtonSegment(value: ReportPeriod.month, label: Text('MESEC')),
            ],
            selected: {_range.period},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _setPeriod(s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.fast_rewind, color: Colors.white70),
                onPressed: () => setState(() => _range = _range.previous()),
              ),
              Expanded(
                child: Text(_range.describe(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: Icon(Icons.fast_forward,
                    color: isCurrentOrFuture ? Colors.white24 : Colors.white70),
                onPressed: isCurrentOrFuture ? null : () => setState(() => _range = _range.next()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          rides.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Text('Greška: $e', style: const TextStyle(color: Colors.redAccent)),
            data: (list) => _StatsCard(stats: RideStats.of(list), eurRate: eurRate),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final RideStats stats;
  final int? eurRate;

  const _StatsCard({required this.stats, required this.eurRate});

  Widget _row(String label, String value, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 15)),
            Text(value,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: big ? 24 : 16,
                  fontWeight: big ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
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
          _row('Ukupno', '${stats.totalPrice} din', big: true),
          if (eurRate != null)
            _row('', '${CurrencyConverter.formatForeign(stats.totalPrice, eurRate!)} EUR'),
          const Divider(color: Colors.white12),
          _row('Vožnji', '${stats.rideCount}'
              '${stats.interruptedCount > 0 ? ' (prekinuto ${stats.interruptedCount})' : ''}'),
          _row('Prosek po vožnji', '${stats.averagePerRide} din'),
          _row('Po satu vožnje', '${stats.perHour} din'),
          _row('Po kilometru', '${stats.perKm} din'),
          const Divider(color: Colors.white12),
          _row('Vreme u vožnji', hm(stats.durationSeconds)),
          _row('Od toga čekanje', formatClock(stats.waitingSeconds)),
          _row('Pređeno (GPS)', '${(stats.distanceMeters / 1000).toStringAsFixed(2)} km'),
        ],
      ),
    );
  }
}
