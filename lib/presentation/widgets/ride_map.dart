import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../providers/taximeter_provider.dart';

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
    if (_ready) _controller.move(point, _controller.camera.zoom < 14 ? 16 : _controller.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TaximeterState>(taximeterProvider, _onRide);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: FlutterMap(
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
          if (_route.length > 1)
            PolylineLayer(polylines: [
              Polyline(points: List.of(_route), strokeWidth: 5, color: Colors.greenAccent),
            ]),
          if (_here != null)
            MarkerLayer(markers: [
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
            ]),
          const RichAttributionWidget(
            showFlutterMapAttribution: false,
            attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }
}
