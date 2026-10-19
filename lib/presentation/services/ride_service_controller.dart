import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/services/task_handler.dart'; // sadrži startCallback

/// Tanak omotač oko statičkog API-ja `FlutterForegroundTask`, da bi se
/// životni ciklus servisa mogao testirati bez plugin-a.
class ForegroundBridge {
  const ForegroundBridge();

  Future<bool> isRunningService() => FlutterForegroundTask.isRunningService;

  /// Vraća null ako je servis pokrenut, inače opis greške.
  Future<String?> startService() async {
    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      serviceTypes: [ForegroundServiceTypes.location],
      notificationTitle: 'Taksimetar Balkan',
      notificationText: 'Taksimetar je aktivan',
      callback: startCallback,
    );
    return result is ServiceRequestFailure ? '${result.error}' : null;
  }

  Future<void> stopService() => FlutterForegroundTask.stopService();

  void sendToTask(Map<String, dynamic> data) =>
      FlutterForegroundTask.sendDataToTask(data);

  void addCallback(DataCallback callback) =>
      FlutterForegroundTask.addTaskDataCallback(callback);

  void removeCallback(DataCallback callback) =>
      FlutterForegroundTask.removeTaskDataCallback(callback);

  void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'taksimetar_balkan_service',
        channelName: 'Taksimetar Balkan',
        channelDescription: 'Prikazuje da je taksimetar aktivan.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        // U1: bez automatskog restarta posle kill-a (na Androidu 12+ pokretanje
        // FGS iz pozadine ne uspeva); vožnja se oporavlja pri otvaranju.
        allowAutoRestart: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }
}

/// Upravlja foreground servisom iz UI-ja.
/// Servis je jedini pisac u bazu i izvor istine; ovaj kontroler šalje
/// komande (start, stop, status), prosleđuje događaje UI-ju kao Stream
/// i jedini pali/gasi servis:
/// - servis radi samo dok postoji vožnja (pali ga [startRide], gasi ga
///   događaj 'stopped' ili [connect] kad servis nema vožnju);
/// - [connect] i [startRide] se izvršavaju redom, nikad preklopljeno.
///
/// VAŽNO: u main() pre runApp() pozovi RideServiceController.initCommunicationPort().
class RideServiceController {
  static const Duration _readyTimeout = Duration(seconds: 10);
  static const Duration _statusTimeout = Duration(seconds: 3);

  RideServiceController({ForegroundBridge bridge = const ForegroundBridge()})
    : _bridge = bridge;

  final ForegroundBridge _bridge;

  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _initialized = false;
  bool _callbackRegistered = false;
  bool _disposed = false;
  bool _serviceReady = false;
  bool _rideActive = false;
  // Start je poslat, a servis još nije odgovorio ('started' ili 'error').
  bool _startPending = false;

  Completer<Map<String, dynamic>>? _readyCompleter;
  Completer<Map<String, dynamic>>? _statusCompleter;
  Future<void> _ops = Future.value();

  /// Događaji iz servisa: ready, status, started, update, stopped, recovered,
  /// already_active, snapshot_failing, error (+ 'warning' iz kontrolera).
  Stream<Map<String, dynamic>> get events => _events.stream;

  /// Da li je vožnja u toku (prema poslednjim događajima iz servisa).
  bool get rideActive => _rideActive;

  /// Da li servis radi i prima komande.
  bool get serviceReady => _serviceReady;

  /// Pozvati jednom u main() pre runApp().
  static void initCommunicationPort() {
    FlutterForegroundTask.initCommunicationPort();
  }

  /// Priključuje se na servis koji već radi, ili ga kratko podiže da bi
  /// oporavio prekinutu vožnju. Ako nema vožnje, servis se odmah gasi (K5).
  /// Vraća true ako kontroler može da primi [startRide].
  ///
  /// [requestPermissions] = false samo proverava dozvole bez dijaloga (za
  /// povratak u prvi plan: dijalog sam izaziva pause/resume i petlju).
  Future<bool> connect({
    bool requestPermissions = true,
  }) => _serialized(() async {
    if (_disposed) return false;
    if (!await ensurePermissions(request: requestPermissions)) return false;
    _prepare();

    try {
      if (await _bridge.isRunningService()) {
        // Servis već radi (npr. aplikacija ponovo otvorena): pitamo za stanje.
        final status = await _attach();
        if (status == null) return false;
        if (status['active'] != true) await _stopService();
        return true;
      }

      final ready = await _startServiceAndWait();
      if (ready == null) return false;
      if (ready['active'] != true) await _stopService();
      return true;
    } on TimeoutException {
      // Servis koji smo upravo podigli nije javio 'ready': gasimo ga (K5).
      // Eventualna vožnja ostaje u bazi i oporavlja se pri sledećem podizanju.
      _emit({'event': 'error', 'message': 'Servis ne odgovara.'});
      await _stopService();
      return false;
    } catch (e) {
      _emit({
        'event': 'error',
        'message': 'Greška pri povezivanju sa servisom: $e',
      });
      return false;
    }
  });

