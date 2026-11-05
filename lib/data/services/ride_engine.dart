import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../domain/calibration.dart';
import '../../domain/fare_calculator.dart';
import '../../domain/location_filter.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/extra_charge.dart';
import '../../domain/models/gap_info.dart';
import '../../domain/models/fare_result.dart';
import '../../domain/models/location_point.dart';
import '../../domain/models/tariff.dart';
import '../../domain/ride_tracker.dart';
import '../../domain/smart_waiter.dart';

typedef EventSink = void Function(Map<String, dynamic> event);

/// Logika vožnje iz foreground servisa, bez zavisnosti od plugin-a:
/// komande (start/stop/status) redom, upis u bazu, snapshot i oporavak.
///
/// `RideTaskHandler` je samo lepak: prosleđuje komande i GPS tačke, a na
/// [onTrackingStart]/[onTrackingStop] pali i gasi GPS stream i snapshot timer.
class RideEngine {
  RideEngine({
    required Future<Database> Function() database,
    required EventSink send,
    int Function()? nowMs,
    this.onTrackingStart,
    this.onTrackingStop,
  })  : _database = database,
        _send = send,
        _nowMs = nowMs ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  static const String statusActive = 'active';
  static const String statusCompleted = 'completed';
  static const String statusInterrupted = 'interrupted';

  // Oporavak dozvoljen samo ako je snapshot mlađi od 5 minuta
  static const int maxSnapshotAgeMs = 5 * 60 * 1000;

  /// Prag brzine ispod koje se računa čekanje (km/h) i prag GPS tačnosti (m)
  /// podešava korisnik; podrazumevane vrednosti su u [AppSettings].
  static const int defaultWaitingSpeedKmh = AppSettings.defaultWaitingSpeedKmh;

  static RideTracker _newTracker(Tariff tariff, int calibrationPermille,
          int? speedKmh, int? gpsAccuracyM) =>
      RideTracker(
        tariff: tariff,
        calibrationPermille: calibrationPermille,
        filter: LocationFilter(
          accuracyThresholdMeters:
              (gpsAccuracyM ?? AppSettings.defaultGpsAccuracyM).toDouble(),
        ),
        waiter: SmartWaiter(
          waitingSpeedThresholdKmh:
              (speedKmh ?? defaultWaitingSpeedKmh).toDouble(),
        ),
      );

  final Future<Database> Function() _database;
  final EventSink _send;
  final int Function() _nowMs;

  /// Vožnja postoji: treba otvoriti GPS i snapshot timer.
  final void Function()? onTrackingStart;

  /// Vožnja je završena: treba zatvoriti GPS i snapshot timer.
  final Future<void> Function()? onTrackingStop;

  RideTracker? tracker;
  int? currentRideId;
  int _snapshotFailures = 0;
  int _gapCount = 0;
  // Fiksna relacija vožnje u toku; null = obračun po tarifi.
  int? _fixedPrice;
  String? _fixedRouteName;
  int _gapMs = 0;

  // Doplate vožnje u toku (redovi iz `ride_extras`); dodaju se na cenu.
  final List<ExtraCharge> _extras = [];
  int get _extrasTotal => ExtraCharge.total(_extras);

  // Pauza: dok traje, GPS tačke se ne obračunavaju (ni km ni čekanje).
  bool _paused = false;
  int _pausedMs = 0; // zbir završenih pauza
  int? _pausedSince; // početak pauze u toku

  // Ruta za mapu: tačke se skupljaju u memoriji i upisuju sa snapshot-om.
  final List<Map<String, Object?>> _pendingPoints = [];
  LocationPoint? _lastStoredPoint;
  static const double routePointMinMeters = 15;
  static const int routePointMinMs = 5000;
  // Dok traje zatvaranje vožnje snapshot ne sme da upiše novi red.
  bool _closing = false;

  // V10: komande se izvršavaju strogo redom (start/stop/status ne smeju
  // da se prepliću preko await tačaka).
  Future<void> _queue = Future.value();

  bool get hasActiveRide => tracker != null && currentRideId != null;

  /// Pauza je u toku (za dijagnostički GPS dnevnik).
  bool get isPaused => _paused;

  /// Tekuća cena vožnje (za dijagnostički GPS dnevnik); null bez vožnje.
  int? get currentPrice => tracker == null ? null : _currentPrice(tracker!);

