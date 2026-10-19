import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/ride_engine.dart';
import '../../domain/calibration.dart';
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
  late final TextEditingController _speed;
  late final TextEditingController _calibration;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = ref.read(eurRateProvider).value;
    _speed = TextEditingController(
        text: '${ref.read(waitingSpeedProvider).value ?? RideEngine.defaultWaitingSpeedKmh}');
    _calibration = TextEditingController(
        text: Calibration.formatPercent(
            ref.read(calibrationProvider).value ?? Calibration.neutralPermille));
    _rate = TextEditingController(
        text: current == null ? '' : CurrencyConverter.formatRate(current));
  }

  @override
  void dispose() {
    _rate.dispose();
    _speed.dispose();
    _calibration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final speed = int.tryParse(_speed.text.trim());
    if (speed == null ||
        speed < RideEngine.minWaitingSpeedKmh ||
        speed > RideEngine.maxWaitingSpeedKmh) {
      setState(() => _error =
          'Brzina za čekanje: ceo broj od ${RideEngine.minWaitingSpeedKmh} do ${RideEngine.maxWaitingSpeedKmh} km/h.');
      return;
    }
    final calibration = Calibration.parsePercent(_calibration.text);
    if (calibration == null) {
      setState(() => _error =
          'Kalibracija: procenat od -50 do 50, npr. 2,5 ili -1 (najviše 1 decimala).');
      return;
    }
    // Kurs je opcion: prazno polje ostavlja EUR prikaz isključen.
    final rateText = _rate.text.trim();
    final milli = rateText.isEmpty ? null : CurrencyConverter.parseRateMilli(rateText);
    if (rateText.isNotEmpty && milli == null) {
      setState(() => _error = 'Unesi kurs, npr. 117.2 (najviše 3 decimale).');
      return;
    }
    await ref.read(waitingSpeedProvider.notifier).set(speed);
    await ref.read(calibrationProvider.notifier).set(calibration);
    if (milli != null) await ref.read(eurRateProvider.notifier).set(milli);
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
          const SizedBox(height: 14),
          TextField(
            controller: _speed,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Čekanje se računa ispod (km/h)',
              labelStyle: TextStyle(color: Colors.white54),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _calibration,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,+-]'))],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Kalibracija distance (%)',
              labelStyle: TextStyle(color: Colors.white54),
              helperText: '0 = bez korekcije; 2,5 = distanca +2,5%',
              helperStyle: TextStyle(color: Colors.white38, fontSize: 11),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Brzina ispod koje taksimetar računa čekanje umesto kilometara.\n'
            'Kurs: koristi se samo za prikaz iznosa u EUR. Cene i obračun ostaju u dinarima.',
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
