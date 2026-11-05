import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/heatmap.dart';
import '../../domain/models/tariff_schedule.dart';
import '../l10n/tr.dart';
import '../providers/history_provider.dart';

/// Počeci vožnji iz istorije (učitava se pri otvaranju ekrana).
final rideStartsProvider = FutureProvider.autoDispose<List<RideStart>>(
  (ref) => ref.read(rideHistoryRepositoryProvider).getRideStarts(),
);

/// Toplotna mapa (G7): gde su vožnje počinjale, po danu i delu dana.
/// Samo iz podataka sa ovog telefona; ništa se ne šalje na internet osim
/// zahteva za podloge mape.
class HeatmapScreen extends ConsumerStatefulWidget {
  const HeatmapScreen({super.key});

  @override
  ConsumerState<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends ConsumerState<HeatmapScreen> {
  final Set<int> _days = {};
  DayPart _part = DayPart.all;
  final _controller = MapController();

  static const _dark = ColorFilter.matrix(<double>[
    -0.6, -0.3, -0.1, 0, 255, //
    -0.3, -0.6, -0.1, 0, 255, //
    -0.3, -0.3, -0.4, 0, 255, //
    0, 0, 0, 1, 0, //
  ]);

  static const _partLabels = {
    DayPart.all: 'Ceo dan',
    DayPart.morning: '06–12',
    DayPart.afternoon: '12–18',
    DayPart.evening: '18–24',
    DayPart.night: '00–06',
  };

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final starts = ref.watch(rideStartsProvider);
    final letters = TariffSchedule.letters(english: t.english);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(t('Toplotna mapa'))),
      body: starts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(t('Greška: {0}', [e]), style: const TextStyle(color: Colors.redAccent)),
        ),
        data: (all) {
          final cells = Heatmap.cells(all, weekdays: _days, part: _part);
          final top = cells.isEmpty ? 1 : cells.first.count;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < 7; i++)
                      FilterChip(
                        label: Text(letters[i]),
                        visualDensity: VisualDensity.compact,
                        showCheckmark: false,
                        selected: _days.contains(i + 1),
                        onSelected: (on) => setState(
                          () => on ? _days.add(i + 1) : _days.remove(i + 1),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final p in DayPart.values)
                      ChoiceChip(
                        label: Text(t(_partLabels[p]!)),
                        visualDensity: VisualDensity.compact,
                        selected: _part == p,
                        onSelected: (_) => setState(() => _part = p),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: cells.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            t('Nema vožnji sa zabeleženom rutom za ovaj izbor.'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: FlutterMap(
                          mapController: _controller,
                          options: MapOptions(
                            initialCameraFit: CameraFit.coordinates(
                              coordinates: [
                                for (final c in cells.take(50)) LatLng(c.lat, c.lon),
                              ],
                              padding: const EdgeInsets.all(48),
                              maxZoom: 15,
                            ),
                            minZoom: 3,
                            maxZoom: 19,
                            backgroundColor: const Color(0xFF1B1B1F),
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                            ),
                          ),
                          children: [
                            ColorFiltered(
                              colorFilter: _dark,
                              child: TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'rs.taksimetar.balkan',
                                evictErrorTileStrategy:
                                    EvictErrorTileStrategy.notVisibleRespectMargin,
                              ),
                            ),
                            CircleLayer(
                              circles: [
                                for (final c in cells.reversed)
                                  CircleMarker(
                                    point: LatLng(c.lat, c.lon),
                                    useRadiusInMeter: true,
                                    radius: 90 + 160 * sqrt(c.count / top),
                                    color: Color.lerp(
                                      Colors.amber,
                                      Colors.deepOrange,
                                      c.count / top,
                                    )!.withValues(alpha: 0.25 + 0.45 * c.count / top),
                                    borderStrokeWidth: 0,
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
              ),
              if (cells.isNotEmpty)
                SizedBox(
                  height: 132,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    children: [
                      Text(
                        t('Najjače zone (vožnji: {0})', [
                          cells.fold<int>(0, (s, c) => s + c.count),
                        ]),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      for (final (i, c) in cells.take(5).indexed)
                        ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.zero,
                          leading: Text(
                            '${i + 1}.',
                            style: const TextStyle(color: Colors.amberAccent),
                          ),
                          title: Text(
                            t('{0} vožnji', [c.count]),
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: const Icon(Icons.center_focus_strong,
                              color: Colors.white38, size: 18),
                          onTap: () => _controller.move(LatLng(c.lat, c.lon), 16),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