  /// Prima komandu iz UI-ja i stavlja je u red. Vraćeni Future se završava
  /// kad je komanda obrađena (za testove; handler ga ignoriše).
  Future<void> receive(Map<String, dynamic> data) =>
      _enqueue(() => _dispatch(data), cmd: data['command']);

  Future<void> _enqueue(Future<void> Function() op, {Object? cmd}) {
    _queue = _queue.then((_) => op()).catchError((Object e) {
      _send({
        'event': 'error',
        'cmd': ?cmd,
        'message': 'Greška pri obradi komande: $e',
      });
    });
    return _queue;
  }

  Future<void> _dispatch(Map<String, dynamic> data) async {
    switch (data['command']) {
      case 'start':
        await _handleStart(data);
        break;
      case 'pause':
        _pause();
        break;
      case 'resume':
        _resume();
        break;
      case 'stop':
        await _handleStop();
        break;
      case 'status':
        _sendStatus();
        break;
      case 'add_extra':
        await _addExtra(data);
        break;
      case 'remove_extra':
        await _removeExtra(data);
        break;
    }
  }

  /// Pri podizanju servisa: oporavlja aktivnu vožnju i javlja `ready{active}`.
  Future<bool> onServiceStart() async {
    var active = false;
    try {
      active = await _recoverActiveRide();
    } catch (e) {
      _send({'event': 'error', 'message': 'Greška pri oporavku vožnje: $e'});
    }
    // K5: GPS i snapshot se pale samo kad postoji vožnja.
    if (active) onTrackingStart?.call();
    _send({'event': 'ready', 'active': active});
    return active;
  }

  /// N1: tačka čije je vreme dalje od sata telefona od ovoga je pogrešna;
  /// jedna takva bi zamrznula vožnju (sve sledeće bi imale msPassed <= 0).
  static const int maxClockSkewMs = 30 * 1000;

  void onPosition(LocationPoint point) {
    if (tracker == null) return;
    if ((point.timestamp.millisecondsSinceEpoch - _nowMs()).abs() >
        maxClockSkewMs) {
      return;
    }
    if (_paused) return; // pauza: ni km ni čekanje ne teku
    try {
      tracker!.processLocation(point);
      final gap = tracker!.lastGap;
      if (gap != null) _recordGap(gap);
      _collectRoutePoint();
      _send({'event': 'update', ..._rideValues()});
    } catch (e) {
      _send({'event': 'error', 'message': 'Greška pri obradi GPS tačke: $e'});
    }
  }

  /// Cena vožnje u toku: fiksna relacija ili taksimetar po tarifi, plus doplate.
  int _currentPrice(RideTracker t) =>
      (_fixedPrice ?? t.currentFare?.totalPrice ?? t.tariff.startPrice) +
      _extrasTotal;

  /// Doplata tokom vožnje (i u pauzi): upisuje se odmah, pa preživi oporavak.
  Future<void> _addExtra(Map<String, dynamic> data) async {
    if (!hasActiveRide || _closing) return;
    final name = data['name'], amount = data['amount'];
    final extra = ExtraCharge(
      name: name is String ? name.trim() : '',
      amount: amount is num ? amount.toInt() : 0,
    );
    final invalid = extra.validate() ??
        (_extras.length >= ExtraCharge.maxCount
            ? 'Najviše ${ExtraCharge.maxCount} doplata po vožnji.'
            : null);
    if (invalid != null) {
      _send({'event': 'error', 'message': invalid});
      return;
    }
    final db = await _database();
    final id = await db.insert('ride_extras', {
      'ride_id': currentRideId,
      'name': extra.name,
      'amount': extra.amount,
      'added_at': _nowMs(),
    });
    _extras.add(ExtraCharge(id: id, name: extra.name, amount: extra.amount));
    _send({'event': 'update', ..._rideValues()});
  }

  Future<void> _removeExtra(Map<String, dynamic> data) async {
    if (!hasActiveRide || _closing) return;
    final id = (data['id'] as num?)?.toInt();
    if (id == null || !_extras.any((e) => e.id == id)) return;
    final db = await _database();
    await db.delete('ride_extras',
        where: 'id = ? AND ride_id = ?', whereArgs: [id, currentRideId]);
    _extras.removeWhere((e) => e.id == id);
    _send({'event': 'update', ..._rideValues()});
  }

