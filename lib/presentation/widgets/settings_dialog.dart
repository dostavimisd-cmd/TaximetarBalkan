import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/currency_converter.dart';
import '../providers/tariffs_provider.dart';

/// Podešavanja: kurs za prikaz u EUR. Aplikacija nema ugrađen kurs.
/// Vraća true ako je kurs sačuvan.
Future<bool?> showSettingsDialog(BuildContext context, WidgetRef ref) {
  return showDialog<bool>(
    context: context,
    builder: (_) => const _SettingsDialog(),
  );
}

class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog();

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  late final TextEditingController _rate;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = ref.read(eurRateProvider).value;
    _rate = TextEditingController(
        text: current == null ? '' : CurrencyConverter.formatRate(current));
  }

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final milli = CurrencyConverter.parseRateMilli(_rate.text);
    if (milli == null) {
      setState(() => _error = 'Unesi kurs, npr. 117.2 (najviše 3 decimale).');
      return;
    }
    await ref.read(eurRateProvider.notifier).set(milli);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Podešavanja', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Kurs: dinara za 1 EUR',
              labelStyle: TextStyle(color: Colors.white54),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Koristi se samo za prikaz iznosa u EUR. Cene i obračun ostaju u dinarima.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ODUSTANI', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('SAČUVAJ', style: TextStyle(color: Colors.amberAccent)),
        ),
      ],
    );
  }
}
