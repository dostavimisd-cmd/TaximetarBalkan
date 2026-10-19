import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/currency_converter.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/gap_info.dart';
import '../../domain/models/ride_record.dart';
import '../../domain/ride_summary.dart';
import '../printing/receipt_printer.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/price_colors.dart';

const _gold = Color(0xFFFFC107);
const _card = Color(0xFF141414);

/// Rezime vožnje: cena, pređena ruta na mapi, statistika, razrada obračuna,
/// prekidi signala; štampa, deljenje i (iz istorije) brisanje.
///
/// [onNewRide] != null znači da je vožnja upravo završena: tada se nudi
/// "NOVA VOŽNJA". Iz istorije se umesto toga nudi brisanje.
class RideSummaryScreen extends ConsumerWidget {
  final RideRecord ride;
  final VoidCallback? onNewRide;

  const RideSummaryScreen({super.key, required this.ride, this.onNewRide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final route = ref.watch(rideRouteProvider(ride.id)).value ?? const [];
    final gaps =
        ref.watch(rideGapsProvider(ride.id)).value ?? const <GapInfo>[];
    final eurRate = settings.eurRateMilli;
    final color = priceColorOf(settings.priceColor);
    final duration = ride.duration;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(onNewRide != null ? 'Vožnja završena' : 'Vožnja'),
        leading: onNewRide != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (onNewRide == null)
            IconButton(
              tooltip: 'Obriši vožnju',
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _confirmDelete(context, ref),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          // ---- naslov: datum, relacija / prekinuta
          Text(
            RideSummary.dateTime(ride.startTime),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          if (ride.fixedRouteName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                ride.fixedRouteName!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (ride.isInterrupted)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'VOŽNJA PREKINUTA · iznos do poslednjeg snimka',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.amberAccent, fontSize: 12),
              ),
            ),

          // ---- cena
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${ride.totalPrice}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 88,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: -3,
              ),
            ),
          ),
          Text(
            eurRate == null
                ? 'RSD'
                : 'RSD  ·  ${CurrencyConverter.formatForeign(ride.totalPrice, eurRate)} EUR',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, letterSpacing: 2),
          ),

          // ---- mapa rute
          const SizedBox(height: 16),
          _RouteMap(route: route),

          // ---- statistika
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _Stat(
                Icons.straighten,
                'DISTANCA',
                '${(ride.distanceMeters / 1000).toStringAsFixed(2)} km',
              ),
              _Stat(
                Icons.timer_outlined,
                'TRAJANJE',
                duration == null ? '—' : RideSummary.clock(duration.inSeconds),
              ),
              _Stat(
                Icons.hourglass_bottom,
                'ČEKANJE',
                RideSummary.clock(ride.waitingSeconds),
              ),
              _Stat(Icons.speed, 'PROSEČNA BRZINA', RideSummary.speed(ride)),
              if (ride.pausedSeconds > 0)
                _Stat(
                  Icons.pause_circle_outline,
                  'PAUZA',
                  RideSummary.clock(ride.pausedSeconds),
                ),
              _Stat(
                Icons.play_arrow,
                'POČETAK',
                RideSummary.dateTime(ride.startTime).split(' ').last,
              ),
              if (ride.endTime != null)
                _Stat(
                  Icons.stop,
                  'KRAJ',
                  RideSummary.dateTime(ride.endTime!).split(' ').last,
                ),
            ],
          ),

          // ---- razrada obračuna
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                if (ride.fixedRouteName != null)
                  _Line('Fiksna cena', '${ride.totalPrice} din')
                else ...[
                  _Line('Start', '${ride.startPrice} din'),
                  _Line('Kilometraža', '${ride.kmPrice} din'),
                  _Line('Čekanje', '${ride.waitingPrice} din'),
                  if (ride.minPriceAdjustment > 0)
                    _Line(
                      'Dopuna do minimalne',
                      '${ride.minPriceAdjustment} din',
                    ),
                ],
                const Divider(color: Colors.white12, height: 20),
                _Line('UKUPNO', '${ride.totalPrice} din', bold: true),
              ],
            ),
          ),

          // ---- prekidi signala
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Gaps(gaps: gaps),
          ],

          // ---- akcije
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => printRideReceipt(context, ref, ride.id),
                  icon: const Icon(Icons.print, color: _gold),
                  label: const Text('ŠTAMPAJ', style: TextStyle(color: _gold)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: _gold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text: RideSummary.shareText(
                        ride,
                        header: settings.receiptHeader.split('\n').first,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.share, color: _gold),
                  label: const Text('PODELI', style: TextStyle(color: _gold)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: _gold),
                  ),
                ),
              ),
            ],
          ),
          if (onNewRide != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                onNewRide!();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'NOVA VOŽNJA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Pomoćni alat za evidenciju i procenu, nije overeni službeni taksimetar ni fiskalni uređaj.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Obrisati vožnju?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${RideSummary.dateTime(ride.startTime)} · ${ride.totalPrice} din\nBrisanje se ne može poništiti.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'ODUSTANI',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'OBRIŠI',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(rideHistoryRepositoryProvider).delete(ride.id);
    ref.invalidate(rideHistoryProvider);
    if (context.mounted) Navigator.pop(context);
  }
}

class _RouteMap extends StatelessWidget {
  final List<(double, double)> route;
  const _RouteMap({required this.route});

  @override
  Widget build(BuildContext context) {
    final points = [for (final p in route) LatLng(p.$1, p.$2)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 230,
        child: points.length < 2
            ? Container(
                color: _card,
                alignment: Alignment.center,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Ruta nije zabeležena (vožnja je kratka ili je počela pre ove verzije).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              )
            : FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(36),
                    maxZoom: 17,
                  ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      -0.6, -0.3, -0.1, 0, 255, //
                      -0.3, -0.6, -0.1, 0, 255, //
                      -0.3, -0.3, -0.4, 0, 255, //
                      0, 0, 0, 1, 0, //
                    ]),
                    child: TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'rs.taksimetar.balkan',
                    ),
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        strokeWidth: 5,
                        color: Colors.greenAccent,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: points.first,
                        width: 22,
                        height: 22,
                        child: const Icon(
                          Icons.trip_origin,
                          color: Colors.lightBlueAccent,
                          size: 22,
                        ),
                      ),
                      Marker(
                        point: points.last,
                        width: 36,
                        height: 36,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.place,
                          color: Colors.redAccent,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                  const RichAttributionWidget(
                    showFlutterMapAttribution: false,
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Stat(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: _gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Line(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: bold ? Colors.white : Colors.white60,
              fontWeight: bold ? FontWeight.bold : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontWeight: bold ? FontWeight.bold : null,
              fontSize: bold ? 18 : 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _Gaps extends StatelessWidget {
  final List<GapInfo> gaps;
  const _Gaps({required this.gaps});

  static String _what(GapInfo g) {
    switch (g.kind) {
      case GapInfo.kindWaiting:
        return 'naplaćeno kao čekanje';
      case GapInfo.kindDistance:
        return 'dodata vazdušna linija ${g.addedDistanceMeters} m';
      case GapInfo.kindServiceRestart:
        return 'servis zaustavljen, nije mereno';
      default:
        return 'nije obračunato';
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = gaps.fold<int>(0, (a, g) => a + g.durationMs) ~/ 1000;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x14FFC107),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x55FFC107)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prekidi GPS signala: ${gaps.length} (ukupno ${RideSummary.clock(total)})',
            style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          for (final g in gaps)
            Text(
              '${RideSummary.dateTime(g.startedAt).split(' ').last} · ${RideSummary.clock(g.durationMs ~/ 1000)} · ${_what(g)}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