  Future<void> _loadExtras(Database db, int rideId) async {
    final rows = await db.query('ride_extras',
        where: 'ride_id = ?', whereArgs: [rideId], orderBy: 'id');
    _extras
      ..clear()
      ..addAll([
        for (final r in rows)
          ExtraCharge(
            id: r['id'] as int,
            name: r['name'] as String,
            amount: r['amount'] as int,
          ),
      ]);
  }

  /// Pauza: obračun staje, cena ostaje, sat pauze teče.
  void _pause() {
    if (!hasActiveRide || _paused) return;
    _paused = true;
    _pausedSince = _nowMs();
    _send({'event': 'paused', ..._rideValues()});
  }

  /// Nastavak: prva nova tačka postaje polazna (pauza se ne naplaćuje).
  void _resume() {
    if (!hasActiveRide || !_paused) return;
    _pausedMs += _nowMs() - (_pausedSince ?? _nowMs());
    _paused = false;
    _pausedSince = null;
    tracker!.dropLastPoint();
    _send({'event': 'resumed', ..._rideValues()});
  }

  int get _pausedSecondsTotal =>
      (_pausedMs + (_paused ? _nowMs() - (_pausedSince ?? _nowMs()) : 0)) ~/ 1000;

  /// Tačka rute: ne češće od 5 s i ne bliže od 15 m prethodnoj sačuvanoj.
  void _collectRoutePoint() {
    final p = tracker?.lastValidPoint;
    if (p == null || currentRideId == null) return;
    final last = _lastStoredPoint;
    if (last != null) {
      final dt = p.timestamp.difference(last.timestamp).inMilliseconds;
      final d = LocationFilter.calculateDistance(
          last.latitude, last.longitude, p.latitude, p.longitude);
      if (dt < routePointMinMs || d < routePointMinMeters) return;
    }
    _lastStoredPoint = p;
    _pendingPoints.add({
      'ride_id': currentRideId,
      'ts': p.timestamp.millisecondsSinceEpoch,
      'lat': p.latitude,
      'lon': p.longitude,
    });
  }

  Future<void> _flushPoints(DatabaseExecutor db) async {
    if (_pendingPoints.isEmpty) return;
    final batch = db.batch();
    for (final row in _pendingPoints) {
      batch.insert('ride_points', row);
    }
    await batch.commit(noResult: true);
    _pendingPoints.clear();
  }

  /// V12: rupa u signalu se broji odmah (za prikaz), a upis ide kroz red
  /// komandi, pa ne može da stigne posle zatvaranja vožnje.
  void _recordGap(GapInfo gap) {
    final rideId = currentRideId;
    if (rideId == null) return;
    _gapCount++;
    _gapMs += gap.durationMs;
    _enqueue(() async {
      final db = await _database();
      await db.insert('ride_gaps', {
        'ride_id': rideId,
        'started_at': gap.startedAt.millisecondsSinceEpoch,
        'duration_ms': gap.durationMs,
        'kind': gap.kind,
        'added_distance_m': gap.addedDistanceMeters,
        'added_waiting_ms': gap.addedWaitingMs,
      });
    });
    _send({
      'event': 'gap',
      'ride_id': rideId,
      'duration_ms': gap.durationMs,
      'kind': gap.kind,
      'added_distance_m': gap.addedDistanceMeters,
      'added_waiting_ms': gap.addedWaitingMs,
    });
  }

  /// Tekuće vrednosti vožnje za događaje; N11: nose i tarifu vožnje, da UI
  /// posle oporavka ne mora da je pogađa.
  Map<String, dynamic> _rideValues() {
    final t = tracker;
    if (t == null) {
      return {'distance': 0.0, 'waitingMs': 0, 'price': 0, 'mode': 'driving'};
    }
    return {
      'distance': t.totalDistanceMeters,
      'waitingMs': t.totalWaitingMs,
      'price': _currentPrice(t),
      'fixed_route_name': ?_fixedRouteName,
      'mode': t.isWaitingNow ? 'waiting' : 'driving',
      'tariff_id': t.tariff.id,
      'start_price': t.tariff.startPrice,
      'waiting_speed_kmh':
          t.waiter.waitingSpeedThresholdKmh.round(),
      'paused': _paused,
      'paused_sec': _pausedSecondsTotal,
      'extras': [for (final e in _extras) e.toJson()],
      'extras_total': _extrasTotal,
      'gap_count': _gapCount,
      'gap_ms': _gapMs,
      if (t.lastValidPoint != null) 'lat': t.lastValidPoint!.latitude,
      if (t.lastValidPoint != null) 'lon': t.lastValidPoint!.longitude,
    };
  }

