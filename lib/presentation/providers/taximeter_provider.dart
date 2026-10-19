import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ride_service_controller.dart';

enum RidePhase { idle, starting, running, stopping, finished }

/// Konačan obračun vožnje, kako ga javlja servis u događaju 'stopped'.
class RideResult {
  final int rideId;
  final int distanceMeters;
  final int waitingSeconds;
  final int startPrice;
  final int kmPrice;
  final int waitingPrice;
  final int minPriceAdjustment;
  final int totalPrice;

  const RideResult({
    required this.rideId,
    required this.distanceMeters,
    required this.waitingSeconds,
    required this.startPrice,
    required this.kmPrice,
    required this.waitingPrice,
    required this.minPriceAdjustment,
    required this.totalPrice,
  });

  factory RideResult.fromEvent(Map<String, dynamic> e) {
    int i(String k) => (e[k] as num?)?.toInt() ?? 0;
    return RideResult(
      rideId: i('ride_id'),
      distanceMeters: i('distance_m'),
      waitingSeconds: i('waiting_sec'),
      startPrice: i('start_price'),
      kmPrice: i('km_price'),
      waitingPrice: i('waiting_price'),
      minPriceAdjustment: i('min_price_adjustment'),
      totalPrice: i('total_price'),
    );
  }
}

class TaximeterState {
  final bool isReady;
  final RidePhase phase;
  final RideResult? lastResult;
  final int currentPrice;
  final double currentDistanceMeters;
  final int currentWaitingMs;
  final int selectedTariffId;

  /// Start cena tarife vožnje u toku (iz servisa); null kad nema vožnje.
  final int? rideStartPrice;

  /// Trenutno stajanje (čekanje se naplaćuje), a ne ukupno čekanje.
  final bool isWaitingNow;

  /// Prag brzine za čekanje (km/h) vožnje u toku; null dok servis ne javi.
  final int? waitingSpeedKmh;
  final String currency; // 'RSD', 'EUR'
  final String language; // 'sr', 'en'
  final String? errorMessage;
  final String? warningMessage;

  const TaximeterState({
    this.isReady = false,
    this.phase = RidePhase.idle,
    this.lastResult,
    this.currentPrice = 0,
    this.currentDistanceMeters = 0.0,
    this.currentWaitingMs = 0,
    this.selectedTariffId = 1,
    this.rideStartPrice,
    this.isWaitingNow = false,
    this.waitingSpeedKmh,
    this.currency = 'RSD',
    this.language = 'sr',
    this.errorMessage,
    this.warningMessage,
  });

  /// Vožnja je u toku (uključujući pokretanje i zaustavljanje).
  bool get isRunning =>
      phase == RidePhase.starting ||
      phase == RidePhase.running ||
      phase == RidePhase.stopping;

  /// Prelazna faza: komanda je poslata, čeka se odgovor servisa.
  bool get isBusy =>
      phase == RidePhase.starting || phase == RidePhase.stopping;

  TaximeterState copyWith({
    bool? isReady,
    RidePhase? phase,
    RideResult? lastResult,
    int? currentPrice,
    double? currentDistanceMeters,
    int? currentWaitingMs,
    int? selectedTariffId,
    int? rideStartPrice,
    bool? isWaitingNow,
    int? waitingSpeedKmh,
    bool clearRideStartPrice = false,
    String? currency,
    String? language,
    String? errorMessage,
    String? warningMessage,
    bool clearError = false,
    bool clearWarning = false,
    bool clearResult = false,
  }) {
    return TaximeterState(
      isReady: isReady ?? this.isReady,
      phase: phase ?? this.phase,
      lastResult: clearResult ? null : (lastResult ?? this.lastResult),
      currentPrice: currentPrice ?? this.currentPrice,
      currentDistanceMeters: currentDistanceMeters ?? this.currentDistanceMeters,
      currentWaitingMs: currentWaitingMs ?? this.currentWaitingMs,
      selectedTariffId: selectedTariffId ?? this.selectedTariffId,
      rideStartPrice: clearRideStartPrice
          ? null
          : (rideStartPrice ?? this.rideStartPrice),
      isWaitingNow: isWaitingNow ?? this.isWaitingNow,
      waitingSpeedKmh: waitingSpeedKmh ?? this.waitingSpeedKmh,
      currency: currency ?? this.currency,
      language: language ?? this.language,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      warningMessage:
          clearWarning ? null : (warningMessage ?? this.warningMessage),
    );
  }
}

