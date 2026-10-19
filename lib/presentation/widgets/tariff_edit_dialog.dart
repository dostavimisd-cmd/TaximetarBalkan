import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/tariff.dart';
import '../providers/tariffs_provider.dart';

/// Forma za unos/izmenu tarife. [existing] == null znači nova (prazna) tarifa.
/// Vraća id sačuvane tarife, -1 ako je obrisana, ili null ako je korisnik odustao.
Future<int?> showTariffEditor(BuildContext context, WidgetRef ref,
    {Tariff? existing}) {
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
  late final TextEditingController _name;
  late final TextEditingController _start;
  late final TextEditingController _perKm;
  late final TextEditingController _waiting;
  late final TextEditingController _min;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    String n(int? v) => v == null ? '' : '$v';
    _name = TextEditingController(text: t?.name ?? '');
    _start = TextEditingController(text: n(t?.startPrice));
    _perKm = TextEditingController(text: n(t?.pricePerKm));
    _waiting = TextEditingController(text: n(t?.waitingPricePerMin));
    _min = TextEditingController(text: n(t?.minPrice));
  }

  @override
  void dispose() {
    for (final c in [_name, _start, _perKm, _waiting, _min]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final values = [_start, _perKm, _waiting, _min]
        .map((c) => int.tryParse(c.text.trim()))
        .toList();
    if (values.any((v) => v == null)) {
      setState(() => _error = 'Popuni sva polja celim brojevima.');
      return;
    }
    final tariff = Tariff(
      id: widget.existing?.id ?? 0,
      name: _name.text.trim(),
      startPrice: values[0]!,
      pricePerKm: values[1]!,
      waitingPricePerMin: values[2]!,
      minPrice: values[3]!,
    );
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

  Widget _field(String label, TextEditingController c, {bool number = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters:
            number ? [FilteringTextInputFormatter.digitsOnly] : const [],
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
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(widget.existing == null ? 'Nova tarifa' : 'Izmena tarife',
          style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field('Naziv', _name, number: false),
            _field('Start (din)', _start),
            _field('Cena po km (din)', _perKm),
            _field('Čekanje po minutu (din)', _waiting),
            _field('Minimalna cena (din)', _min),
            if (_error != null)
              Text(_error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: _delete,
            child: const Text('OBRIŠI', style: TextStyle(color: Colors.redAccent)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
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