  void _sendStatus() {
    _send({
      'event': 'status',
      'active': hasActiveRide,
      'ride_id': currentRideId,
      ..._rideValues(),
    });
  }

  Future<void> _handleStart(Map<String, dynamic> data) async {
    if (tracker != null || currentRideId != null) {
      _send({'event': 'already_active'});
      return;
    }

    const requiredKeys = [
      'tariff_id',
      'start_price',
      'price_per_km',
      'waiting_para_per_min',
      'min_price',
    ];
    for (final key in requiredKeys) {
      if (!data.containsKey(key) || data[key] == null) {
        _send({
          'event': 'error',
          'cmd': 'start',
          'message': 'Nedostaje obavezno polje tarife: $key',
        });
        return;
      }
    }

    try {
      final tariff = Tariff(
        id: data['tariff_id'] as int,
        startPrice: data['start_price'] as int,
        pricePerKm: data['price_per_km'] as int,
        waitingParaPerMin: data['waiting_para_per_min'] as int,
        minPrice: data['min_price'] as int,
        firstKmPrice: (data['first_km_price'] as num?)?.toInt(),
      );
      final calibration =
          (data['calibration_permille'] as num?)?.toInt() ?? Calibration.neutralPermille;
      if (!Calibration.isValid(calibration)) {
        _send({
          'event': 'error',
          'cmd': 'start',
          'message':
              'Kalibracija mora biti od ${Calibration.minPermille} do ${Calibration.maxPermille} promila.',
        });
        return;
      }

      final speedKmh = (data['waiting_speed_kmh'] as num?)?.toInt();
      if (speedKmh != null &&
          (speedKmh < AppSettings.minWaitingSpeedKmh ||
              speedKmh > AppSettings.maxWaitingSpeedKmh)) {
        _send({
          'event': 'error',
          'cmd': 'start',
          'message':
              'Brzina za čekanje mora biti od ${AppSettings.minWaitingSpeedKmh} do ${AppSettings.maxWaitingSpeedKmh} km/h.',
        });
        return;
      }
      final gpsAccuracyM = (data['gps_accuracy_m'] as num?)?.toInt();
      if (gpsAccuracyM != null &&
          (gpsAccuracyM < AppSettings.minGpsAccuracyM ||
              gpsAccuracyM > AppSettings.maxGpsAccuracyM)) {
        _send({
          'event': 'error',
          'cmd': 'start',
          'message':
              'GPS tačnost mora biti od ${AppSettings.minGpsAccuracyM} do ${AppSettings.maxGpsAccuracyM} m.',
        });
        return;
      }

      final invalid = tariff.validate();
      if (invalid != null) {
        _send({'event': 'error', 'cmd': 'start', 'message': invalid});
        return;
      }
      final fixedPrice = (data['fixed_price'] as num?)?.toInt();
      final fixedName = data['fixed_route_name'] as String?;
      if (fixedPrice != null && (fixedPrice <= 0 || fixedPrice > Tariff.maxPrice)) {
        _send({'event': 'error', 'cmd': 'start', 'message': 'Neispravna fiksna cena.'});
        return;
      }

      final db = await _database();
      await _cleanupOldActiveRides(db);

      final rideId = await db.insert('rides', {
        'start_time': _nowMs(),
        'distance_m': 0,
        'waiting_time_sec': 0,
        'start_price': fixedPrice ?? tariff.startPrice,
        'km_price': 0,
        'waiting_price': 0,
        'total_price': fixedPrice ?? tariff.startPrice,
        'fixed_price': fixedPrice,
        'fixed_route_name': fixedPrice == null ? null : fixedName,
        'tariff_id': tariff.id,
        // REAL kolona iz stare šeme: promili / 1000 (npr. 1025 → 1.025)
        'applied_calibration': calibration / 1000.0,
        'waiting_speed_kmh': speedKmh,
        'gps_accuracy_m': gpsAccuracyM,
        'status': statusActive,
        'tariff_start_price': tariff.startPrice,
        'tariff_price_per_km': tariff.pricePerKm,
        'tariff_waiting_para_per_min': tariff.waitingParaPerMin,
        'tariff_min_price': tariff.minPrice,
        'tariff_first_km_price': tariff.firstKmPrice,
        'min_price_adjustment': 0,
      });

      currentRideId = rideId;
      tracker = _newTracker(tariff, calibration, speedKmh, gpsAccuracyM);
      _fixedPrice = fixedPrice;
      _fixedRouteName = fixedPrice == null ? null : fixedName;
      _snapshotFailures = 0;
      _gapCount = 0;
      _gapMs = 0;
      _extras.clear();
      _paused = false;
      _pausedMs = 0;
      _pausedSince = null;
      _pendingPoints.clear();
      _lastStoredPoint = null;
      onTrackingStart?.call();

      _send({'event': 'started', 'ride_id': currentRideId});
    } catch (e) {
      _send({
        'event': 'error',
        'cmd': 'start',
        'message': 'Greška pri kreiranju vožnje: $e',
      });
    }
  }

