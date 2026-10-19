import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/currency_converter.dart';
import '../../domain/models/tariff.dart';
import '../../domain/models/tariff_schedule.dart';
import '../providers/tariffs_provider.dart';
import '../l10n/tr.dart';

/// Forma za unos/izmenu tarife. [existing] == null znači nova (prazna) tarifa.
/// Vraća id sačuvane tarife, -1 ako je obrisana, ili null ako je korisnik odustao.
Future<int?> showTariffEditor(
  BuildContext context,
  WidgetRef ref, {
  Tariff? existing,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _TariffEditDialog(existing: existing),
  );
}

class _TariffEditDialog extends ConsumerStatefulWidget {
  final Tariff? existing;
  const _TariffEditDialog({this.existing});

  @override
  ConsumerState<_TariffEditDialog> createState() => _TariffEditDialogState();
}

class _TariffEditDialogState extends ConsumerState<_TariffEditDialog> {
  Tr get t => ref.read(trProvider);
  late final TextEditingController _name;
  late final TextEditingController _start;
  late final TextEditingController _perKm;
  late final TextEditingController _waiting;
  late final TextEditingController _min;
  String? _error;

  // raspored za automatski izbor
  bool _scheduled = false;
  int _days = TariffSchedule.allDays;
  int _startMinute = 0;
  int _endMinute = 0;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    String n(int? v) => v == null ? '' : '$v';
    _name = TextEditingController(text: t?.name ?? '');
    _start = TextEditingController(text: n(t?.startPrice));
    _perKm = TextEditingController(text: n(t?.pricePerKm));
    _waiting = TextEditingController(
      text: t == null ? '' : CurrencyConverter.formatPara(t.waitingParaPerMin),
    );
    _min = TextEditingController(text: n(t?.minPrice));
    final s = t?.schedule;
    if (s != null) {
      _scheduled = true;
      _days = s.days;
      _startMinute = s.startMinute;
      _endMinute = s.endMinute;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _start, _perKm, _waiting, _min]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final values = [_start, _perKm, _waiting, _min].map((c) {
      // čekanje može sa decimalama (13.4 ili 13,4), ostalo su celi dinari
      return c == _waiting
          ? CurrencyConverter.parsePara(c.text)
          : int.tryParse(c.text.trim());
    }).toList();
    if (values.any((v) => v == null)) {
      setState(
        () => _error =
            t('Popuni sva polja. Čekanje može sa zarezom (npr. 13,4), ostalo celim brojevima.'),
      );
      return;
    }
    final tariff = Tariff(
      id: widget.existing?.id ?? 0,
      name: _name.text.trim(),
      startPrice: values[0]!,
      pricePerKm: values[1]!,
      waitingParaPerMin: values[2]!,
      minPrice: values[3]!,
      schedule: _scheduled
          ? TariffSchedule(
              days: _days,
              startMinute: _startMinute,
              endMinute: _endMinute,
            )
          : null,
    );
    if (_scheduled && _days == 0) {
      setState(
        () => _error = t('Izaberi bar jedan dan rasporeda ili isključi raspored.'),
      );
      return;
    }
    final error = tariff.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final id = await ref.read(tariffsProvider.notifier).save(tariff);
    if (mounted) Navigator.pop(context, id);
  }

  Future<void> _delete() async {
    await ref.read(tariffsProvider.notifier).remove(widget.existing!.id);
    if (mounted) Navigator.pop(context, -1);
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _startMinute : _endMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      final m = picked.hour * 60 + picked.minute;
      if (start) {
        _startMinute = m;
      } else {
        _endMinute = m;
      }
    });
  }

  Widget _scheduleSection() {
    final preview = TariffSchedule(
      days: _days,
      startMinute: _startMinute,
      endMinute: _endMinute,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _scheduled,
          onChanged: (v) => setState(() => _scheduled = v),
          title: Text(
            t('Raspored (automatski izbor)'),
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: Text(
            t('Važi kad je u podešavanjima uključen automatski izbor tarife.'),
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
        if (_scheduled) ...[
          Wrap(
            spacing: 4,
            children: [
              for (var i = 0; i < 7; i++)
                FilterChip(
                  label: Text(TariffSchedule.letters(english: t.english)[i]),
                  selected: _days & (1 << i) != 0,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (on) => setState(
                    () => _days = on ? _days | (1 << i) : _days & ~(1 << i),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => _pickTime(true),
                child: Text('od ${TariffSchedule.formatMinute(_startMinute)}'),
              ),
              TextButton(
                onPressed: () => _pickTime(false),
                child: Text('do ${TariffSchedule.formatMinute(_endMinute)}'),
              ),
            ],
          ),
          Text(
            '${preview.describe(english: t.english)}${_startMinute != _endMinute && _endMinute < _startMinute ? t(' (preko ponoći)') : ''}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    bool number = true,
    bool decimal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: decimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : (number ? TextInputType.number : TextInputType.text),
        inputFormatters: decimal
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
            : (number ? [FilteringTextInputFormatter.digitsOnly] : const []),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(trProvider); // prevod se menja sa jezikom
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        widget.existing == null ? t('Nova tarifa') : t('Izmena tarife'),
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(t('Naziv'), _name, number: false),
            _field(t('Start (din)'), _start),
            _field(t('Cena po km (din)'), _perKm),
            _field(
              t('Čekanje po minutu (din, npr. 13,4)'),
              _waiting,
              decimal: true,
            ),
            _field(t('Minimalna cena (din)'), _min),
            _scheduleSection(),
            if (_error != null)
              Text(
                t.message(_error!),
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: _delete,
            child: Text(
              t('OBRIŠI'),
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            t('ODUSTANI'),
            style: TextStyle(color: Colors.white54),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: Text(
            t('SAČUVAJ'),
            style: TextStyle(color: Colors.amberAccent),
          ),
        ),
      ],
    );
  }
}
