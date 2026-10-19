import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/currency_converter.dart';
import '../../domain/models/tariff.dart';
import '../providers/tariffs_provider.dart';
import 'tariff_edit_dialog.dart';

/// Izbor i upravljanje tarifama koje je korisnik uneo (nema ugrađenih).
class TariffSelectionSheet extends ConsumerWidget {
  final int currentTariffId;
  final void Function(Tariff selected) onTariffSelected;

  const TariffSelectionSheet({
    super.key,
    required this.currentTariffId,
    required this.onTariffSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tariffs = ref.watch(tariffsProvider).value ?? const <Tariff>[];

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
            const Text(
              'TARIFE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            if (tariffs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Još nema tarifa. Unesi tarifu koju primenjuješ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ...tariffs.map((t) {
              final isSelected = t.id == currentTariffId;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2A2A2A) : const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? Colors.amberAccent : Colors.white10,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    t.name,
                    style: TextStyle(
                      color: isSelected ? Colors.amberAccent : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Start: ${t.startPrice} | Km: ${t.pricePerKm} | '
                      'Čekanje/min: ${CurrencyConverter.formatPara(t.waitingParaPerMin)} | Min: ${t.minPrice}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                    onPressed: () => showTariffEditor(context, ref, existing: t),
                  ),
                  onTap: () {
                    onTariffSelected(t);
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
              label: const Text('NOVA TARIFA',
                  style: TextStyle(color: Colors.amberAccent)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
