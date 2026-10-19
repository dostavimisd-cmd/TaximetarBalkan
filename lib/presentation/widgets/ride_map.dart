import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../data/services/navigation_service.dart';
import '../../domain/fare_estimate.dart';
import '../../domain/models/navigation.dart';
import '../../domain/models/tariff.dart';
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
  /// Tarifa koja bi važila za vožnju (za približnu cenu do odredišta).
  final Tariff? tariff;
  final int calibrationPermille;

  /// Fiksna relacija izabrana za sledeću vožnju (tada je cena tačna).
  final int? fixedPrice;

  const RideMap({
    super.key,
    this.tariff,
    this.calibrationPermille = 1000,
    this.fixedPrice,
  });

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

  // Živa pozicija dok vožnja ne traje (servis je tada ugašen, pa GPS ne radi).
  // Tokom vožnje poziciju šalje servis i ovaj tok se zatvara.
  StreamSubscription<Position>? _idleSub;
  bool _centeredOnce = false;

  @override
  void initState() {
    super.initState();
    if (!ref.read(taximeterProvider).isRunning) _startIdleLocation();
  }

  @override
  void dispose() {
    _idleSub?.cancel();
    super.dispose();
  }

  /// Prvo svež fiks (ne keširana "poslednja poznata" tačka, koja može biti
  /// stara kilometrima), pa tok sa pomerajem od 5 m dok je ekran otvoren.
  Future<void> _startIdleLocation() async {
    if (_idleSub != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      _idleSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_onIdlePosition, onError: (_) {});
      // brz prvi prikaz dok tok ne stigne
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));
      _onIdlePosition(first);
    } catch (_) {
      // bez dozvole, GPS-a ili vremena: ostaje poslednja poznata tačka
      if (_here == null) {
        try {
          final p = await Geolocator.getLastKnownPosition();
          if (p != null) _onIdlePosition(p);
        } catch (_) {}
      }
    }
  }

  void _stopIdleLocation() {
    _idleSub?.cancel();
    _idleSub = null;
  }

  void _onIdlePosition(Position p) {
    if (!mounted) return;
    final here = LatLng(p.latitude, p.longitude);
    setState(() => _here = here);
    // kamera prati samo prvi fiks; posle toga korisnik slobodno pomera mapu
    if (_ready && !_centeredOnce) {
      _centeredOnce = true;
      _controller.move(here, 16);
    }
  }

  /// Dugme "moja lokacija": vraća kameru na poziciju (i pali živu lokaciju).
  void _recenter() {
    if (_here != null && _ready) _controller.move(_here!, 16);
    if (!ref.read(taximeterProvider).isRunning) _startIdleLocation();
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

  /// "≈ 3870 din" po tarifi (bez čekanja) ili tačna fiksna cena.
  String _estimate() {
    final plan = _plan, tariff = widget.tariff;
    if (plan == null || (tariff == null && widget.fixedPrice == null)) {
      return '';
    }
    final price = FareEstimate.forRoute(
      tariff:
          tariff ??
          const Tariff(
            startPrice: 0,
            pricePerKm: 0,
            waitingParaPerMin: 0,
            minPrice: 0,
          ),
      distanceMeters: plan.distanceMeters,
      calibrationPermille: widget.calibrationPermille,
      fixedPrice: widget.fixedPrice,
    );
    return widget.fixedPrice != null
        ? '\nFiksna cena: $price din'
        : '\n≈ $price din (bez čekanja)';
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
    // Servis preuzima GPS pri vožnji; ovde se tok zatvara i otvara posle nje.
    if (next.isRunning && !(prev?.isRunning ?? false)) {
      _stopIdleLocation();
    } else if (!next.isRunning && (prev?.isRunning ?? false)) {
      _centeredOnce = false;
      _startIdleLocation();
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
          // Moja lokacija (dole desno)
          Positioned(
            bottom: 28,
            right: 8,
            child: FloatingActionButton.small(
              heroTag: 'map_locate',
              backgroundColor: const Color(0xEE1C1C1C),
              onPressed: _recenter,
              child: const Icon(
                Icons.my_location,
                color: Colors.lightBlueAccent,
              ),
            ),
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
                        '${_plan == null ? '' : '\n${_plan!.describe()}${_estimate()}'}',
                        maxLines: 3,
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
