import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/ride_record.dart';
import '../providers/history_provider.dart';
import 'ride_summary_screen.dart';
import '../providers/settings_provider.dart';
import '../l10n/tr.dart';

String formatDateTime(DateTime utc) {
  final t = utc.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
}


String formatClock(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Istorija vožnji (samo za čitanje).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final rides = ref.watch(rideHistoryProvider);
    final eurRate = ref.watch(appSettingsProvider).value?.eurRateMilli;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Istorija vožnji'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(rideHistoryProvider),
          ),
        ],
      ),
      body: rides.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            t('Greška pri čitanju istorije: {0}', [e]),
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                t('Još nema završenih vožnji.'),
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: Colors.white10),
            itemBuilder: (_, i) => _RideTile(ride: list[i], eurRate: eurRate),
          );
        },
      ),
    );
  }
}

class _RideTile extends ConsumerWidget {
  final RideRecord ride;
  final int? eurRate;

  const _RideTile({required this.ride, required this.eurRate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final duration = ride.duration;
    final details = [
      t('{0} km', [(ride.distanceMeters / 1000).toStringAsFixed(2)]),
      if (duration != null) formatClock(duration.inSeconds),
    ].join(' · ');

    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RideSummaryScreen(ride: ride)),
      ),
      title: Text(
        formatDateTime(ride.startTime),
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Row(
        children: [
          Text(
            details,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (ride.isInterrupted) ...[
            const SizedBox(width: 8),
            Text(
              t('PREKINUTA'),
              style: TextStyle(
                color: Colors.amberAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
      trailing: Text(
        '${ride.totalPrice}',
        style: const TextStyle(
          fontFamily: 'monospace',
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
