import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../domain/currency_converter.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/fixed_route.dart';
import '../../domain/models/holiday.dart';
import '../../domain/models/tariff.dart';
import '../../domain/tariff_selector.dart';
import '../providers/taximeter_provider.dart';
import '../providers/tariffs_provider.dart';
import '../../domain/announcement.dart';
import '../../domain/price_throttle.dart';
import '../printing/receipt_printer.dart';
import '../services/voice_service.dart';
import '../providers/settings_provider.dart';
import 'history_screen.dart';
import 'ride_summary_screen.dart';
import '../providers/history_provider.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import '../widgets/fixed_route_picker.dart';
import '../widgets/price_colors.dart';
import '../widgets/ride_map.dart';
import '../widgets/tariff_edit_dialog.dart';
import '../widgets/tariff_selection_sheet.dart';
import '../widgets/taximeter_drawer.dart';
import '../l10n/tr.dart';

class TaximeterScreen extends ConsumerStatefulWidget {
  const TaximeterScreen({super.key});

  @override
  ConsumerState<TaximeterScreen> createState() => _TaximeterScreenState();
}

class _TaximeterScreenState extends ConsumerState<TaximeterScreen> {
  Tr get t => ref.read(trProvider);
  /// Automatski izbor zavisi od sata: ekran se osvežava dok čeka start.
  Timer? _clock;

  // prikaz cene sa podesivim osvežavanjem (obračun ide nezavisno)
  final _throttle = PriceThrottle();
  Timer? _priceTick;
  bool? _wakelockOn;

  /// Fiksna relacija izabrana za sledeću vožnju; null = taksimetar.
  FixedRoute? _fixedRoute;