  /// Pokreće vožnju; po potrebi prvo podiže servis (K2).
  /// Vraća false ako komanda nije poslata.
  Future<bool> startRide({
    required int tariffId,
    required int startPrice,
    required int pricePerKm,
    required int waitingParaPerMin,
    required int minPrice,
    required int calibrationPermille,
    int? waitingSpeedKmh,
    int? gpsAccuracyM,
    int? fixedPrice,
    String? fixedRouteName,
  }) => _serialized(() async {
    if (_disposed) return false;
    if (_startPending) {
      if (await _bridge.isRunningService()) return false;
      _startPending = false; // servis je nestao pre odgovora
    }
    if (_rideActive) {
      _emit({'event': 'already_active'});
      return false;
    }
    // Na false provider sam vraća prethodnu fazu, pa greške ovde ne
    // nose 'cmd' (to je rezervisano za odgovore servisa).
    if (!await ensurePermissions()) return false;
    _prepare();

    try {
      final running = await _bridge.isRunningService();
      if (!running) {
        _serviceReady = false; // servis ne radi ili je ubijen spolja
      } else if (!_serviceReady) {
        // Servis radi, ali se nismo uspešno priključili: pitamo za stanje.
        final status = await _attach();
        if (status == null) return false;
        if (status['active'] == true) return false; // vožnja već postoji
      }
      if (!_serviceReady) {
        final ready = await _startServiceAndWait();
        if (ready == null) return false;
        // Servis je pri podizanju oporavio vožnju: ne pravimo novu.
        if (ready['active'] == true) return false;
      }
    } on TimeoutException {
      _emit({'event': 'error', 'message': 'Servis ne odgovara.'});
      await _stopService();
      return false;
    } catch (e) {
      _emit({'event': 'error', 'message': 'Greška pri pokretanju servisa: $e'});
      return false;
    }

    _startPending = true;
    _bridge.sendToTask({
      'command': 'start',
      'tariff_id': tariffId,
      'start_price': startPrice,
      'price_per_km': pricePerKm,
      'waiting_para_per_min': waitingParaPerMin,
      'min_price': minPrice,
      'calibration_permille': calibrationPermille,
      'waiting_speed_kmh': ?waitingSpeedKmh,
      'gps_accuracy_m': ?gpsAccuracyM,
      'fixed_price': ?fixedPrice,
      'fixed_route_name': ?fixedRouteName,
    });
    return true;
  });

