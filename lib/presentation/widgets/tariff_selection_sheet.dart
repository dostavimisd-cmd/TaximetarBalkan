import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/currency_converter.dart';
import '../../domain/models/fixed_route.dart';
import '../../domain/models/tariff.dart';
import '../providers/settings_provider.dart';
import '../providers/tariffs_provider.dart';
import 'tariff_edit_dialog.dart';
import '../l10n/tr.dart';

/// Izbor i upravljanje tarifama koje je korisnik uneo (nema ugrađenih).
class TariffSelectionSheet extends ConsumerWidget {
  final int currentTariffId;
  final void Function(Tariff selected) onTariffSelected;

  /// Izabrana fiksna relacija za sledeću vožnju (null = taksimetar).
  final int? currentFixedRouteId;
  final void Function(FixedRoute? route)? onFixedRouteSelected;

  const TariffSelectionSheet({
    super.key,
    required this.currentTariffId,
    required this.onTariffSelected,
    this.currentFixedRouteId,
    this.onFixedRouteSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final tariffs = ref.watch(tariffsProvider).value ?? const <Tariff>[];
    final auto = ref.watch(appSettingsProvider).value?.autoTariff ?? false;
    final routes = ref.watch(fixedRoutesProvider).value ?? const <FixedRoute>[];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('TARIFE'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            if (auto)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  t('Automatski izbor je uključen: pri startu važe praznici pa raspored. Ručno izabrana tarifa važi kad nijedno pravilo ne važi.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.amberAccent, fontSize: 11),
                ),
              ),
            const SizedBox(height: 16),
            if (tariffs.isEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  t('Još nema tarifa. Unesi tarifu koju primenjuješ.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ...tariffs.map((tariff) {
              final isSelected = tariff.id == currentTariffId;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? Colors.amberAccent : Colors.white10,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    tariff.name,
                    style: TextStyle(
                      color: isSelected ? Colors.amberAccent : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${t('Start: {0} | Km: {1} | Čekanje/min: {2} | Min: {3}', [tariff.startPrice, tariff.pricePerKm, CurrencyConverter.formatPara(tariff.waitingParaPerMin), tariff.minPrice])}'
                      '${tariff.schedule == null ? '' : '\n${t('Raspored')}: ${tariff.schedule!.describe()}'}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: () =>
                        showTariffEditor(context, ref, existing: tariff),
                  ),
                  onTap: () {
                    onTariffSelected(tariff);
                    Navigator.pop(context);
                  },
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () async {
                final id = await showTariffEditor(context, ref);
                if (id == null || id <= 0 || !context.mounted) return;
                final saved = ref
                    .read(tariffsProvider)
                    .value
                    ?.where((t) => t.id == id)
                    .firstOrNull;
                if (saved != null) onTariffSelected(saved);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.add, color: Colors.amberAccent),
              label: Text(
                t('NOVA TARIFA'),
                style: TextStyle(color: Colors.amberAccent),
              ),
            ),
            if (routes.isNotEmpty && onFixedRouteSelected != null) ...[
              const SizedBox(height: 16),
              Text(
                t('FIKSNA RELACIJA (sledeća vožnja)'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              for (final r in routes)
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.route,
                    color: r.id == currentFixedRouteId
                        ? Colors.amberAccent
                        : Colors.white38,
                  ),
                  title: Text(
                    r.name,
                    style: TextStyle(
                      color: r.id == currentFixedRouteId
                          ? Colors.amberAccent
                          : Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    r.describe(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () {
                    onFixedRouteSelected!(
                      r.id == currentFixedRouteId ? null : r,
                    );
                    Navigator.pop(context);
                  },
                ),
              if (currentFixedRouteId != null)
                TextButton(
                  onPressed: () {
                    onFixedRouteSelected!(null);
                    Navigator.pop(context);
                  },
                  child: Text(
                    t('Bez fiksne relacije (taksimetar)'),
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