class TaximeterNotifier extends Notifier<TaximeterState> {
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  TaximeterState build() {
    final controller = ref.watch(rideServiceControllerProvider);

    _subscription?.cancel();
    _subscription = controller.events.listen(_handleServiceEvent);

    WidgetsFlutterBinding.ensureInitialized();
    final lifecycle = AppLifecycleListener(onResume: _onResume);

    ref.onDispose(() {
      _subscription?.cancel();
      lifecycle.dispose();
    });

    _initConnection(controller);

    return const TaximeterState();
  }

  bool _connecting = false;

  void _onResume() {
    // Neuspeo connect ponavljamo; vožnja u toku se usklađuje sa servisom
    // (connect traži 'status'). Mirna aplikacija ne dira servis.
    if (!state.isReady || state.isRunning) {
      retryConnect(requestPermissions: false);
    }
  }

  Future<void> _initConnection(RideServiceController controller,
      {bool requestPermissions = true}) async {
    if (_connecting) return;
    _connecting = true;
    try {
      final connected =
          await controller.connect(requestPermissions: requestPermissions);
      state = state.copyWith(isReady: connected);
    } finally {
      _connecting = false;
    }
  }

  /// V8: ponovni pokušaj povezivanja (npr. posle odobrene dozvole ili
  /// uključenog GPS-a); poziva se i pri povratku aplikacije u prvi plan.
  Future<void> retryConnect({bool requestPermissions = true}) {
    if (state.isBusy) return Future.value();
    return _initConnection(ref.read(rideServiceControllerProvider),
        requestPermissions: requestPermissions);
  }

  void _handleServiceEvent(Map<String, dynamic> event) {
    final eventType = event['event'];
    switch (eventType) {
      case 'ready':
        state = state.copyWith(isReady: true, clearError: true);
        break;
      case 'status':
        state = state.copyWith(
          isReady: true,
          phase: event['active'] == true
              ? RidePhase.running
              : (state.phase == RidePhase.finished
                  ? RidePhase.finished
                  : RidePhase.idle),
          currentDistanceMeters: (event['distance'] as num?)?.toDouble() ?? 0.0,
          currentWaitingMs: event['waitingMs'] as int? ?? 0,
          currentPrice: event['price'] as int? ?? 0,
          selectedTariffId: event['tariff_id'] as int?,
          rideStartPrice: event['start_price'] as int?,
          isWaitingNow: event['mode'] == 'waiting',
          waitingSpeedKmh: event['waiting_speed_kmh'] as int?,
          clearError: true,
        );
        break;
      case 'started':
        state = state.copyWith(
            phase: RidePhase.running, clearResult: true, clearError: true);
        break;
      case 'recovered':
        // V7: vožnja nastavljena posle prekida servisa; preuzimamo tekuće vrednosti.
        state = state.copyWith(
          phase: RidePhase.running,
          currentDistanceMeters:
              (event['distance'] as num?)?.toDouble() ?? state.currentDistanceMeters,
          currentWaitingMs: event['waitingMs'] as int? ?? state.currentWaitingMs,
          currentPrice: event['price'] as int? ?? state.currentPrice,
          selectedTariffId: event['tariff_id'] as int?,
          rideStartPrice: event['start_price'] as int?,
          isWaitingNow: event['mode'] == 'waiting',
          waitingSpeedKmh: event['waiting_speed_kmh'] as int?,
          warningMessage: 'Vožnja je nastavljena posle prekida servisa.',
          clearResult: true,
          clearError: true,
        );
        break;
      case 'already_active':
        state = state.copyWith(
          phase: RidePhase.running,
          errorMessage: 'Vožnja je već bila aktivna u pozadini.',
        );
        break;
      case 'update':
        if (state.phase == RidePhase.finished) break; // zakasneli događaj
        state = state.copyWith(
          currentDistanceMeters: (event['distance'] as num?)?.toDouble() ?? state.currentDistanceMeters,
          currentWaitingMs: event['waitingMs'] as int? ?? state.currentWaitingMs,
          currentPrice: event['price'] as int? ?? state.currentPrice,
          isWaitingNow: event['mode'] == 'waiting',
          waitingSpeedKmh: event['waiting_speed_kmh'] as int?,
        );
        break;
      case 'stopped':
        if (event['ride_id'] == null) {
          state = state.copyWith(
            phase: RidePhase.idle,
            currentDistanceMeters: 0.0,
            currentWaitingMs: 0,
            currentPrice: 0,
            isWaitingNow: false,
            clearRideStartPrice: true,
            clearError: true,
          );
        } else {
          final result = RideResult.fromEvent(event);
          state = state.copyWith(
            phase: RidePhase.finished,
            lastResult: result,
            currentDistanceMeters: result.distanceMeters.toDouble(),
            currentWaitingMs: result.waitingSeconds * 1000,
            currentPrice: result.totalPrice,
            isWaitingNow: false,
            clearRideStartPrice: true,
            clearError: true,
          );
        }
        break;
      case 'snapshot_failing':
        state = state.copyWith(
          warningMessage: 'Upozorenje: Problem sa periodičnim čuvanjem u bazu.',
        );
        break;
      case 'warning':
        state = state.copyWith(
          warningMessage: event['message'] as String?,
        );
        break;
      case 'error':
        // K6: neuspeo start vraća UI u mirovanje; neuspeo stop ostavlja
        // vožnju aktivnom da korisnik može ponovo da pritisne Stop.
        final cmd = event['cmd'];
        state = state.copyWith(
          phase: cmd == 'start'
              ? RidePhase.idle
              : (cmd == 'stop' ? RidePhase.running : state.phase),
          errorMessage: event['message'] as String?,
        );
        break;
    }
  }

