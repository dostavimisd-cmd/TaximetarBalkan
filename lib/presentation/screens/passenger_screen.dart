import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/currency_converter.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/extra_charge.dart';
import '../../domain/ride_summary.dart';
import '../l10n/tr.dart';
import '../providers/settings_provider.dart';
import '../providers/tariffs_provider.dart';
import '../providers/taximeter_provider.dart';
import '../widgets/price_colors.dart';

const _card = Color(0xFF141414);
const _border = Color(0xFF2A2A2A);
const _muted = Color(0xFFB8B8B8);

/// Ekran za putnika (G5): položen telefon ili tablet u držaču, velika cena,
/// logo i naziv firme; posle kraja vožnje „Za naplatu” sa razradom.
/// Tokom vožnje vozač može i odavde da pauzira, nastavi i završi vožnju
/// (iste komande kao na glavnom ekranu).
class PassengerScreen extends ConsumerStatefulWidget {
  const PassengerScreen({super.key});

  @override
  ConsumerState<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends ConsumerState<PassengerScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  /// 1248 → „1.248” (tačka za hiljade, kao na računu).
  static String money(int v) {
    final s = v.abs().toString();
    final b = StringBuffer(v < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final state = ref.watch(taximeterProvider);
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final result = state.phase == RidePhase.finished ? state.lastResult : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 12),
              child: result == null
                  ? _running(t, state, settings)
                  : _finished(t, state, result, settings),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: t('Zatvori'),
                icon: const Icon(Icons.close, color: Colors.white24),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _firm(AppSettings s, {double logo = 52}) {
    final lines = s.receiptHeader
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final path = s.receiptLogoPath;
    final hasLogo = path != null && File(path).existsSync();
    if (!hasLogo && lines.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        if (hasLogo)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(path),
              width: logo,
              height: logo,
              fit: BoxFit.contain,
            ),
          ),
        if (hasLogo) const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // zaglavlje računa je korisnički tekst: ne prevodi se
              if (lines.isNotEmpty)
                Text(
                  lines.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (lines.length > 1)
                Text(
                  lines[1],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Cena popunjava 80% svog prostora (cela je bila prevelika).
  Widget _price(int value, Color color, {double max = 150}) => Expanded(
    child: FractionallySizedBox(
      widthFactor: 0.8,
      heightFactor: 0.8,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(value),
              style: TextStyle(
                color: color,
                fontSize: max,
                height: 1,
                fontWeight: FontWeight.bold,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(width: 14),
            Padding(
              padding: EdgeInsets.only(bottom: max * 0.12),
              child: Text(
                'RSD',
                style: TextStyle(
                  color: _muted,
                  fontSize: max * 0.23,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _button(String label, Color color, VoidCallback? onPressed) =>
      SizedBox(
        width: 150,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: color.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: FittedBox(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      );

  Widget _tile(String label, String value, {Color color = Colors.white}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFA8A8A8),
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
              FittedBox(
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _running(Tr t, TaximeterState state, AppSettings s) {
    final paused = state.phase == RidePhase.paused;
    final active = state.isRunning;
    final tariffs = ref.watch(tariffsProvider).value ?? const [];
    final tariff = tariffs
        .where((x) => x.id == state.selectedTariffId)
        .firstOrNull;
    final extras = ExtraCharge.total(state.extras);
    final statusColor = paused ? Colors.amberAccent : const Color(0xFF66D19E);
    final notifier = ref.read(taximeterProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _firm(s)),
            if (active)
              Container(
                margin: const EdgeInsets.only(right: 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  paused ? t('PAUZA') : t('VOŽNJA U TOKU'),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: Row(
            children: [
              _price(
                active ? state.currentPrice : 0,
                priceColorOf(s.priceColor),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _tile(
                t('DISTANCA'),
                t('{0} km', [
                  (state.currentDistanceMeters / 1000).toStringAsFixed(1),
                ]),
              ),
              const SizedBox(width: 10),
              _tile(
                t('ČEKANJE'),
                RideSummary.clock(state.currentWaitingMs ~/ 1000),
              ),
              if (extras > 0) ...[
                const SizedBox(width: 10),
                _tile(t('DOPLATA'), '+$extras', color: const Color(0xFFFFD54F)),
              ],
              if (state.fixedRouteName != null || tariff != null) ...[
                const SizedBox(width: 10),
                // naziv relacije i tarife unosi korisnik: ne prevodi se
                _tile(
                  state.fixedRouteName != null ? t('RELACIJA') : t('TARIFA'),
                  state.fixedRouteName ?? tariff!.name,
                ),
              ],
              // PAUZA/NASTAVI i ZAVRŠI: iste komande kao na glavnom ekranu
              if (active) ...[
                const SizedBox(width: 10),
                _button(
                  paused ? t('NASTAVI') : t('PAUZA'),
                  paused ? const Color(0xFF2E7D32) : const Color(0xFFF9A825),
                  state.isBusy
                      ? null
                      : (paused ? notifier.resumeRide : notifier.pauseRide),
                ),
                const SizedBox(width: 10),
                _button(
                  t('ZAVRŠI'),
                  const Color(0xFFD32F2F),
                  state.isBusy ? null : notifier.stopRide,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t('Pomoćni taksimetar · nije overeni taksimetar ni fiskalni uređaj'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 11),
        ),
      ],
    );
  }

  Widget _finished(Tr t, TaximeterState state, RideResult r, AppSettings s) {
    Widget line(String label, int value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? Colors.white : _muted,
                fontSize: bold ? 18 : 15,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            t('{0} din', [money(value)]),
            style: TextStyle(
              color: bold ? const Color(0xFFFFD54F) : Colors.white,
              fontSize: bold ? 18 : 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
    final eur = s.eurRateMilli;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _firm(s, logo: 44),
              const Spacer(),
              Text(
                t('ZA NAPLATU'),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(
                height: 130,
                child: Row(
                  children: [
                    _price(r.totalPrice, const Color(0xFFFFD54F), max: 120),
                  ],
                ),
              ),
              if (eur != null)
                Text(
                  '≈ ${t('{0} EUR', [CurrencyConverter.formatForeign(r.totalPrice, eur)])}',
                  style: const TextStyle(
                    color: Color(0xFFD0D0D0),
                    fontSize: 18,
                  ),
                ),
              const Spacer(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Container(
          width: 300,
          margin: const EdgeInsets.only(top: 36),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (state.fixedRouteName != null)
                line(t('Fiksno: {0}', [state.fixedRouteName]), r.startPrice)
              else ...[
                line(t('Start'), r.startPrice),
                line(
                  t('Kilometraža ({0} km)', [
                    (r.distanceMeters / 1000).toStringAsFixed(1),
                  ]),
                  r.kmPrice,
                ),
                line(
                  t('Čekanje ({0})', [RideSummary.clock(r.waitingSeconds)]),
                  r.waitingPrice,
                ),
              ],
              if (r.minPriceAdjustment > 0)
                line(t('Dopuna do minimalne'), r.minPriceAdjustment),
              for (final e in r.extras) line(e.name, e.amount),
              const Divider(color: _border, height: 18),
              line(t('UKUPNO'), r.totalPrice, bold: true),
            ],
          ),
        ),
      ],
    );
  }
}
