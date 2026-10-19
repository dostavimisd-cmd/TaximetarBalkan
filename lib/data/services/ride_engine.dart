import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../domain/fare_calculator.dart';
import '../../domain/models/fare_result.dart';
import '../../domain/models/location_point.dart';
import '../../domain/models/tariff.dart';
import '../../domain/ride_tracker.dart';

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
  // Dok traje zatvaranje vožnje snapshot ne sme da upiše novi red.
  bool _closing = false;

  // V10: komande se izvršavaju strogo redom (start/stop/status ne smeju
  // da se prepliću preko await tačaka).
  Future<void> _queue = Future.value();

  bool get hasActiveRide => tracker != null && currentRideId != null;

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
      case 'stop':
        await _handleStop();
        break;
      case 'status':
        _sendStatus();
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
    try {
      tracker!.processLocation(point);
      _send({'event': 'update', ..._rideValues()});
    } catch (e) {
      _send({'event': 'error', 'message': 'Greška pri obradi GPS tačke: $e'});
    }
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
      'price': t.currentFare?.totalPrice ?? t.tariff.startPrice,
      'mode': t.isWaitingNow ? 'waiting' : 'driving',
      'tariff_id': t.tariff.id,
      'start_price': t.tariff.startPrice,
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
      );
      final calibration = (data['calibration'] as num?)?.toDouble() ?? 1.0;

      final invalid = tariff.validate();
      if (invalid != null) {
        _send({'event': 'error', 'cmd': 'start', 'message': invalid});
        return;
      }

      final db = await _database();
      await _cleanupOldActiveRides(db);

      final rideId = await db.insert('rides', {
        'start_time': _nowMs(),
        'distance_m': 0,
        'waiting_time_sec': 0,
        'start_price': tariff.startPrice,
        'km_price': 0,
        'waiting_price': 0,
        'total_price': tariff.startPrice,
        'tariff_id': tariff.id,
        'applied_calibration': calibration,
        'status': statusActive,
        'tariff_start_price': tariff.startPrice,
        'tariff_price_per_km': tariff.pricePerKm,
        'tariff_waiting_para_per_min': tariff.waitingParaPerMin,
        'tariff_min_price': tariff.minPrice,
        'min_price_adjustment': 0,
      });

      currentRideId = rideId;
      tracker = RideTracker(tariff: tariff, calibrationMultiplier: calibration);
      _snapshotFailures = 0;
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
    try {
      fare = FareCalculator.calculate(
        tariff: tracker!.tariff,
        distanceMeters: distanceM,
        waitingSeconds: waitingSec,
        calibrationMultiplier: tracker!.calibrationMultiplier,
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
        }, where: 'id = ?', whereArgs: [rideId]);

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

    tracker = null;
    currentRideId = null;
    _closing = false;
    await onTrackingStop?.call();
    _send({
      'event': 'stopped',
      'ride_id': rideId,
      'distance_m': distanceM,
      'waiting_sec': waitingSec,
      'start_price': fare.startPrice,
      'km_price': fare.kmPrice,
      'waiting_price': fare.waitingPrice,
      'min_price_adjustment': fare.minPriceAdjustment,
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
          'current_price': t.currentFare?.totalPrice ?? t.tariff.startPrice,
          'last_lat': t.lastValidPoint!.latitude,
          'last_lon': t.lastValidPoint!.longitude,
          'timestamp': t.lastValidPoint!.timestamp.millisecondsSinceEpoch,
          'saved_at': _nowMs(),
        });
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

  Tariff _tariffFromRide(Map<String, Object?> ride) => Tariff(
        id: ride['tariff_id'] as int,
        startPrice: ride['tariff_start_price'] as int,
        pricePerKm: ride['tariff_price_per_km'] as int,
        waitingParaPerMin: ride['tariff_waiting_para_per_min'] as int,
        minPrice: ride['tariff_min_price'] as int,
      );

  /// K1: prekinutu vožnju zatvara sa iznosima iz poslednjeg snapshot-a
  /// (ili bez ičega, ako ga nema) i briše snapshot u istoj transakciji.
  Future<void> _markInterrupted(
      Database db, Map<String, Object?> ride, Map<String, Object?>? snap) async {
    final rideId = ride['id'] as int;
    final values = <String, Object?>{'status': statusInterrupted};

    if (snap == null) {
      values['end_time'] = ride['start_time'];
    } else {
      values['end_time'] = snap['timestamp'];
      final distanceM = (snap['current_distance'] as num).round();
      final waitingSec = (snap['current_waiting_ms'] as int) ~/ 1000;
      values['distance_m'] = distanceM;
      values['waiting_time_sec'] = waitingSec;
      try {
        final fare = FareCalculator.calculate(
          tariff: _tariffFromRide(ride),
          distanceMeters: distanceM,
          waitingSeconds: waitingSec,
          calibrationMultiplier: (ride['applied_calibration'] as num).toDouble(),
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
      tracker = RideTracker(
        tariff: _tariffFromRide(ride),
        calibrationMultiplier: (ride['applied_calibration'] as num).toDouble(),
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

    final restored = RideTracker(
      tariff: tariff,
      calibrationMultiplier: (ride['applied_calibration'] as num).toDouble(),
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

    _send({'event': 'recovered', 'ride_id': currentRideId, ..._rideValues()});
    return true;
  }
}
