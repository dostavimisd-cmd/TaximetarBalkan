import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/currency_converter.dart';
import '../../domain/models/gap_info.dart';
import '../../domain/models/ride_record.dart';
import '../providers/history_provider.dart';
import '../printing/receipt_printer.dart';
import '../providers/settings_provider.dart';

String formatDateTime(DateTime utc) {
  final t = utc.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
}

/// Šta je obračunato za rupu u signalu.
String gapDescription(GapInfo g) {
  switch (g.kind) {
    case GapInfo.kindWaiting:
      return 'naplaćeno kao čekanje (${formatClock(g.addedWaitingMs ~/ 1000)})';
    case GapInfo.kindDistance:
      return 'dodata vazdušna linija ${g.addedDistanceMeters} m';
    case GapInfo.kindServiceRestart:
      return 'servis zaustavljen, nije mereno';
    default:
      return 'nije obračunato';
  }
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
          child: Text('Greška pri čitanju istorije: $e',
              style: const TextStyle(color: Colors.redAccent)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('Još nema završenih vožnji.',
                  style: TextStyle(color: Colors.white54)),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Colors.white10),
            itemBuilder: (_, i) => _RideTile(ride: list[i], eurRate: eurRate),
          );
        },
      ),
    );
  }
}

class _RideTile extends StatelessWidget {
  final RideRecord ride;
  final int? eurRate;

  const _RideTile({required this.ride, required this.eurRate});

  @override
  Widget build(BuildContext context) {
    final duration = ride.duration;
    final details = [
      '${(ride.distanceMeters / 1000).toStringAsFixed(2)} km',
      if (duration != null) formatClock(duration.inSeconds),
    ].join(' · ');

    return ListTile(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _RideDetailsDialog(ride: ride, eurRate: eurRate),
      ),
      title: Text(formatDateTime(ride.startTime),
          style: const TextStyle(color: Colors.white)),
      subtitle: Row(
        children: [
          Text(details, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          if (ride.isInterrupted) ...[
            const SizedBox(width: 8),
            const Text('PREKINUTA',
                style: TextStyle(
                    color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
      trailing: Text('${ride.totalPrice}',
          style: const TextStyle(
              fontFamily: 'monospace',
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _RideDetailsDialog extends ConsumerWidget {
  final RideRecord ride;
  final int? eurRate;

  const _RideDetailsDialog({required this.ride, required this.eurRate});

  Widget _line(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      color: Colors.white,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value, style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = ride.duration;
    final gaps = ref.watch(rideGapsProvider(ride.id)).value ?? const <GapInfo>[];
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(formatDateTime(ride.startTime),
          style: const TextStyle(color: Colors.white, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ride.isInterrupted)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Vožnja je prekinuta (servis zaustavljen). Iznos je do poslednjeg snimka.',
                style: TextStyle(color: Colors.amberAccent, fontSize: 12),
              ),
            ),
          _line('Distanca', '${(ride.distanceMeters / 1000).toStringAsFixed(2)} km'),
          if (duration != null) _line('Trajanje', formatClock(duration.inSeconds)),
          _line('Čekanje', formatClock(ride.waitingSeconds)),
          const Divider(color: Colors.white12),
          _line('Start', '${ride.startPrice}'),
          _line('Kilometraža', '${ride.kmPrice}'),
          _line('Čekanje', '${ride.waitingPrice}'),
          if (ride.minPriceAdjustment > 0)
            _line('Dopuna do minimalne', '${ride.minPriceAdjustment}'),
          const Divider(color: Colors.white12),
          _line('UKUPNO', '${ride.totalPrice} din', bold: true),
          if (eurRate != null)
            _line('', '${CurrencyConverter.formatForeign(ride.totalPrice, eurRate!)} EUR'),
          if (gaps.isNotEmpty) ...[
            const Divider(color: Colors.white12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Prekidi GPS signala: ${gaps.length} '
                '(ukupno ${formatClock(gaps.fold<int>(0, (a, g) => a + g.durationMs) ~/ 1000)})',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
              ),
            ),
            ...gaps.map((g) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${formatDateTime(g.startedAt).substring(11)} · '
                    '${formatClock(g.durationMs ~/ 1000)} · ${gapDescription(g)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                )),
          ],
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Obriši vožnju',
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                title: const Text('Obrisati vožnju?', style: TextStyle(color: Colors.white)),
                content: Text(
                  '${formatDateTime(ride.startTime)} · ${ride.totalPrice} din\nBrisanje se ne može poništiti.',
                  style: const TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('ODUSTANI', style: TextStyle(color: Colors.white54)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('OBRIŠI', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            );
            if (ok != true || !context.mounted) return;
            await ref.read(rideHistoryRepositoryProvider).delete(ride.id);
            ref.invalidate(rideHistoryProvider);
            if (context.mounted) Navigator.pop(context);
          },
        ),
        if (ref.watch(appSettingsProvider).value?.printerMac != null)
          TextButton.icon(
            onPressed: () => printRideReceipt(context, ref, ride.id),
            icon: const Icon(Icons.print, color: Colors.amberAccent, size: 18),
            label: const Text('ŠTAMPAJ', style: TextStyle(color: Colors.amberAccent)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ZATVORI', style: TextStyle(color: Colors.amberAccent)),
        ),
      ],
    );
  }
}