  Future<void> _handleStop() async {
    if (!hasActiveRide) {
      // Nema vožnje (npr. start nije uspeo): UI dobija 'stopped' bez ride_id.
      // Servis gasi kontroler u UI isolate-u kad primi 'stopped'.
      await onTrackingStop?.call();
      _send({'event': 'stopped', 'ride_id': null});
      return;
    }

    final rideId = currentRideId!;
    final distanceM = tracker!.totalDistanceMeters.round();
    final waitingSec = tracker!.totalWaitingMs ~/ 1000;

    _closing = true;
    final FareResult fare;
    final extras = List<ExtraCharge>.of(_extras);
    try {
      fare = FareCalculator.withExtras(
        _fixedPrice != null
            ? FareCalculator.fixed(_fixedPrice!)
            : FareCalculator.calculate(
                tariff: tracker!.tariff,
                distanceMeters: distanceM,
                waitingSeconds: waitingSec,
                calibrationPermille: tracker!.calibrationPermille,
              ),
        ExtraCharge.total(extras),
      );

      final db = await _database();
      await db.transaction((txn) async {
        await txn.update('rides', {
          'end_time': _nowMs(),
          'status': statusCompleted,
          'distance_m': distanceM,
          'waiting_time_sec': waitingSec,
          'km_price': fare.kmPrice,
          'waiting_price': fare.waitingPrice,
          'total_price': fare.totalPrice,
          'min_price_adjustment': fare.minPriceAdjustment,
          'extras_total': fare.extrasPrice,
          'paused_sec': _pausedSecondsTotal,
        }, where: 'id = ?', whereArgs: [rideId]);
        await _flushPoints(txn);

        await txn.delete('ride_snapshots',
            where: 'ride_id = ?', whereArgs: [rideId]);
      });
    } catch (e) {
      // Upis nije uspeo: vožnja ostaje aktivna, tracker se ne briše,
      // snapshot se nastavlja i korisnik može ponovo da pritisne Stop.
      _closing = false;
      _send({
        'event': 'error',
        'cmd': 'stop',
        'message': 'Greška pri zatvaranju vožnje: $e',
      });
      return;
    }

    final fixedName = _fixedRouteName;
    final pausedSec = _pausedSecondsTotal;
    _paused = false;
    _pausedMs = 0;
    _pausedSince = null;
    _lastStoredPoint = null;
    tracker = null;
    currentRideId = null;
    _fixedPrice = null;
    _fixedRouteName = null;
    _extras.clear();
    _closing = false;
    await onTrackingStop?.call();
    _send({
      'event': 'stopped',
      'ride_id': rideId,
      'fixed_route_name': ?fixedName,
      'paused_sec': pausedSec,
      'distance_m': distanceM,
      'waiting_sec': waitingSec,
      'start_price': fare.startPrice,
      'km_price': fare.kmPrice,
      'waiting_price': fare.waitingPrice,
      'min_price_adjustment': fare.minPriceAdjustment,
      'extras': [for (final e in extras) e.toJson()],
      'extras_total': fare.extrasPrice,
      'total_price': fare.totalPrice,
    });
  }

  /// Snapshot ide kroz isti red kao komande, pa ne može da upiše red
  /// posle transakcije koja ga briše pri stop-u.
  Future<void> saveSnapshot() => _enqueue(_saveSnapshot);

