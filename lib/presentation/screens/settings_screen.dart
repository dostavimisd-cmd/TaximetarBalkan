import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/calibration.dart';
import '../../domain/currency_converter.dart';
import '../../domain/models/app_settings.dart';
import '../printing/receipt_printer.dart';
import '../providers/settings_provider.dart';
import 'holidays_screen.dart';

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
  final _header = TextEditingController();
  String _language = 'sr';
  String _currency = 'RSD';
  bool _autoTariff = false;
  bool _showMap = true;
  String? _logoPath;
  String? _receiptLogoPath;
  String? _printerMac;
  String? _printerName;
  PrintOption _printOption = PrintOption.all.first;
  bool _printing = false;
  bool _loaded = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_speed, _calibration, _gps, _rate, _header]) {
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
    _autoTariff = s.autoTariff;
    _showMap = s.showMap;
    _logoPath = s.backgroundLogoPath;
    _receiptLogoPath = s.receiptLogoPath;
    _printerMac = s.printerMac;
    _printerName = s.printerName;
    _printOption = PrintOption.of(s);
    _header.text = s.receiptHeader;
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
      autoTariff: _autoTariff,
      showMap: _showMap,
      backgroundLogoPath: _logoPath,
      printerMac: _printerMac,
      printerName: _printerName,
      printMode: _printOption.mode,
      printCodePage: _printOption.codePage == 0 ? current.printCodePage : _printOption.codePage,
      receiptHeader: _header.text.trim(),
      receiptLogoPath: _receiptLogoPath,
    );
    final invalid = next.validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    await ref.read(appSettingsProvider.notifier).save(next);
    if (mounted) Navigator.pop(context, true);
  }

  /// Slika se kopira u fascikle aplikacije, da ostane i ako se original
  /// obriše. Vraća novu putanju ili null ako korisnik odustane.
  Future<String?> _pickImage(String prefix, String? old) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(picked.path).isEmpty ? '.png' : p.extension(picked.path);
    // novo ime svaki put, da se prikaz ne zadrži na staroj slici iz keša
    final target = p.join(dir.path, '${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(picked.path).copy(target);
    if (old != null && old != target) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    return target;
  }

  Future<void> _pickLogo() async {
    final path = await _pickImage('background_logo', _logoPath);
    if (path != null) setState(() => _logoPath = path);
  }

  Future<void> _pickReceiptLogo() async {
    final path = await _pickImage('receipt_logo', _receiptLogoPath);
    if (path != null) setState(() => _receiptLogoPath = path);
  }

  Future<void> _choosePrinter() async {
    try {
      final devices = await ref.read(receiptPrinterProvider).paired();
      if (!mounted) return;
      final chosen = await showDialog<(String, String)>(
        context: context,
        builder: (ctx) => SimpleDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Upareni uređaji', style: TextStyle(color: Colors.white)),
          children: [
            if (devices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nema uparenih uređaja. Upari štampač u Bluetooth podešavanjima telefona (PIN je obično 0000 ili 1234).',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            for (final d in devices)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, (d.macAdress, d.name)),
                child: Text('${d.name}\n${d.macAdress}',
                    style: const TextStyle(color: Colors.white)),
              ),
          ],
        ),
      );
      if (chosen != null) {
        setState(() {
          _printerMac = chosen.$1;
          _printerName = chosen.$2;
        });
      }
    } catch (e) {
      setState(() => _error = 'Štampač: $e');
    }
  }

  Future<void> _testPrint() async {
    final mac = _printerMac;
    if (mac == null) {
      setState(() => _error = 'Prvo izaberi štampač.');
      return;
    }
    setState(() {
      _printing = true;
      _error = null;
    });
    try {
      await ref.read(receiptPrinterProvider).send(mac, await ReceiptPrinter.testPageBytes());
    } catch (e) {
      if (mounted) setState(() => _error = 'Probna štampa nije uspela: $e');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
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
              _section('TARIFE'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _autoTariff,
                onChanged: (v) => setState(() => _autoTariff = v),
                title: const Text('Automatski izbor tarife pri startu',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    'Prvo praznici, pa raspored tarife (dani i vreme). Tarifa se ne menja tokom vožnje.',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const HolidaysScreen())),
                icon: const Icon(Icons.event, color: Colors.amberAccent),
                label: const Text('Praznici', style: TextStyle(color: Colors.amberAccent)),
              ),
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
              _section('IZGLED'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _showMap,
                onChanged: (v) => setState(() => _showMap = v),
                title: const Text('Prikaži mapu', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    'OpenStreetMap (besplatno). Podloge traže internet; obračun radi i bez mape.',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ),
              _choice('Pozadina', const ['crna', 'logo'], _logoPath == null ? 'crna' : 'logo',
                  (v) {
                if (v == 'crna') {
                  _logoPath = null;
                } else if (_logoPath == null) {
                  _pickLogo();
                }
              }),
              if (_logoPath != null)
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_logoPath!),
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image, color: Colors.white38)),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _pickLogo,
                      child: const Text('Promeni sliku', style: TextStyle(color: Colors.amberAccent)),
                    ),
                  ],
                ),
              _section('ŠTAMPAČ RAČUNA'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.print, color: Colors.amberAccent),
                title: Text(_printerName ?? 'Štampač nije izabran',
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(_printerMac ?? 'Bluetooth, 58 mm (npr. PT-210)',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
                trailing: TextButton(
                  onPressed: _choosePrinter,
                  child: const Text('IZABERI', style: TextStyle(color: Colors.amberAccent)),
                ),
              ),
              DropdownButton<PrintOption>(
                value: _printOption,
                isExpanded: true,
                dropdownColor: const Color(0xFF2A2A2A),
                items: [
                  for (final o in PrintOption.all)
                    DropdownMenuItem(
                        value: o, child: Text(o.label, style: const TextStyle(color: Colors.white))),
                ],
                onChanged: (o) => setState(() => _printOption = o ?? _printOption),
              ),
              const Text(
                'Naša slova (č ć ž š đ): "Kao slika" uvek radi. Za brži tekst odštampaj probnu stranicu i izaberi slovo reda koji je ispravan.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _printing ? null : _testPrint,
                  icon: const Icon(Icons.receipt, color: Colors.amberAccent),
                  label: Text(_printing ? 'Štampam…' : 'Probna štampa',
                      style: const TextStyle(color: Colors.amberAccent)),
                ),
              ),
              Row(
                children: [
                  if (_receiptLogoPath != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(4),
                        child: Image.file(File(_receiptLogoPath!),
                            width: 56,
                            height: 56,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image, color: Colors.black38)),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _pickReceiptLogo,
                    icon: const Icon(Icons.image, color: Colors.amberAccent),
                    label: Text(_receiptLogoPath == null ? 'Logo firme na računu' : 'Promeni logo',
                        style: const TextStyle(color: Colors.amberAccent)),
                  ),
                  if (_receiptLogoPath != null)
                    IconButton(
                      tooltip: 'Bez logoa',
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => setState(() => _receiptLogoPath = null),
                    ),
                ],
              ),
              TextField(
                controller: _header,
                maxLines: 4,
                minLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Zaglavlje računa (naziv, telefon…)',
                  labelStyle: TextStyle(color: Colors.white60),
                  helperText: 'Svaki red posebno. Na dnu računa uvek piše da nije fiskalni.',
                  helperStyle: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
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
