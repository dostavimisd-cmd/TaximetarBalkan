import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/services/task_handler.dart'; // sadrži startCallback

/// Upravlja foreground servisom iz UI-ja.
/// Servis je jedini pisac u bazu i izvor istine; ovaj kontroler samo šalje
/// komande (start, stop, status) i prosleđuje događaje UI-ju kao Stream.
///
/// VAŽNO: u main() pre runApp() pozovi RideServiceController.initCommunicationPort().
class RideServiceController {
  static const Duration _readyTimeout = Duration(seconds: 10);
  static const Duration _statusTimeout = Duration(seconds: 3);

  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _initialized = false;
  bool _callbackRegistered = false;
  bool _disposed = false;
  bool _serviceReady = false;
  bool _rideActive = false;

  Completer<void>? _readyCompleter;
  Completer<void>? _statusCompleter;

  /// Događaji iz servisa: ready, status, started, update, stopped, recovered,
  /// already_active, snapshot_failing, error (+ 'warning' iz kontrolera).
  Stream<Map<String, dynamic>> get events => _events.stream;

  /// Da li je vožnja u toku (prema poslednjim događajima iz servisa).
  bool get rideActive => _rideActive;

  /// Da li je servis spreman da primi komande.
  bool get serviceReady => _serviceReady;

  /// Pozvati jednom u main() pre runApp().
  static void initCommunicationPort() {
    FlutterForegroundTask.initCommunicationPort();
  }

  /// Proverava dozvole, pokreće servis (ili se priključuje na onaj koji već
  /// radi) i čeka da servis javi da je spreman. Vraća true ako je sve u redu.
  Future<bool> connect() async {
    if (_disposed) return false;
    if (!await _ensurePermissions()) return false;

    _initServiceOptions();
    _registerCallback(); // MORA pre startService, da ne propuste 'recovered'/'ready'

    try {
      if (await FlutterForegroundTask.isRunningService) {
        // Servis već radi (npr. aplikacija ponovo otvorena): pitamo za stanje.
        _statusCompleter = Completer<void>();
        FlutterForegroundTask.sendDataToTask({'command': 'status'});
        await _statusCompleter!.future.timeout(_statusTimeout);
        _serviceReady = true;
        return true;
      }

      _readyCompleter = Completer<void>();
      final result = await FlutterForegroundTask.startService(
        serviceId: 256,
        serviceTypes: [ForegroundServiceTypes.location],
        notificationTitle: 'Taksimetar Balkan',
        notificationText: 'Taksimetar je aktivan',
        callback: startCallback,
      );

      if (result is ServiceRequestFailure) {
        _emit({
          'event': 'error',
          'message': 'Neuspelo pokretanje servisa: ${result.error}',
        });
        return false;
      }

      await _readyCompleter!.future.timeout(_readyTimeout);
      _serviceReady = true;
      return true;
    } on TimeoutException {
      _emit({'event': 'error', 'message': 'Servis ne odgovara.'});
      return false;
    } catch (e) {
      _emit({'event': 'error', 'message': 'Greška pri povezivanju sa servisom: $e'});
      return false;
    }
  }

  /// Šalje komandu za početak vožnje. Vraća false ako ne može da se pošalje.
  bool sendStartCommand({
    required int tariffId,
    required int startPrice,
    required int pricePerKm,
    required int waitingPricePerMin,
    required int minPrice,
    required double calibration,
  }) {
    if (!_serviceReady) {
      _emit({'event': 'error', 'message': 'Servis nije spreman.'});
      return false;
    }
    if (_rideActive) {
      _emit({'event': 'already_active'});
      return false;
    }
    FlutterForegroundTask.sendDataToTask({
      'command': 'start',
      'tariff_id': tariffId,
      'start_price': startPrice,
      'price_per_km': pricePerKm,
      'waiting_price_per_min': waitingPricePerMin,
      'min_price': minPrice,
      'calibration': calibration,
    });
    return true;
  }

  /// Šalje komandu za kraj vožnje. Servis upisuje rezultat i sam se gasi.
  void sendStopCommand() {
    if (!_serviceReady) return;
    FlutterForegroundTask.sendDataToTask({'command': 'stop'});
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_callbackRegistered) {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
      _callbackRegistered = false;
    }
    _events.close();
  }

  // ---------------------------------------------------------------------

  Future<bool> _ensurePermissions() async {
    final location = await Permission.locationWhenInUse.request();
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
      _emit({'event': 'error', 'message': 'GPS je isključen. Uključi lokaciju na telefonu.'});
      return false;
    }

    final notifications = await Permission.notification.request();
    if (!notifications.isGranted) {
      // Ne blokira rad, ali notifikacija servisa možda neće biti vidljiva.
      _emit({
        'event': 'warning',
        'message': 'Notifikacije su isključene; obaveštenje o aktivnom taksimetru neće biti prikazano.',
      });
    }
    return true;
  }

  void _initServiceOptions() {
    if (_initialized) return;
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
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _initialized = true;
  }

  void _registerCallback() {
    if (_callbackRegistered) return;
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    _callbackRegistered = true;
  }

  void _onReceiveTaskData(Object data) {
    if (data is! Map) return;
    final event = Map<String, dynamic>.from(data);

    switch (event['event']) {
      case 'ready':
        _completeOnce(_readyCompleter);
        break;
      case 'status':
        _rideActive = event['active'] == true;
        _completeOnce(_statusCompleter);
        break;
      case 'started':
      case 'recovered':
      case 'already_active':
      case 'update':
        _rideActive = true;
        break;
      case 'stopped':
        _rideActive = false;
        _serviceReady = false; // servis se gasi sam posle stop komande
        break;
    }
    _emit(event);
  }

  void _completeOnce(Completer<void>? completer) {
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _emit(Map<String, dynamic> event) {
    if (!_events.isClosed) _events.add(event);
  }
}