  Future<void> _saveSnapshot() async {
    if (_closing || !hasActiveRide || tracker!.lastValidPoint == null) return;
    final rideId = currentRideId!;
    final t = tracker!;
    try {
      final db = await _database();
      await db.transaction((txn) async {
        await txn.delete('ride_snapshots',
            where: 'ride_id = ?', whereArgs: [rideId]);
        await txn.insert('ride_snapshots', {
          'ride_id': rideId,
          'current_distance': t.totalDistanceMeters,
          'current_waiting_ms': t.totalWaitingMs,
          'current_price': _currentPrice(t),
          'last_lat': t.lastValidPoint!.latitude,
          'last_lon': t.lastValidPoint!.longitude,
          'timestamp': t.lastValidPoint!.timestamp.millisecondsSinceEpoch,
          'saved_at': _nowMs(),
        });
        await _flushPoints(txn);
      });
      _snapshotFailures = 0;
    } catch (e) {
      _snapshotFailures++;
      if (_snapshotFailures == 3) {
        _send({
          'event': 'snapshot_failing',
          'message': 'Vožnja se ne snima u bazu: $e',
        });
      }
    }
  }

  Future<void> _cleanupOldActiveRides(Database db) async {
    final oldRides =
        await db.query('rides', where: 'status = ?', whereArgs: [statusActive]);
    for (final ride in oldRides) {
      await _markInterrupted(db, ride, await _latestSnapshot(db, ride['id'] as int));
    }
  }

  Future<Map<String, Object?>?> _latestSnapshot(Database db, int rideId) async {
    final snaps = await db.query('ride_snapshots',
        where: 'ride_id = ?', whereArgs: [rideId], orderBy: 'id DESC', limit: 1);
    return snaps.isEmpty ? null : snaps.first;
  }

  int _permilleOf(Map<String, Object?> ride) =>
      ((ride['applied_calibration'] as num) * 1000).round();

  Tariff _tariffFromRide(Map<String, Object?> ride) => Tariff(
        id: ride['tariff_id'] as int,
        startPrice: ride['tariff_start_price'] as int,
        pricePerKm: ride['tariff_price_per_km'] as int,
        waitingParaPerMin: ride['tariff_waiting_para_per_min'] as int,
        minPrice: ride['tariff_min_price'] as int,
        firstKmPrice: ride['tariff_first_km_price'] as int?,
      );

  /// K1: prekinutu vožnju zatvara sa iznosima iz poslednjeg snapshot-a
  /// (ili bez ičega, ako ga nema) i briše snapshot u istoj transakciji.
  Future<void> _markInterrupted(
      Database db, Map<String, Object?> ride, Map<String, Object?>? snap) async {
    final rideId = ride['id'] as int;
    final values = <String, Object?>{'status': statusInterrupted};
    final extras = ((await db.rawQuery(
                'SELECT COALESCE(SUM(amount), 0) AS s FROM ride_extras WHERE ride_id = ?',
                [rideId]))
            .first['s'] as num)
        .toInt();
    values['extras_total'] = extras;

    if (snap == null) {
      values['end_time'] = ride['start_time'];
      // Nema merenja: ostaje upisani start (ili fiksna cena) i doplate.
      values['total_price'] = (ride['start_price'] as int) + extras;
    } else {
      values['end_time'] = snap['timestamp'];
      final distanceM = (snap['current_distance'] as num).round();
      final waitingSec = (snap['current_waiting_ms'] as int) ~/ 1000;
      values['distance_m'] = distanceM;
      values['waiting_time_sec'] = waitingSec;
      try {
        final fixed = ride['fixed_price'] as int?;
        final fare = FareCalculator.withExtras(
          fixed != null
              ? FareCalculator.fixed(fixed)
              : FareCalculator.calculate(
                  tariff: _tariffFromRide(ride),
                  distanceMeters: distanceM,
                  waitingSeconds: waitingSec,
                  calibrationPermille: _permilleOf(ride),
                ),
          extras,
        );
        values['km_price'] = fare.kmPrice;
        values['waiting_price'] = fare.waitingPrice;
        values['total_price'] = fare.totalPrice;
        values['min_price_adjustment'] = fare.minPriceAdjustment;
      } catch (_) {
        // Nevalidni ulazi (npr. kalibracija ≤ 0): ostavljamo bar distancu i vreme.
      }
    }

    await db.transaction((txn) async {
      await txn.update('rides', values, where: 'id = ?', whereArgs: [rideId]);
      await txn.delete('ride_snapshots',
          where: 'ride_id = ?', whereArgs: [rideId]);
    });
  }

