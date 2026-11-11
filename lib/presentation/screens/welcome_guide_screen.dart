import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/tr.dart';
import '../providers/tariffs_provider.dart';
import '../widgets/battery_guide.dart';
import '../widgets/tariff_edit_dialog.dart';
import 'fixed_routes_screen.dart';
import 'settings_screen.dart';

/// D1: vodič za početak posle napomene pri prvom pokretanju (ponovo iz menija).
/// Svaki korak se može preskočiti; aplikacija ne predlaže cene (Pravilo 3).
/// Štampač i rad u pozadini su samo na Androidu.
class WelcomeGuideScreen extends ConsumerStatefulWidget {
  const WelcomeGuideScreen({super.key});

  @override
  ConsumerState<WelcomeGuideScreen> createState() => _WelcomeGuideScreenState();
}

enum _Step { tariff, routes, printer, battery }

class _WelcomeGuideScreenState extends ConsumerState<WelcomeGuideScreen> {
  late final List<_Step> _steps = [
    _Step.tariff,
    _Step.routes,
    if (Platform.isAndroid) ...[_Step.printer, _Step.battery],
  ];
  int _index = 0;

  static const _titles = {
    _Step.tariff: 'Tvoja tarifa',
    _Step.routes: 'Fiksne relacije (opciono)',
    _Step.printer: 'Štampač računa (opciono)',
    _Step.battery: 'Rad sa zaključanim ekranom',
  };

  static const _texts = {
    _Step.tariff:
        'Unesi start, cenu po km, čekanje i minimalnu cenu iz svog cenovnika. Aplikacija ne predlaže cene. Kasnije možeš dodati još tarifa (noćna, praznik) i raspored.',
    _Step.routes:
        'Ako imaš stalne cene za relacije (npr. aerodrom), nalepi spisak: jedan red je jedna relacija. Može i kasnije u Podešavanjima → Fiksne relacije.',
    _Step.printer:
        'Ako imaš Bluetooth termalni štampač, izaberi ga u Podešavanjima → Štampač računa. Bez štampača aplikacija radi normalno.',
    _Step.battery:
        'Da taksimetar kuca i kad je ekran zaključan, isključi štednju baterije za ovu aplikaciju. Vodič pokazuje korake za tvoj telefon.',
  };

  static const _actions = {
    _Step.tariff: 'DODAJ TARIFU',
    _Step.routes: 'UVEZI RELACIJE',
    _Step.printer: 'OTVORI PODEŠAVANJA',
    _Step.battery: 'PODESI BATERIJU',
  };

  static const _icons = {
    _Step.tariff: Icons.tune,
    _Step.routes: Icons.route,
    _Step.printer: Icons.print,
    _Step.battery: Icons.battery_alert,
  };

  Future<void> _act(_Step step) async {
    switch (step) {
      case _Step.tariff:
        await showTariffEditor(context, ref);
      case _Step.routes:
        await showFixedRouteImport(context);
      case _Step.printer:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
        );
      case _Step.battery:
        await showBatteryGuide(context, ref);
    }
  }

  void _next() {
    if (_index + 1 >= _steps.length) {
      Navigator.pop(context);
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final step = _steps[_index];
    final last = _index + 1 == _steps.length;
    final tariffCount = ref.watch(tariffsProvider).value?.length ?? 0;
    final routeCount = ref.watch(fixedRoutesProvider).value?.length ?? 0;
    final status = switch (step) {
      _Step.tariff => tariffCount > 0 ? t('Uneto tarifa: {0}', [tariffCount]) : null,
      _Step.routes => routeCount > 0 ? t('Uneto relacija: {0}', [routeCount]) : null,
      _ => null,
    };

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
        title: Text(t('Vodič za početak')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('ZATVORI'), style: const TextStyle(color: Colors.white54)),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  t('Korak {0} od {1}', [_index + 1, _steps.length]),
                  style: const TextStyle(color: Colors.amberAccent, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_index + 1) / _steps.length,
                  color: Colors.amberAccent,
                  backgroundColor: Colors.white12,
                ),
                const SizedBox(height: 32),
                Icon(_icons[step], color: Colors.amberAccent, size: 56),
                const SizedBox(height: 16),
                Text(
                  t(_titles[step]!),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t(_texts[step]!),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                ),
                if (status != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF66D19E), fontSize: 14),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _act(step),
                    icon: Icon(_icons[step], color: Colors.white),
                    label: Text(
                      t(_actions[step]!),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _next,
                    child: Text(
                      last ? t('GOTOVO') : t('DALJE'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