  /// Šalje komandu za kraj vožnje. Servis upisuje rezultat, a kontroler
  /// gasi servis kad stigne 'stopped'.
  Future<void> stopRide() => _serialized(() async {
    // Servis obrađuje komande redom, pa 'stop' šaljemo čim radi, i kad
    // prethodni 'status' nije stigao na vreme.
    if (await _bridge.isRunningService()) {
      _bridge.sendToTask({'command': 'stop'});
      return;
    }
    // Servis ne radi, pa nema ni vožnje u memoriji. Aktivan red u bazi
    // označiće se kao prekinut pri sledećem startu.
    _serviceReady = false;
    _rideActive = false;
    _emit({'event': 'stopped', 'ride_id': null});
    _emit({
      'event': 'warning',
      'message': 'Servis nije radio; vožnja nije zatvorena u bazi.',
    });
  });

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_callbackRegistered) {
      _bridge.removeCallback(_onReceiveTaskData);
      _callbackRegistered = false;
    }
    _events.close();
  }

  // ---------------------------------------------------------------------

  /// Proverava dozvole i emituje grešku/upozorenje. Vraća false ako rad
  /// nije moguć.
  @protected
  Future<bool> ensurePermissions({bool request = true}) async {
    final location = request
        ? await Permission.locationWhenInUse.request()
        : await Permission.locationWhenInUse.status;
    if (!location.isGranted) {
      _emit({
        'event': 'error',
        'message': location.isPermanentlyDenied
            ? 'Dozvola za lokaciju je trajno odbijena. Uključi je u podešavanjima telefona.'
            : 'Za rad taksimetra potrebna je dozvola za lokaciju.',
        'permanent': location.isPermanentlyDenied,
      });
      return false;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      _emit({
        'event': 'error',
        'message': 'GPS je isključen. Uključi lokaciju na telefonu.',
      });
      return false;
    }

    // V9: "Približna lokacija" daje tačnost od kilometra; vožnja bi bila
    // pogrešno obračunata, pa je ne dozvoljavamo.
    if (await Geolocator.getLocationAccuracy() ==
        LocationAccuracyStatus.reduced) {
      _emit({
        'event': 'error',
        'message':
            'Uključi "Preciznu lokaciju" za ovu aplikaciju u podešavanjima telefona.',
        'permanent': true,
      });
      return false;
    }

    final notifications = request
        ? await Permission.notification.request()
        : await Permission.notification.status;
    if (request && !notifications.isGranted) {
      // Ne blokira rad, ali notifikacija servisa možda neće biti vidljiva.
      _emit({
        'event': 'warning',
        'message':
            'Notifikacije su isključene; obaveštenje o aktivnom taksimetru neće biti prikazano.',
      });
    }
    return true;
  }

  /// Operacije se ulančavaju; greška jedne ne prekida lanac.
  Future<T> _serialized<T>(Future<T> Function() op) {
    final result = _ops.then((_) => op());
    _ops = result.then((_) {}, onError: (_) {});
    return result;
  }

  void _prepare() {
    if (!_initialized) {
      _bridge.init();
      _initialized = true;
    }
    // MORA pre startService, da ne propuste 'recovered'/'ready'
    if (!_callbackRegistered) {
      _bridge.addCallback(_onReceiveTaskData);
      _callbackRegistered = true;
    }
  }

  /// Traži 'status' od servisa koji radi. Vraća događaj ili null ako servis
  /// ne odgovori na vreme (servis se ne gasi; vožnja možda postoji).
  Future<Map<String, dynamic>?> _attach() async {
    final completer = _statusCompleter = Completer<Map<String, dynamic>>();
    _bridge.sendToTask({'command': 'status'});
    try {
      final status = await completer.future.timeout(_statusTimeout);
      _serviceReady = true;
      return status;
    } on TimeoutException {
      _serviceReady = false;
      _emit({'event': 'error', 'message': 'Servis ne odgovara.'});
      return null;
    } finally {
      if (identical(_statusCompleter, completer)) _statusCompleter = null;
    }
  }

  /// Podiže servis i čeka 'ready'. Vraća događaj 'ready' ili null ako
  /// servis nije pokrenut (greška je već emitovana).
  Future<Map<String, dynamic>?> _startServiceAndWait() async {
    _readyCompleter = Completer<Map<String, dynamic>>();
    final error = await _bridge.startService();
    if (error != null) {
      _readyCompleter = null;
      _emit({
        'event': 'error',
        'message': 'Neuspelo pokretanje servisa: $error',
      });
      return null;
    }
    final ready = await _readyCompleter!.future.timeout(_readyTimeout);
    _serviceReady = true;
    return ready;
  }

  Future<void> _stopService() async {
    _serviceReady = false;
    _rideActive = false;
    _startPending = false;
    await _bridge.stopService();
  }

  void _onReceiveTaskData(Object data) {
    if (data is! Map) return;
    final event = Map<String, dynamic>.from(data);

    switch (event['event']) {
      case 'ready':
        _rideActive = event['active'] == true;
        _completeOnce(_readyCompleter, event);
        break;
      case 'status':
        _rideActive = event['active'] == true;
        _completeOnce(_statusCompleter, event);
        break;
      case 'started':
      case 'recovered':
      case 'already_active':
        _startPending = false;
        _rideActive = true;
        break;
      case 'update':
        _rideActive = true;
        break;
      case 'stopped':
        _startPending = false;
        _rideActive = false;
        unawaited(_serialized(_stopService));
        break;
      case 'error':
        if (event['cmd'] == 'start') _startPending = false;
        // Neuspeo start ostavlja servis bez vožnje: gasimo ga.
        if (event['cmd'] == 'start' && !_rideActive) {
          unawaited(
            _serialized(() async {
              if (!_rideActive) await _stopService();
            }),
          );
        }
        break;
    }
    _emit(event);
  }

  void _completeOnce(
    Completer<Map<String, dynamic>>? completer,
    Map<String, dynamic> event,
  ) {
    if (completer != null && !completer.isCompleted) completer.complete(event);
  }

  void _emit(Map<String, dynamic> event) {
    if (!_events.isClosed) _events.add(event);
  }
}