  Future<void> _loadGaps(Database db, int rideId) async {
    final row = (await db.rawQuery(
            'SELECT COUNT(*) AS n, COALESCE(SUM(duration_ms), 0) AS ms '
            'FROM ride_gaps WHERE ride_id = ?',
            [rideId]))
        .first;
    _gapCount = row['n'] as int;
    _gapMs = row['ms'] as int;
  }

  /// Vreme dok je servis bio zaustavljen nije mereno ni naplaćeno; beležimo ga
  /// kao rupu da vozač zna da je deo vožnje bez merenja.
  Future<void> _addRestartGap(Database db, int rideId, int fromMs) async {
    final duration = _nowMs() - fromMs;
    if (duration <= 0) return;
    await db.insert('ride_gaps', {
      'ride_id': rideId,
      'started_at': fromMs,
      'duration_ms': duration,
      'kind': GapInfo.kindServiceRestart,
      'added_distance_m': 0,
      'added_waiting_ms': 0,
    });
    _gapCount++;
    _gapMs += duration;
  }

  /// Vraća true ako je vožnja oporavljena i treba nastaviti praćenje.
  Future<bool> _recoverActiveRide() async {
    final db = await _database();
    final rides = await db.query('rides',
        where: 'status = ?',
        whereArgs: [statusActive],
        orderBy: 'id DESC',
        limit: 1);
    if (rides.isEmpty) return false;

    final ride = rides.first;
    final rId = ride['id'] as int;
    final snap = await _latestSnapshot(db, rId);

    if (snap == null) {
      // N6: vožnja bez prvog GPS fix-a nema snapshot. Sveža nastavlja od nule,
      // stara se zatvara kao prekinuta.
      if (_nowMs() - (ride['start_time'] as int) > maxSnapshotAgeMs) {
        await _markInterrupted(db, ride, null);
        return false;
      }
      currentRideId = rId;
      _fixedPrice = ride['fixed_price'] as int?;
      _fixedRouteName = ride['fixed_route_name'] as String?;
      await _loadExtras(db, rId);
      tracker = _newTracker(
        _tariffFromRide(ride),
        _permilleOf(ride),
        ride['waiting_speed_kmh'] as int?,
        ride['gps_accuracy_m'] as int?,
      );
      _send({'event': 'recovered', 'ride_id': rId, ..._rideValues()});
      return true;
    }

    final snapTime = snap['timestamp'] as int;
    // N5: starost se meri vremenom upisa, ne GPS vremenom poslednje tačke.
    final savedAt = (snap['saved_at'] as int?) ?? snapTime;

    if (_nowMs() - savedAt > maxSnapshotAgeMs) {
      await _markInterrupted(db, ride, snap);
      return false;
    }

    final tariff = _tariffFromRide(ride);

    final restored = _newTracker(
      tariff,
      _permilleOf(ride),
      ride['waiting_speed_kmh'] as int?,
      ride['gps_accuracy_m'] as int?,
    );
    restored.restoreFromSnapshot(
      restoredDistance: (snap['current_distance'] as num).toDouble(),
      restoredWaitingMs: snap['current_waiting_ms'] as int,
      lastLat: (snap['last_lat'] as num).toDouble(),
      lastLon: (snap['last_lon'] as num).toDouble(),
      lastTimestamp: DateTime.fromMillisecondsSinceEpoch(snapTime, isUtc: true),
    );

    // Vreme dok servis nije radio nije mereno: prva nova tačka postaje
    // polazna, umesto da se ceo prekid naplati kao čekanje.
    restored.dropLastPoint();

    currentRideId = rId;
    tracker = restored;
    _fixedPrice = ride['fixed_price'] as int?;
    _fixedRouteName = ride['fixed_route_name'] as String?;
    await _loadGaps(db, rId);
    await _loadExtras(db, rId);
    await _addRestartGap(db, rId, savedAt);

    _send({'event': 'recovered', 'ride_id': currentRideId, ..._rideValues()});
    return true;
  }
}
