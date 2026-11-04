import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../domain/calibration.dart';
import '../../domain/currency_converter.dart';
import '../../domain/models/app_settings.dart';
import '../printing/receipt_printer.dart';
import '../providers/settings_provider.dart';
import '../widgets/battery_guide.dart';
import '../widgets/price_colors.dart';
import 'fixed_routes_screen.dart';
import 'holidays_screen.dart';
import '../l10n/tr.dart';

/// Podešavanja korisnika. Vrednosti važe od sledećeg starta vožnje; vožnja u
/// toku zadržava ono sa čim je počela (upisano je u `rides`).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Tr get t => ref.read(trProvider);
  final _speed = TextEditingController();
  final _calibration = TextEditingController();
  final _gps = TextEditingController();
  final _rate = TextEditingController();
  final _header = TextEditingController();
  String _language = 'sr';
  String _currency = 'RSD';
  bool _autoTariff = false;
  bool _showMap = true;
  bool _voice = false;
  bool _feedback = true;
  bool _autoPrint = false;
  int _refresh = 1;
  bool _keepOn = true;
  String _priceColor = 'bela';
  int _priceScale = 100;
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
    _rate.text = s.eurRateMilli == null
        ? ''
        : CurrencyConverter.formatRate(s.eurRateMilli!);
    _language = s.language;
    _currency = s.currency;
    _autoTariff = s.autoTariff;
    _showMap = s.showMap;
    _voice = s.voiceAnnounce;
    _feedback = s.buttonFeedback;
    _autoPrint = s.autoPrint;
    _refresh = s.priceRefreshSeconds;
    _keepOn = s.keepScreenOn;
    _priceColor = s.priceColor;
    _priceScale = s.priceScale;
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
    final rate = rateText.isEmpty
        ? null
        : CurrencyConverter.parseRateMilli(rateText);

    String? error;
    if (speed == null) error = t('Unesi brzinu za čekanje (ceo broj km/h).');
    if (calibration == null) {
      error ??= t('Kalibracija: procenat od -50 do 50, npr. 2,5 ili -1.');
    }
    if (gps == null) error ??= t('Unesi GPS tačnost (ceo broj metara).');
    if (rateText.isNotEmpty && rate == null) {
      error ??= t('Kurs: npr. 117,2 (najviše 3 decimale).');
    }
    if (_currency == 'EUR' && rate == null) {
      error ??= t('Za prikaz u EUR unesi kurs.');
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
      voiceAnnounce: _voice,
      buttonFeedback: _feedback,
      autoPrint: _autoPrint,
      priceRefreshSeconds: _refresh,
      keepScreenOn: _keepOn,
      priceColor: _priceColor,
      priceScale: _priceScale,
      backgroundLogoPath: _logoPath,
      printerMac: _printerMac,
      printerName: _printerName,
      printMode: _printOption.mode,
      printCodePage: _printOption.codePage == 0
          ? current.printCodePage
          : _printOption.codePage,
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
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );
    if (picked == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(picked.path).isEmpty
        ? '.png'
        : p.extension(picked.path);
    // novo ime svaki put, da se prikaz ne zadrži na staroj slici iz keša
    final target = p.join(
      dir.path,
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
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
          title: Text(
            t('Upareni uređaji'),
            style: TextStyle(color: Colors.white),
          ),
          children: [
            if (devices.isEmpty)
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  t('Nema uparenih uređaja. Upari štampač u Bluetooth podešavanjima telefona (PIN je obično 0000 ili 1234).'),
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            for (final d in devices)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, (d.macAdress, d.name)),
                child: Text(
                  '${d.name}\n${d.macAdress}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      );
      if (chosen != null) {
        setState(() {
          _printerMac = chosen.$1;
          _printerName = chosen.$2;
        });
        // Izbor se pamti odmah (ne tek na SAČUVAJ), da dugmad za štampu
        // postoje i ako se iz podešavanja izađe nazad.
        await ref
            .read(appSettingsProvider.notifier)
            .change(
              (s) => s.copyWith(printerMac: chosen.$1, printerName: chosen.$2),
            );
      }
    } catch (e) {
      setState(() => _error = t('Štampač: {0}', [e]));
    }
  }

  Future<void> _testPrint() async {
    final mac = _printerMac;
    if (mac == null) {
      setState(() => _error = t('Prvo izaberi štampač.'));
      return;
    }
    setState(() {
      _printing = true;
      _error = null;
    });
    try {
      await ref
          .read(receiptPrinterProvider)
          .send(mac, await ReceiptPrinter.testPageBytes());
    } catch (e) {
      if (mounted) setState(() => _error = t('Probna štampa nije uspela: {0}', [e]));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 22, 0, 6),
    child: Text(
      title,
      style: const TextStyle(
        color: Colors.amberAccent,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _number(
    String label,
    TextEditingController c, {
    String? helper,
    String allow = r'[0-9]',
    bool decimal = false,
    bool signed = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(
          decimal: decimal,
          signed: signed,
        ),
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

  Widget _choice(
    String label,
    List<String> options,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          SegmentedButton<String>(
            segments: [
              for (final o in options)
                ButtonSegment(value: o, label: Text(t(o).toUpperCase())),
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
    ref.watch(trProvider); // prevod se menja sa jezikom
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(t('Podešavanja')),
        actions: [
          TextButton(
            onPressed: settings.hasValue ? () => _save(settings.value!) : null,
            child: Text(
              t('SAČUVAJ'),
              style: TextStyle(color: Colors.amberAccent),
            ),
          ),
        ],
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            t('Greška: {0}', [e]),
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
        data: (s) {
          if (!_loaded) _fill(s);
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _section(t('OBRAČUN')),
              _number(
                t('Čekanje se računa ispod (km/h)'),
                _speed,
                helper:
                    t('Ceo broj {0}–{1}. Ispod ove brzine taksimetar računa čekanje umesto kilometara.', [AppSettings.minWaitingSpeedKmh, AppSettings.maxWaitingSpeedKmh]),
              ),
              _number(
                t('Kalibracija distance (%)'),
                _calibration,
                allow: r'[0-9.,+-]',
                decimal: true,
                signed: true,
                helper:
                    t('0 = bez korekcije; 2,5 = distanca +2,5%. Uskladi sa zvaničnim taksimetrom.'),
              ),
              _section(t('TARIFE')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _autoTariff,
                onChanged: (v) => setState(() => _autoTariff = v),
                title: Text(
                  t('Automatski izbor tarife pri startu'),
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  t('Prvo praznici, pa raspored tarife (dani i vreme). Tarifa se ne menja tokom vožnje.'),
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HolidaysScreen(),
                  ),
                ),
                icon: const Icon(Icons.event, color: Colors.amberAccent),
                label: Text(
                  t('Praznici'),
                  style: TextStyle(color: Colors.amberAccent),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FixedRoutesScreen(),
                  ),
                ),
                icon: const Icon(Icons.route, color: Colors.amberAccent),
                label: Text(
                  t('Fiksne relacije'),
                  style: TextStyle(color: Colors.amberAccent),
                ),
              ),
              _section(t('GPS')),
              _number(
                t('Najveća dozvoljena nepreciznost (m)'),
                _gps,
                helper:
                    t('Ceo broj {0}–{1}. Tačke sa lošijom procenom tačnosti se odbacuju. Manje = strože.', [AppSettings.minGpsAccuracyM, AppSettings.maxGpsAccuracyM]),
              ),
              _section(t('PRIKAZ')),
              _choice(
                t('Jezik'),
                AppSettings.languages,
                _language,
                (v) => _language = v,
              ),
              _choice(
                t('Valuta prikaza'),
                AppSettings.currencies,
                _currency,
                (v) => _currency = v,
              ),
              _number(
                t('Kurs: dinara za 1 EUR'),
                _rate,
                allow: r'[0-9.,]',
                decimal: true,
                helper: t('Samo za prikaz u EUR. Obračun je uvek u dinarima.'),
              ),
              _section(t('EKRAN')),
              Text(t('Boja cene'), style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in AppSettings.priceColors)
                    ChoiceChip(
                      label: Text(t(priceColorLabels[key]!)),
                      selected: _priceColor == key,
                      avatar: CircleAvatar(
                        backgroundColor: priceColorOf(key),
                        radius: 8,
                      ),
                      onSelected: (_) => setState(() => _priceColor = key),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                t('Veličina cene: {0} %', [_priceScale]),
                style: const TextStyle(color: Colors.white70),
              ),
              Slider(
                value: _priceScale.toDouble(),
                min: AppSettings.minPriceScale.toDouble(),
                max: AppSettings.maxPriceScale.toDouble(),
                divisions:
                    (AppSettings.maxPriceScale - AppSettings.minPriceScale) ~/
                    10,
                label: '$_priceScale %',
                onChanged: (v) => setState(() => _priceScale = v.round()),
              ),
              Container(
                color: Colors.black,
                alignment: Alignment.center,
                height: 110,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '1250',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: priceColorOf(_priceColor),
                      fontSize: 82 * _priceScale / 100,
                    ),
                  ),
                ),
              ),
              _choice(
                t('Osvežavanje cene (s)'),
                const ['1', '4', '6', '10'],
                '$_refresh',
                (v) => _refresh = int.parse(v),
              ),
              Text(
                t('1 = odmah. Duže osvežavanje samo usporava prikaz; obračun i konačna cena su isti.'),
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _keepOn,
                onChanged: (v) => setState(() => _keepOn = v),
                title: Text(
                  t('Ekran uvek uključen'),
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  t('Dok je aplikacija otvorena ekran se ne gasi, cena se stalno vidi (troši više baterije).'),
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              _section(t('GLAS')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _voice,
                onChanged: (v) => setState(() => _voice = v),
                title: Text(
                  t('Najavi cenu na kraju vožnje'),
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  t('Telefon izgovori ukupan iznos. Koristi sintetizator govora telefona.'),
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _feedback,
                onChanged: (v) => setState(() => _feedback = v),
                title: Text(
                  t('Vibracija i zvuk'),
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  t('Kratak signal kad vožnja počne, stane na pauzu, nastavi se ili završi.'),
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              _section(t('IZGLED')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _showMap,
                onChanged: (v) => setState(() => _showMap = v),
                title: Text(
                  t('Prikaži mapu'),
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  t('OpenStreetMap (besplatno). Podloge traže internet; obračun radi i bez mape.'),
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              _choice(
                t('Pozadina'),
                const ['crna', 'logo'],
                _logoPath == null ? 'crna' : 'logo',
                (v) {
                  if (v == 'crna') {
                    _logoPath = null;
                  } else if (_logoPath == null) {
                    _pickLogo();
                  }
                },
              ),
              if (_logoPath != null)
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_logoPath!),
                        width: 64,
                        height: 64,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _pickLogo,
                      child: Text(
                        t('Promeni sliku'),
                        style: TextStyle(color: Colors.amberAccent),
                      ),
                    ),
                  ],
                ),
              _section(t('ŠTAMPAČ RAČUNA')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.print, color: Colors.amberAccent),
                title: Text(
                  _printerName ?? t('Štampač nije izabran'),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _printerMac ?? t('Bluetooth, 58 mm (npr. PT-210)'),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                trailing: TextButton(
                  onPressed: _choosePrinter,
                  child: Text(
                    t('IZABERI'),
                    style: TextStyle(color: Colors.amberAccent),
                  ),
                ),
              ),
              DropdownButton<PrintOption>(
                value: _printOption,
                isExpanded: true,
                dropdownColor: const Color(0xFF2A2A2A),
                items: [
                  for (final o in PrintOption.all)
                    DropdownMenuItem(
                      value: o,
                      child: Text(
                        o.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
                onChanged: (o) =>
                    setState(() => _printOption = o ?? _printOption),
              ),
              Text(
                t('Naša slova (č ć ž š đ): "Kao slika" uvek radi. Za brži tekst odštampaj probnu stranicu i izaberi slovo reda koji je ispravan.'),
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _printing ? null : _testPrint,
                  icon: const Icon(Icons.receipt, color: Colors.amberAccent),
                  label: Text(
                    _printing ? t('Štampam…') : t('Probna štampa'),
                    style: const TextStyle(color: Colors.amberAccent),
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _autoPrint,
                onChanged: (v) => setState(() => _autoPrint = v),
                title: Text(
                  t('Štampaj račun na kraju vožnje'),
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _printerMac == null
                      ? t('Prvo izaberi štampač.')
                      : t('Račun se sam šalje na štampač kad završiš vožnju.'),
                  style: TextStyle(color: Colors.white38, fontSize: 11),
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
                        child: Image.file(
                          File(_receiptLogoPath!),
                          width: 56,
                          height: 56,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.broken_image,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _pickReceiptLogo,
                    icon: const Icon(Icons.image, color: Colors.amberAccent),
                    label: Text(
                      _receiptLogoPath == null
                          ? t('Logo firme na računu')
                          : t('Promeni logo'),
                      style: const TextStyle(color: Colors.amberAccent),
                    ),
                  ),
                  if (_receiptLogoPath != null)
                    IconButton(
                      tooltip: t('Bez logoa'),
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
                decoration: InputDecoration(
                  labelText: t('Zaglavlje računa (naziv, telefon…)'),
                  labelStyle: TextStyle(color: Colors.white60),
                  helperText:
                      t('Svaki red posebno. Na dnu računa uvek piše da nije fiskalni.'),
                  helperStyle: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              _section(t('RAD U POZADINI')),
              Text(
                t('Da taksimetar ne bi bio ugašen na zaključanom ekranu, isključi optimizaciju baterije za aplikaciju i dozvoli rad u pozadini.'),
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => showBatteryGuide(context, ref),
                icon: const Icon(
                  Icons.battery_charging_full,
                  color: Colors.amberAccent,
                ),
                label: Text(
                  t('Uputstvo za rad u pozadini'),
                  style: TextStyle(color: Colors.amberAccent),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    t.message(_error!),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                t('Pomoćni alat za evidenciju i procenu, nije overeni službeni taksimetar ni fiskalni uređaj.'),
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
