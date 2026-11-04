import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/calibration.dart';
import '../../domain/currency_converter.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/gap_info.dart';
import '../../domain/models/ride_record.dart';
import '../../domain/ride_summary.dart';
import '../printing/receipt_printer.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/price_colors.dart';
import '../l10n/tr.dart';

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

  /// Vozač upiše km sa zvaničnog taksimetra; aplikacija izračuna kalibraciju
  /// iz izmerene distance i, na potvrdu, sačuva je za sledeće vožnje.
  Future<void> _calibrate(BuildContext context, WidgetRef ref) async {
    final t = ref.read(trProvider);
    final current = ref.read(appSettingsProvider).value?.calibrationPermille ??
        Calibration.neutralPermille;
    final controller = TextEditingController();
    String? error;
    final permille = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          void compute() {
            final official = Calibration.parseKm(controller.text);
            final p = official == null
                ? null
                : Calibration.fromOfficial(
                    measuredMeters: ride.distanceMeters,
                    officialMeters: official,
                  );
            if (p == null) {
              setState(
                () => error = t(
                  'Upiši km sa zvaničnog taksimetra (npr. 12,35). Razlika može biti najviše ±50%.',
                ),
              );
              return;
            }
            Navigator.pop(ctx, p);
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(
              t('Uskladi sa zvaničnim taksimetrom'),
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Aplikacija je izmerila {0} km (bez kalibracije). Koliko km je pokazao zvanični taksimetar za ovu vožnju?', [
                    (ride.distanceMeters / 1000).toStringAsFixed(2),
                  ]),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t('Zvanični taksimetar (km)'),
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                  onSubmitted: (_) => compute(),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  t('ODUSTANI'),
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: compute,
                child: Text(
                  t('IZRAČUNAJ'),
                  style: const TextStyle(color: Colors.amberAccent),
                ),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (permille == null || !context.mounted) return;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          t('Nova kalibracija: {0} %', [Calibration.formatPercent(permille)]),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          t('Trenutno: {0} %. Važi od sledeće vožnje; završene vožnje se ne menjaju. Za tačniji rezultat uporedi dužu vožnju (5 km i više).', [
            Calibration.formatPercent(current),
          ]),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t('ODUSTANI'),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t('SAČUVAJ'),
              style: const TextStyle(color: Colors.amberAccent),
            ),
          ),
        ],
      ),
    );
    if (save != true) return;
    await ref
        .read(appSettingsProvider.notifier)
        .change((s) => s.copyWith(calibrationPermille: permille));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Kalibracija sačuvana: {0} %', [
              Calibration.formatPercent(permille),
            ]),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
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
        title: Text(onNewRide != null ? t('Vožnja završena') : t('Vožnja')),
        leading: onNewRide != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (onNewRide == null)
            IconButton(
              tooltip: t('Obriši vožnju'),
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
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                t('VOŽNJA PREKINUTA · iznos do poslednjeg snimka'),
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
                : t('RSD  ·  {0} EUR', [CurrencyConverter.formatForeign(ride.totalPrice, eurRate)]),
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
                t('DISTANCA'),
                t('{0} km', [(ride.distanceMeters / 1000).toStringAsFixed(2)]),
              ),
              _Stat(
                Icons.timer_outlined,
                t('TRAJANJE'),
                duration == null ? '—' : RideSummary.clock(duration.inSeconds),
              ),
              _Stat(
                Icons.hourglass_bottom,
                t('ČEKANJE'),
                RideSummary.clock(ride.waitingSeconds),
              ),
              _Stat(Icons.speed, t('PROSEČNA BRZINA'), RideSummary.speed(ride)),
              if (ride.pausedSeconds > 0)
                _Stat(
                  Icons.pause_circle_outline,
                  t('PAUZA'),
                  RideSummary.clock(ride.pausedSeconds),
                ),
              _Stat(
                Icons.play_arrow,
                t('POČETAK'),
                RideSummary.dateTime(ride.startTime).split(' ').last,
              ),
              if (ride.endTime != null)
                _Stat(
                  Icons.stop,
                  t('KRAJ'),
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
                  _Line(t('Fiksna cena'), t('{0} din', [ride.priceWithoutExtras]))
                else ...[
                  _Line(t('Start'), t('{0} din', [ride.startPrice])),
                  _Line(t('Kilometraža'), t('{0} din', [ride.kmPrice])),
                  _Line(t('Čekanje'), t('{0} din', [ride.waitingPrice])),
                  if (ride.minPriceAdjustment > 0)
                    _Line(
                      t('Dopuna do minimalne'),
                      t('{0} din', [ride.minPriceAdjustment]),
                    ),
                ],
                for (final e in ride.extrasOr(t('Doplata')))
                  _Line(e.name, t('{0} din', [e.amount])),
                const Divider(color: Colors.white12, height: 20),
                _Line(t('UKUPNO'), t('{0} din', [ride.totalPrice]), bold: true),
              ],
            ),
          ),

          // ---- pomoćnik za kalibraciju (C2)
          if (ride.distanceMeters >= Calibration.minCompareMeters) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _calibrate(context, ref),
              icon: const Icon(Icons.straighten, color: Colors.white70),
              label: Text(
                t('Uskladi km sa zvaničnim taksimetrom'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],

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
                  label: Text(t('ŠTAMPAJ'), style: TextStyle(color: _gold)),
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
                  label: Text(t('PODELI'), style: TextStyle(color: _gold)),
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
              child: Text(
                t('NOVA VOŽNJA'),
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
          Text(
            t('Pomoćni alat za evidenciju i procenu, nije overeni službeni taksimetar ni fiskalni uređaj.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final t = ref.read(trProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          t('Obrisati vožnju?'),
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          t('{0} · {1} din\nBrisanje se ne može poništiti.', [RideSummary.dateTime(ride.startTime), ride.totalPrice]),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t('ODUSTANI'),
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t('OBRIŠI'),
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

class _RouteMap extends ConsumerWidget {
  final List<(double, double)> route;
  const _RouteMap({required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final points = [for (final p in route) LatLng(p.$1, p.$2)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 230,
        child: points.length < 2
            ? Container(
                color: _card,
                alignment: Alignment.center,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    t('Ruta nije zabeležena (vožnja je kratka ili je počela pre ove verzije).'),
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
                  RichAttributionWidget(
                    showFlutterMapAttribution: false,
                    attributions: [
                      TextSourceAttribution(t('© OpenStreetMap contributors')),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _Stat extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Stat(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class _Line extends ConsumerWidget {
  final String label;
  final String value;
  final bool bold;
  const _Line(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class _Gaps extends ConsumerWidget {
  final List<GapInfo> gaps;
  const _Gaps({required this.gaps});

  static String _what(GapInfo g) {
    switch (g.kind) {
      case GapInfo.kindWaiting:
        return 'naplaćeno kao čekanje';
      case GapInfo.kindDistance:
        return 'dodata vazdušna linija {0} m';
      case GapInfo.kindServiceRestart:
        return 'servis zaustavljen, nije mereno';
      default:
        return 'nije obračunato';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
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
            t('Prekidi GPS signala: {0} (ukupno {1})', [gaps.length, RideSummary.clock(total)]),
            style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          for (final g in gaps)
            Text(
              '${RideSummary.dateTime(g.startedAt).split(' ').last} · ${RideSummary.clock(g.durationMs ~/ 1000)} · ${t(_what(g), [g.addedDistanceMeters])}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
