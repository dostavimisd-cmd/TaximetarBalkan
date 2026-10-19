import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/taximeter_provider.dart';
import '../widgets/tariff_selection_sheet.dart';
import '../widgets/taximeter_drawer.dart';

class TaximeterScreen extends ConsumerStatefulWidget {
  const TaximeterScreen({super.key});

  @override
  ConsumerState<TaximeterScreen> createState() => _TaximeterScreenState();
}

class _TaximeterScreenState extends ConsumerState<TaximeterScreen> {
  /// Tarifa se drži samo u provider-u (selectedTariffId); servis je vraća
  /// u status/recovered, pa ekran posle oporavka prikazuje pravu.
  TariffOption get _activeTariff {
    final id = ref.read(taximeterProvider).selectedTariffId;
    return TariffSelectionSheet.predefinedTariffs.firstWhere(
      (t) => t.id == id,
      orElse: () => TariffSelectionSheet.predefinedTariffs.first,
    );
  }

  String _formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  void _openTariffSheet(BuildContext context) {
    final isRunning = ref.read(taximeterProvider).isRunning;
    if (isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nije moguće menjati tarifu tokom aktivne vožnje!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => TariffSelectionSheet(
        currentTariffId: _activeTariff.id,
        onTariffSelected: (selected) {
          ref.read(taximeterProvider.notifier).setTariff(selected.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taximeterProvider);
    final notifier = ref.read(taximeterProvider.notifier);

    final isSr = state.language == 'sr';
    final currencyFactor = state.currency == 'EUR' ? 117.2 : 1.0;
    final displayPrice = state.currency == 'EUR'
        ? (state.currentPrice / currencyFactor).toStringAsFixed(2)
        : state.currentPrice.toString();

    // Trenutno stajanje (servis javlja mode), ne ukupno čekanje
    final isWaiting = state.isRunning && state.isWaitingNow;
    final isFinished = state.phase == RidePhase.finished;
    final result = state.lastResult;

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: TaximeterDrawer(
        onHistoryTap: () {},
        onTariffsTap: () => _openTariffSheet(context),
        onSettingsTap: () {},
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gornja traka: Meni, Pravna napomena i Preklopnici
              Row(
                children: [
                  Builder(
                    builder: (innerContext) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white70),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Scaffold.of(innerContext).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isSr ? 'POMOĆNI TAKSIMETAR' : 'AUXILIARY METER',
                      style: TextStyle(
                        color: Colors.amberAccent.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: notifier.toggleLanguage,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      backgroundColor: Colors.white10,
                      minimumSize: const Size(36, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: Text(state.language.toUpperCase(), style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: notifier.toggleCurrency,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.amberAccent,
                      backgroundColor: Colors.white10,
                      minimumSize: const Size(44, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: Text(state.currency, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // Status režima rada (Vožnja vs Čekanje)
              if (state.isRunning)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isWaiting
                          ? Colors.orangeAccent.withValues(alpha: 0.15)
                          : Colors.greenAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isWaiting ? Colors.orangeAccent : Colors.greenAccent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isWaiting ? Icons.hourglass_top : Icons.directions_car,
                          color: isWaiting ? Colors.orangeAccent : Colors.greenAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isWaiting
                              ? (isSr ? 'ČEKANJE (STRIKTNO < 8 km/h)' : 'WAITING (< 8 km/h)')
                              : (isSr ? 'VOŽNJA' : 'DRIVING'),
                          style: TextStyle(
                            color: isWaiting ? Colors.orangeAccent : Colors.greenAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Glavna cifra (Cena)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayPrice,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                        fontSize: 82,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -3,
                      ),
                    ),
                    Text(
                      state.currency,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Info paneli: Razdaljina, Čekanje i Tarifa
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _InfoBlock(
                      label: isSr ? 'DISTANCA' : 'DISTANCE',
                      value: '${(state.currentDistanceMeters / 1000).toStringAsFixed(2)} km',
                    ),
                    Container(width: 1, height: 40, color: Colors.white12),
                    _InfoBlock(
                      label: isSr ? 'ČEKANJE' : 'WAITING',
                      value: _formatDuration(state.currentWaitingMs),
                    ),
                    Container(width: 1, height: 40, color: Colors.white12),
                    _InfoBlock(
                      label: isSr ? 'START' : 'BASE',
                      value: '${state.rideStartPrice ?? _activeTariff.startPrice}',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Konačan obračun završene vožnje
              if (isFinished && result != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      _ResultLine(isSr ? 'Start' : 'Base', result.startPrice),
                      _ResultLine(isSr ? 'Kilometraža' : 'Distance', result.kmPrice),
                      _ResultLine(isSr ? 'Čekanje' : 'Waiting', result.waitingPrice),
                      if (result.minPriceAdjustment > 0)
                        _ResultLine(isSr ? 'Dopuna do minimalne' : 'Minimum fare top-up',
                            result.minPriceAdjustment),
                    ],
                  ),
                ),

              // Poruke o grešci ili upozorenja
              if (state.warningMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    state.warningMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
                  ),
                ),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    state.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),

              // Donja kontrolna traka: Dugme za Tarifu + Masivno Start/Stop
              Row(
                children: [
                  // Brzo dugme za promenu tarife
                  GestureDetector(
                    onTap: () => _openTariffSheet(context),
                    child: Container(
                      height: 74,
                      width: 74,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1C),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.tune, color: Colors.amberAccent, size: 22),
                          const SizedBox(height: 4),
                          Text(
                            'T-${_activeTariff.id}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Masivno Start / Stop dugme
                  Expanded(
                    child: SizedBox(
                      height: 74,
                      child: isFinished
                          ? ElevatedButton(
                              onPressed: notifier.newRide,
                              style: _mainButtonStyle(const Color(0xFF1565C0)),
                              child: _mainButtonLabel(isSr ? 'NOVA VOŽNJA' : 'NEW RIDE'),
                            )
                          : state.isRunning
                              ? ElevatedButton(
                                  onPressed: state.isBusy ? null : notifier.stopRide,
                                  style: _mainButtonStyle(const Color(0xFFD32F2F)),
                                  child: _mainButtonLabel(isSr ? 'ZAVRŠI (STOP)' : 'END RIDE'),
                                )
                              : ElevatedButton(
                                  onPressed: state.isReady
                                      ? () {
                                          final t = _activeTariff;
                                          notifier.startRide(
                                            startPrice: t.startPrice,
                                            pricePerKm: t.pricePerKm,
                                            waitingPricePerMin: t.waitingPricePerMin,
                                            minPrice: t.minPrice,
                                          );
                                        }
                                      : notifier.retryConnect,
                                  style: _mainButtonStyle(const Color(0xFF2E7D32)),
                                  child: _mainButtonLabel(state.isReady
                                      ? (isSr ? 'POKRENI (START)' : 'START RIDE')
                                      : (isSr ? 'POVEŽI SE PONOVO' : 'RECONNECT')),
                                ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
ButtonStyle _mainButtonStyle(Color color) => ElevatedButton.styleFrom(
      backgroundColor: color,
      disabledBackgroundColor: Colors.white12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 6,
    );

Widget _mainButtonLabel(String text) => Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );

class _ResultLine extends StatelessWidget {
  final String label;
  final int amount;

  const _ResultLine(this.label, this.amount);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text('$amount',
              style: const TextStyle(
                  fontFamily: 'monospace', color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