  @override
  void initState() {
    super.initState();
    // Osvežava prikaz cene i kad GPS ne šalje nove tačke (npr. tunel).
    _priceTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(taximeterProvider).isRunning) setState(() {});
    });
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      final auto = ref.read(appSettingsProvider).value?.autoTariff ?? false;
      if (mounted && auto && !ref.read(taximeterProvider).isRunning) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _priceTick?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  /// Tokom (i posle) vožnje tarifu javlja servis (status/recovered), pa ekran
  /// posle oporavka prikazuje pravu. Između vožnji: ručni izbor (pamti se) ili
  /// automatski po prazniku/rasporedu u ovom trenutku. Tarife unosi korisnik;
  /// dok ih nema, vraća null.
  TariffChoice? get _choice {
    final tariffs = ref.read(tariffsProvider).value ?? const <Tariff>[];
    if (tariffs.isEmpty) return null;
    final state = ref.read(taximeterProvider);
    if (state.isRunning || state.phase == RidePhase.finished) {
      final t = tariffs
          .where((t) => t.id == state.selectedTariffId)
          .firstOrNull;
      if (t != null) return TariffChoice(t, TariffChoiceReason.manual);
    }
    final settings = ref.read(appSettingsProvider).value;
    return TariffSelector.choose(
      tariffs: tariffs,
      holidays: ref.read(holidaysProvider).value ?? const <Holiday>[],
      local: DateTime.now(),
      automatic: settings?.autoTariff ?? false,
      manualTariffId: settings?.selectedTariffId,
    );
  }

  Tariff? get _activeTariff => _choice?.tariff;

  /// Rezime vožnje se otvara čim se vožnja završi (čita se iz baze, pa
  /// prikazuje isto što i istorija). Zatvaranje ostavlja mali rezultat ispod.
  Future<void> _showSummary(int rideId) async {
    final ride = await ref.read(rideHistoryRepositoryProvider).getById(rideId);
    if (ride == null || !mounted) return;
    ref.invalidate(rideHistoryProvider);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RideSummaryScreen(
          ride: ride,
          onNewRide: ref.read(taximeterProvider.notifier).newRide,
        ),
      ),
    );
  }

  Future<void> _selectTariff(int id) async {
    ref.read(taximeterProvider.notifier).setTariff(id);
    await ref
        .read(appSettingsProvider.notifier)
        .change((s) => s.copyWith(selectedTariffId: id));
  }

  Future<void> _openSettings() => Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => const SettingsScreen()));

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
        currentTariffId: _activeTariff?.id ?? 0,
        onTariffSelected: (selected) => _selectTariff(selected.id),
        currentFixedRouteId: _fixedRoute?.id,
        onFixedRouteSelected: (route) => setState(() => _fixedRoute = route),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(trProvider); // prevod se menja sa jezikom
    ref.listen<TaximeterState>(taximeterProvider, (prev, next) {
      final finishedNow =
          next.phase == RidePhase.finished && prev?.phase != RidePhase.finished;
      final s = ref.read(appSettingsProvider).value;
      if (finishedNow && next.lastResult != null) {
        _showSummary(next.lastResult!.rideId);
      }
      if (!finishedNow ||
          s == null ||
          !s.voiceAnnounce ||
          next.lastResult == null) {
        return;
      }
      ref
          .read(voiceServiceProvider)
          .speak(
            Announcement.rideFinished(
              next.lastResult!.totalPrice,
              language: s.language,
              fixedRouteName: next.fixedRouteName,
            ),
            language: s.language,
          );
    });
    final state = ref.watch(taximeterProvider);
    final notifier = ref.read(taximeterProvider.notifier);

    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final tariffs = ref.watch(tariffsProvider).value ?? const <Tariff>[];
    final eurRate = settings.eurRateMilli;
    final badgeSpeed = state.waitingSpeedKmh ?? settings.waitingSpeedKmh;
    ref.watch(holidaysProvider);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final choice = _choice;
    final tariff = choice?.tariff;
    final autoPicked =
        choice != null &&
        (choice.reason == TariffChoiceReason.schedule ||
            choice.reason == TariffChoiceReason.holiday);
    // EUR samo uz kurs koji je korisnik uneo; račun je celobrojan.
    final currency = (settings.currency == 'EUR' && eurRate != null)
        ? 'EUR'
        : 'RSD';
    // Ekran uvek uključen (podešavanje); uključuje se samo pri promeni.
    if (_wakelockOn != settings.keepScreenOn) {
      _wakelockOn = settings.keepScreenOn;
      settings.keepScreenOn ? WakelockPlus.enable() : WakelockPlus.disable();
    }
    final shownPrice = _throttle.show(
      state.currentPrice,
      DateTime.now().millisecondsSinceEpoch,
      settings.priceRefreshSeconds * 1000,
      force: state.phase != RidePhase.running,
    );
    final displayPrice = (currency == 'EUR')
        ? CurrencyConverter.formatForeign(shownPrice, eurRate!)
        : shownPrice.toString();

    // Trenutno stajanje (servis javlja mode), ne ukupno čekanje
    final isWaiting = state.isRunning && state.isWaitingNow;
    final isFinished = state.phase == RidePhase.finished;
    final result = state.lastResult;

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: TaximeterDrawer(
        onHistoryTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const HistoryScreen())),
        onReportsTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ReportsScreen())),
        onTariffsTap: () => _openTariffSheet(context),
        onSettingsTap: _openSettings,
      ),
      body: Stack(
        children: [
          if (settings.backgroundLogoPath != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.18,
                child: Image.file(
                  File(settings.backgroundLogoPath!),
                  fit: BoxFit.contain,
                  // obrisana/nedostupna slika: ostaje crna pozadina
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              // Horizontalno: taksimetar levo, mapa desno (u koloni nema mesta).
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Gornja traka: Meni, Pravna napomena i Preklopnici
                        Row(
                          children: [
                            Builder(
                              builder: (innerContext) => IconButton(
                                icon: const Icon(
                                  Icons.menu,
                                  color: Colors.white70,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () =>
                                    Scaffold.of(innerContext).openDrawer(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                t('POMOĆNI TAKSIMETAR'),
                                style: TextStyle(
                                  color: Colors.amberAccent.withValues(
                                    alpha: 0.85,
                                  ),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => ref
                                  .read(appSettingsProvider.notifier)
                                  .change(
                                    (s) => s.copyWith(
                                      language: s.language == 'sr'
                                          ? 'en'
                                          : 'sr',
                                    ),
                                  ),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                backgroundColor: Colors.white10,
                                minimumSize: const Size(36, 28),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                              ),
                              child: Text(
                                settings.language.toUpperCase(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                            TextButton(
                              onPressed: () async {
                                if (currency == 'RSD' && eurRate == null) {
                                  // Nema ugrađenog kursa: prvo ga korisnik unosi u podešavanjima.
                                  await _openSettings();
                                  return;
                                }
                                await ref
                                    .read(appSettingsProvider.notifier)
                                    .change(
                                      (s) => s.copyWith(
                                        currency: currency == 'RSD'
                                            ? 'EUR'
                                            : 'RSD',
                                      ),
                                    );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.amberAccent,
                                backgroundColor: Colors.white10,
                                minimumSize: const Size(44, 28),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                              ),
                              child: Text(
                                currency,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(flex: 1),

                        // Status režima rada (Vožnja vs Čekanje)
                        // Pauza: obračun staje, cena ostaje; prikazuje se trajanje pauze
                        if (state.phase == RidePhase.paused)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.amberAccent.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.amberAccent,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.pause_circle,
                                    color: Colors.amberAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    state.pausedSince == null
                                        ? t('PAUZIRANO')
                                        : '${t('PAUZIRANO')} · ${formatClock(DateTime.now().difference(state.pausedSince!).inSeconds)}',
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (state.isRunning)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isWaiting
                                    ? Colors.orangeAccent.withValues(
                                        alpha: 0.15,
                                      )
                                    : Colors.greenAccent.withValues(
                                        alpha: 0.15,
                                      ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isWaiting
                                      ? Colors.orangeAccent
                                      : Colors.greenAccent,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isWaiting
                                        ? Icons.hourglass_top
                                        : Icons.directions_car,
                                    color: isWaiting
                                        ? Colors.orangeAccent
                                        : Colors.greenAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isWaiting
                                        ? (t('ČEKANJE (< {0} km/h)', [badgeSpeed]))
                                        : (t('VOŽNJA')),
                                    style: TextStyle(
                                      color: isWaiting
                                          ? Colors.orangeAccent
                                          : Colors.greenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Glavna cifra (Cena); smanjuje se kad nema mesta
                        // (horizontalno, ili uz mapu na manjem ekranu)
                        Flexible(
                          flex: 3,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayPrice,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: priceColorOf(settings.priceColor),
                                    fontSize: 82 * settings.priceScale / 100,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -3,
                                  ),
                                ),
                                Text(
                                  currency,
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
                        ),

                        if (settings.showMap && !landscape)
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: RideMap(
                                tariff: tariff,
                                calibrationPermille:
                                    settings.calibrationPermille,
                                fixedPrice: _fixedRoute?.price,
                              ),
                            ),
                          )
                        else
                          const Spacer(flex: 1),

                        // Info paneli: Razdaljina, Čekanje i Tarifa
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _InfoBlock(
                                label: t('DISTANCA'),
                                value:
                                    t('{0} km', [(state.currentDistanceMeters / 1000).toStringAsFixed(2)]),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white12,
                              ),
                              _InfoBlock(
                                label: t('ČEKANJE'),
                                value: _formatDuration(state.currentWaitingMs),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white12,
                              ),
                              _InfoBlock(
                                label: t('START'),
                                value:
                                    '${state.rideStartPrice ?? tariff?.startPrice ?? '-'}',
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
                                if (state.fixedRouteName != null)
                                  _ResultLine(
                                    t('Fiksno: {0}', [state.fixedRouteName]),
                                    result.totalPrice,
                                  )
                                else ...[
                                  _ResultLine(
                                    t('Start'),
                                    result.startPrice,
                                  ),
                                  _ResultLine(
                                    t('Kilometraža'),
                                    result.kmPrice,
                                  ),
                                  _ResultLine(
                                    t('Čekanje'),
                                    result.waitingPrice,
                                  ),
                                ],
                                if (result.minPriceAdjustment > 0)
                                  _ResultLine(
                                    t('Dopuna do minimalne'),
                                    result.minPriceAdjustment,
                                  ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => printRideReceipt(
                                      context,
                                      ref,
                                      result.rideId,
                                    ),
                                    icon: const Icon(
                                      Icons.print,
                                      color: Colors.amberAccent,
                                      size: 18,
                                    ),
                                    label: Text(
                                      t('ŠTAMPAJ RAČUN'),
                                      style: const TextStyle(
                                        color: Colors.amberAccent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // V12: vozač vidi da je bilo prekida GPS signala
                        if (state.isRunning && state.gapCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Text(
                              t('GPS signal prekidan {0}× (ukupno {1})', [state.gapCount, formatClock(state.gapMs ~/ 1000)]),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),

                        // Poruke o grešci ili upozorenja
                        if (state.warningMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Text(
                              state.warningMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        if (state.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Text(
                              state.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
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
                                  border: Border.all(
                                    color: Colors.amberAccent.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.tune,
                                      color: Colors.amberAccent,
                                      size: 22,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tariff == null
                                          ? '-'
                                          : (tariff.name.length > 6
                                                ? tariff.name.substring(0, 6)
                                                : tariff.name),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (_fixedRoute != null && !state.isRunning)
                                      Text(
                                        t('FIKSNO'),
                                        style: TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: 9,
                                        ),
                                      )
                                    else if (autoPicked)
                                      Text(
                                        choice.reason ==
                                                TariffChoiceReason.holiday
                                            ? t('PRAZNIK')
                                            : t('AUTO'),
                                        style: const TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: 9,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Fiksne relacije: pretraga i izbor za sledeću vožnju
                            if (!state.isRunning)
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showFixedRoutePicker(
                                    context,
                                    selectedId: _fixedRoute?.id,
                                  );
                                  if (picked == null || !mounted) return;
                                  // id -1 = "bez fiksne relacije"
                                  setState(
                                    () => _fixedRoute = picked.id == -1
                                        ? null
                                        : picked,
                                  );
                                },
                                child: Container(
                                  height: 74,
                                  width: 74,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1C1C1C),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: _fixedRoute == null
                                          ? Colors.white24
                                          : Colors.amberAccent,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.route,
                                        color: _fixedRoute == null
                                            ? Colors.white54
                                            : Colors.amberAccent,
                                        size: 22,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _fixedRoute == null
                                            ? t('RELACIJE')
                                            : '${_fixedRoute!.price}',
                                        style: TextStyle(
                                          color: _fixedRoute == null
                                              ? Colors.white54
                                              : Colors.amberAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Masivno Start / Stop dugme
                            Expanded(
                              child: SizedBox(
                                height: 74,
                                child: isFinished
                                    ? ElevatedButton(
                                        onPressed: notifier.newRide,
                                        style: _mainButtonStyle(
                                          const Color(0xFF1565C0),
                                        ),
                                        child: _mainButtonLabel(
                                          t('NOVA VOŽNJA'),
                                        ),
                                      )
                                    : state.isRunning
                                    ? Row(
                                        children: [
                                          // PAUZA / NASTAVI: obračun staje, cena ostaje
                                          Expanded(
                                            flex: 4,
                                            child: SizedBox(
                                              height: 74,
                                              child: ElevatedButton(
                                                onPressed: state.isBusy
                                                    ? null
                                                    : (state.phase ==
                                                              RidePhase.paused
                                                          ? notifier.resumeRide
                                                          : notifier.pauseRide),
                                                style: _mainButtonStyle(
                                                  state.phase ==
                                                          RidePhase.paused
                                                      ? const Color(0xFF2E7D32)
                                                      : const Color(0xFFF9A825),
                                                ),
                                                child: FittedBox(
                                                  child: _mainButtonLabel(
                                                    state.phase ==
                                                            RidePhase.paused
                                                        ? (t('NASTAVI'))
                                                        : (t('PAUZA')),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 5,
                                            child: SizedBox(
                                              height: 74,
                                              child: ElevatedButton(
                                                onPressed: state.isBusy
                                                    ? null
                                                    : notifier.stopRide,
                                                style: _mainButtonStyle(
                                                  const Color(0xFFD32F2F),
                                                ),
                                                child: FittedBox(
                                                  child: _mainButtonLabel(
                                                    t('ZAVRŠI'),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : ElevatedButton(
                                        onPressed: !state.isReady
                                            ? notifier.retryConnect
                                            : tariffs.isEmpty
                                            ? () async {
                                                final id =
                                                    await showTariffEditor(
                                                      context,
                                                      ref,
                                                    );
                                                if (id != null && id > 0) {
                                                  await _selectTariff(id);
                                                }
                                              }
                                            : () {
                                                // tarifa se bira u trenutku starta
                                                final t = _activeTariff!;
                                                notifier.startRide(
                                                  tariffId: t.id,
                                                  startPrice: t.startPrice,
                                                  pricePerKm: t.pricePerKm,
                                                  waitingParaPerMin:
                                                      t.waitingParaPerMin,
                                                  minPrice: t.minPrice,
                                                  waitingSpeedKmh:
                                                      settings.waitingSpeedKmh,
                                                  calibrationPermille: settings
                                                      .calibrationPermille,
                                                  gpsAccuracyM:
                                                      settings.gpsAccuracyM,
                                                  fixedPrice:
                                                      _fixedRoute?.price,
                                                  fixedRouteName:
                                                      _fixedRoute?.name,
                                                );
                                                // relacija važi za jednu vožnju
                                                setState(
                                                  () => _fixedRoute = null,
                                                );
                                              },
                                        style: _mainButtonStyle(
                                          const Color(0xFF2E7D32),
                                        ),
                                        child: _mainButtonLabel(
                                          !state.isReady
                                              ? (t('POVEŽI SE PONOVO'))
                                              : tariffs.isEmpty
                                              ? (t('DODAJ TARIFU'))
                                              : (t('POKRENI (START)')),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  if (settings.showMap && landscape) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: RideMap(
                        tariff: tariff,
                        calibrationPermille: settings.calibrationPermille,
                        fixedPrice: _fixedRoute?.price,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends ConsumerWidget {
  final String label;
  final String value;

  const _InfoBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class _ResultLine extends ConsumerWidget {
  final String label;
  final int amount;

  const _ResultLine(this.label, this.amount);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            '$amount',
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
