import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../data/services/navigation_service.dart';
import '../../domain/models/navigation.dart';
import '../providers/taximeter_provider.dart';
import 'address_search_dialog.dart';

final navigationServiceProvider = Provider<NavigationService>(
  (ref) => NavigationService(),
);

/// Mapa vožnje na OpenStreetMap podlogama (besplatno, open source).
/// Podloge traže internet; obračun ne zavisi od mape.
///
/// Napomena: javni server tile.openstreetmap.org je za malu upotrebu
/// (pravila: https://operations.osmfoundation.org/policies/tiles/). Pre
/// objave sa mnogo korisnika treba sopstveni ili plaćeni server podloga.
class RideMap extends ConsumerStatefulWidget {
  const RideMap({super.key});

  @override
  ConsumerState<RideMap> createState() => _RideMapState();
}

class _RideMapState extends ConsumerState<RideMap> {
  final _controller = MapController();
  final List<LatLng> _route = [];
  LatLng? _here;
  bool _ready = false;

  // predlog rute do odredišta (samo za orijentaciju; ne utiče na obračun)
  Place? _destination;
  RoutePlan? _plan;
  bool _routing = false;

  // Tamna mapa: invertovane boje uz sivi ton (kao "Dark" kod konkurencije).
  static const _dark = ColorFilter.matrix(<double>[
    -0.6, -0.3, -0.1, 0, 255, //
    -0.3, -0.6, -0.1, 0, 255, //
    -0.3, -0.3, -0.4, 0, 255, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  void initState() {
    super.initState();
    _locateOnce();
  }

  /// Između vožnji GPS ne radi (servis je ugašen), pa mapu centriramo na
  /// poslednju poznatu poziciju telefona.
  Future<void> _locateOnce() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p == null || !mounted) return;
      setState(() => _here = LatLng(p.latitude, p.longitude));
      if (_ready) _controller.move(_here!, 15);
    } catch (_) {
      // bez dozvole ili lokacije: ostaje podrazumevani prikaz
    }
  }

  Future<void> _findDestination() async {
    final place = await showAddressSearch(
      context,
      ref.read(navigationServiceProvider),
      nearLat: _here?.latitude,
      nearLon: _here?.longitude,
    );
    if (place == null || !mounted) return;
    setState(() {
      _destination = place;
      _plan = null;
    });
    await _routeTo(place);
  }

  Future<void> _routeTo(Place place) async {
    final from = _here;
    final to = LatLng(place.lat, place.lon);
    if (from == null) {
      _showMessage(
        'Trenutna lokacija nije poznata; prikazujem samo odredište.',
      );
      if (_ready) _controller.move(to, 15);
      return;
    }
    setState(() => _routing = true);
    try {
      final plan = await ref
          .read(navigationServiceProvider)
          .route(from.latitude, from.longitude, place.lat, place.lon);
      if (!mounted) return;
      setState(() => _plan = plan);
      if (_ready && plan.points.length > 1) {
        _controller.fitCamera(
          CameraFit.coordinates(
            coordinates: [for (final p in plan.points) LatLng(p.$1, p.$2)],
            padding: const EdgeInsets.all(36),
          ),
        );
      }
    } catch (e) {
      _showMessage('Ruta nije dostupna (internet?): $e');
      if (_ready) _controller.move(to, 15);
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  void _clearDestination() => setState(() {
    _destination = null;
    _plan = null;
  });

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _onRide(TaximeterState? prev, TaximeterState next) {
    if (next.phase == RidePhase.starting && prev?.phase != RidePhase.starting) {
      setState(_route.clear); // nova vožnja, nova linija
    }
    final lat = next.lat, lon = next.lon;
    if (!next.isRunning || lat == null || lon == null) return;
    final point = LatLng(lat, lon);
    if (_route.isNotEmpty && _route.last == point) return;
    setState(() {
      _route.add(point);
      _here = point;
    });
    if (_ready && _plan == null) {
      _controller.move(
        point,
        _controller.camera.zoom < 14 ? 16 : _controller.camera.zoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TaximeterState>(taximeterProvider, _onRide);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _here ?? const LatLng(44.0, 20.9),
              initialZoom: _here == null ? 7 : 15,
              onMapReady: () => _ready = true,
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
                ),
              ),
              if (_plan != null && _plan!.points.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        for (final p in _plan!.points) LatLng(p.$1, p.$2),
                      ],
                      strokeWidth: 6,
                      color: Colors.lightBlueAccent.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              if (_route.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: List.of(_route),
                      strokeWidth: 5,
                      color: Colors.greenAccent,
                    ),
                  ],
                ),
              if (_destination != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_destination!.lat, _destination!.lon),
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.place,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              if (_here != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _here!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.lightBlueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
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
          // Pretraga adrese (gore desno)
          Positioned(
            top: 8,
            right: 8,
            child: FloatingActionButton.small(
              heroTag: 'map_search',
              backgroundColor: const Color(0xEE1C1C1C),
              onPressed: _routing ? null : _findDestination,
              child: _routing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search, color: Colors.amberAccent),
            ),
          ),
          // Odredište i procena rute
          if (_destination != null)
            Positioned(
              left: 8,
              right: 56,
              top: 8,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
                decoration: BoxDecoration(
                  color: const Color(0xEE1C1C1C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_destination!.label.split(',').first}'
                        '${_plan == null ? '' : '\n${_plan!.describe()}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onPressed: _clearDestination,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