  Future<void> startRide({
    int? tariffId,
    required int startPrice,
    required int pricePerKm,
    required int waitingParaPerMin,
    required int minPrice,
    double calibration = 1.0,
    int? waitingSpeedKmh,
  }) async {
    if (!state.isReady ||
        (state.phase != RidePhase.idle && state.phase != RidePhase.finished)) {
      return;
    }

    // 'starting' odmah, da drugi pritisak ne pošalje dupli start.
    final previous = state;
    state = state.copyWith(
      phase: RidePhase.starting,
      rideStartPrice: startPrice,
      currentDistanceMeters: 0.0,
      currentWaitingMs: 0,
      currentPrice: 0,
      clearResult: true,
      clearError: true,
    );

    final controller = ref.read(rideServiceControllerProvider);
    final sent = await controller.startRide(
      tariffId: tariffId ?? state.selectedTariffId,
      startPrice: startPrice,
      pricePerKm: pricePerKm,
      waitingParaPerMin: waitingParaPerMin,
      minPrice: minPrice,
      calibration: calibration,
      waitingSpeedKmh: waitingSpeedKmh,
    );

    // Komanda nije poslata, a nijedan događaj nije promenio fazu.
    if (!sent && state.phase == RidePhase.starting) {
      state = state.copyWith(
        phase: previous.phase,
        lastResult: previous.lastResult,
        currentDistanceMeters: previous.currentDistanceMeters,
        currentWaitingMs: previous.currentWaitingMs,
        currentPrice: previous.currentPrice,
      );
    }
  }

  Future<void> stopRide() async {
    if (state.phase != RidePhase.running) return;
    final controller = ref.read(rideServiceControllerProvider);
    state = state.copyWith(phase: RidePhase.stopping);
    await controller.stopRide();
  }

  /// Zatvara prikaz završene vožnje i vraća ekran u početno stanje.
  void newRide() {
    if (state.phase != RidePhase.finished) return;
    state = state.copyWith(
      phase: RidePhase.idle,
      currentDistanceMeters: 0.0,
      currentWaitingMs: 0,
      currentPrice: 0,
      isWaitingNow: false,
      clearRideStartPrice: true,
      clearResult: true,
      clearError: true,
      clearWarning: true,
    );
  }

  void setTariff(int tariffId) {
    if (state.isRunning) return;
    state = state.copyWith(selectedTariffId: tariffId);
  }

  void toggleCurrency() {
    final nextCurrency = state.currency == 'RSD' ? 'EUR' : 'RSD';
    state = state.copyWith(currency: nextCurrency);
  }

  void toggleLanguage() {
    final nextLang = state.language == 'sr' ? 'en' : 'sr';
    state = state.copyWith(language: nextLang);
  }
}

final rideServiceControllerProvider = Provider<RideServiceController>((ref) {
  final controller = RideServiceController();
  ref.onDispose(() => controller.dispose());
  return controller;
});

final taximeterProvider = NotifierProvider<TaximeterNotifier, TaximeterState>(
  TaximeterNotifier.new,
);