import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ride_service_controller.dart';

class TaximeterState {
  final bool isReady;
  final bool isRunning;
  final int currentPrice;
  final double currentDistanceMeters;
  final int currentWaitingMs;
  final int selectedTariffId;
  final String currency; // 'RSD', 'EUR'
  final String language; // 'sr', 'en'
  final String? errorMessage;
  final String? warningMessage;

  const TaximeterState({
    this.isReady = false,
    this.isRunning = false,
    this.currentPrice = 0,
    this.currentDistanceMeters = 0.0,
    this.currentWaitingMs = 0,
    this.selectedTariffId = 1,
    this.currency = 'RSD',
    this.language = 'sr',
    this.errorMessage,
    this.warningMessage,
  });

  TaximeterState copyWith({
    bool? isReady,
    bool? isRunning,
    int? currentPrice,
    double? currentDistanceMeters,
    int? currentWaitingMs,
    int? selectedTariffId,
    String? currency,
    String? language,
    String? errorMessage,
    String? warningMessage,
    bool clearError = false,
    bool clearWarning = false,
  }) {
    return TaximeterState(
      isReady: isReady ?? this.isReady,
      isRunning: isRunning ?? this.isRunning,
      currentPrice: currentPrice ?? this.currentPrice,
      currentDistanceMeters: currentDistanceMeters ?? this.currentDistanceMeters,
      currentWaitingMs: currentWaitingMs ?? this.currentWaitingMs,
      selectedTariffId: selectedTariffId ?? this.selectedTariffId,
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

    ref.onDispose(() {
      _subscription?.cancel();
    });

    _initConnection(controller);

    return const TaximeterState();
  }

  Future<void> _initConnection(RideServiceController controller) async {
    final connected = await controller.connect();
    state = state.copyWith(isReady: connected);
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
          isRunning: event['active'] == true,
          currentDistanceMeters: (event['distance'] as num?)?.toDouble() ?? 0.0,
          currentWaitingMs: event['waitingMs'] as int? ?? 0,
          currentPrice: event['price'] as int? ?? 0,
          clearError: true,
        );
        break;
      case 'started':
      case 'recovered':
        state = state.copyWith(isRunning: true, clearError: true);
        break;
      case 'already_active':
        state = state.copyWith(
          isRunning: true,
          errorMessage: 'Vožnja je već bila aktivna u pozadini.',
        );
        break;
      case 'update':
        state = state.copyWith(
          currentDistanceMeters: (event['distance'] as num?)?.toDouble() ?? state.currentDistanceMeters,
          currentWaitingMs: event['waitingMs'] as int? ?? state.currentWaitingMs,
          currentPrice: event['price'] as int? ?? state.currentPrice,
        );
        break;
      case 'stopped':
        state = state.copyWith(
          isRunning: false,
          currentDistanceMeters: 0.0,
          currentWaitingMs: 0,
          currentPrice: 0,
          clearError: true,
        );
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
        state = state.copyWith(
          errorMessage: event['message'] as String?,
        );
        break;
    }
  }

  void startRide({
    required int startPrice,
    required int pricePerKm,
    required int waitingPricePerMin,
    required int minPrice,
    double calibration = 1.0,
  }) {
    if (!state.isReady || state.isRunning) return;

    final controller = ref.read(rideServiceControllerProvider);
    final success = controller.sendStartCommand(
      tariffId: state.selectedTariffId,
      startPrice: startPrice,
      pricePerKm: pricePerKm,
      waitingPricePerMin: waitingPricePerMin,
      minPrice: minPrice,
      calibration: calibration,
    );

    if (success) {
      state = state.copyWith(isRunning: true, clearError: true);
    }
  }

  void stopRide() {
    if (!state.isRunning) return;
    final controller = ref.read(rideServiceControllerProvider);
    controller.sendStopCommand();
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