import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/calibration.dart';
import '../../domain/currency_converter.dart';
import '../../domain/models/app_settings.dart';
import '../providers/settings_provider.dart';

/// Podešavanja korisnika. Vrednosti važe od sledećeg starta vožnje; vožnja u
/// toku zadržava ono sa čim je počela (upisano je u `rides`).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _speed = TextEditingController();
  final _calibration = TextEditingController();
  final _gps = TextEditingController();
  final _rate = TextEditingController();
  String _language = 'sr';
  String _currency = 'RSD';
  bool _loaded = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_speed, _calibration, _gps, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(AppSettings s) {
    _speed.text = '${s.waitingSpeedKmh}';
    _calibration.text = Calibration.formatPercent(s.calibrationPermille);
    _gps.text = '${s.gpsAccuracyM}';
    _rate.text = s.eurRateMilli == null ? '' : CurrencyConverter.formatRate(s.eurRateMilli!);
    _language = s.language;
    _currency = s.currency;
    _loaded = true;
  }

  Future<void> _save(AppSettings current) async {
    final speed = int.tryParse(_speed.text.trim());
    final gps = int.tryParse(_gps.text.trim());
    final calibration = Calibration.parsePercent(_calibration.text);
    final rateText = _rate.text.trim();
    final rate = rateText.isEmpty ? null : CurrencyConverter.parseRateMilli(rateText);

    String? error;
    if (speed == null) error = 'Unesi brzinu za čekanje (ceo broj km/h).';
    if (calibration == null) {
      error ??= 'Kalibracija: procenat od -50 do 50, npr. 2,5 ili -1.';
    }
    if (gps == null) error ??= 'Unesi GPS tačnost (ceo broj metara).';
    if (rateText.isNotEmpty && rate == null) {
      error ??= 'Kurs: npr. 117,2 (najviše 3 decimale).';
    }
    if (_currency == 'EUR' && rate == null) {
      error ??= 'Za prikaz u EUR unesi kurs.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final next = AppSettings(
      eurRateMilli: rate,
      waitingSpeedKmh: speed!,
      calibrationPermille: calibration!,
      gpsAccuracyM: gps!,
      language: _language,
      currency: _currency,
      selectedTariffId: current.selectedTariffId,
    );
    final invalid = next.validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    await ref.read(appSettingsProvider.notifier).save(next);
    if (mounted) Navigator.pop(context, true);
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 22, 0, 6),
        child: Text(title,
            style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
      );

  Widget _number(String label, TextEditingController c,
      {String? helper, String allow = r'[0-9]', bool decimal = false, bool signed = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal, signed: signed),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(allow))],
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          helperText: helper,
          helperMaxLines: 2,
          helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
          isDense: true,
        ),
      ),
    );
  }

  Widget _choice(String label, List<String> options, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
          SegmentedButton<String>(
            segments: [
              for (final o in options) ButtonSegment(value: o, label: Text(o.toUpperCase())),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => onChanged(s.first)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Podešavanja'),
        actions: [
          TextButton(
            onPressed: settings.hasValue ? () => _save(settings.value!) : null,
            child: const Text('SAČUVAJ', style: TextStyle(color: Colors.amberAccent)),
          ),
        ],
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Greška: $e', style: const TextStyle(color: Colors.redAccent))),
        data: (s) {
          if (!_loaded) _fill(s);
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _section('OBRAČUN'),
              _number('Čekanje se računa ispod (km/h)', _speed,
                  helper:
                      'Ceo broj ${AppSettings.minWaitingSpeedKmh}–${AppSettings.maxWaitingSpeedKmh}. Ispod ove brzine taksimetar računa čekanje umesto kilometara.'),
              _number('Kalibracija distance (%)', _calibration,
                  allow: r'[0-9.,+-]',
                  decimal: true,
                  signed: true,
                  helper: '0 = bez korekcije; 2,5 = distanca +2,5%. Uskladi sa zvaničnim taksimetrom.'),
              _section('GPS'),
              _number('Najveća dozvoljena nepreciznost (m)', _gps,
                  helper:
                      'Ceo broj ${AppSettings.minGpsAccuracyM}–${AppSettings.maxGpsAccuracyM}. Tačke sa lošijom procenom tačnosti se odbacuju. Manje = strože.'),
              _section('PRIKAZ'),
              _choice('Jezik', AppSettings.languages, _language, (v) => _language = v),
              _choice('Valuta prikaza', AppSettings.currencies, _currency, (v) => _currency = v),
              _number('Kurs: dinara za 1 EUR', _rate,
                  allow: r'[0-9.,]',
                  decimal: true,
                  helper: 'Samo za prikaz u EUR. Obračun je uvek u dinarima.'),
              _section('RAD U POZADINI'),
              const Text(
                'Da taksimetar ne bi bio ugašen na zaključanom ekranu, isključi optimizaciju baterije za aplikaciju i dozvoli rad u pozadini.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.battery_charging_full, color: Colors.amberAccent),
                label: const Text('Otvori podešavanja aplikacije',
                    style: TextStyle(color: Colors.amberAccent)),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              const SizedBox(height: 24),
              const Text(
                'Pomoćni alat za evidenciju i procenu, nije overeni službeni taksimetar ni fiskalni uređaj.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
