import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/holiday.dart';
import '../../domain/models/tariff.dart';
import '../providers/tariffs_provider.dart';

/// Praznici koje korisnik unosi: tog dana (ceo dan) važi izabrana tarifa,
/// ako je uključen automatski izbor. Nema ugrađenih praznika (Pravilo 3).
class HolidaysScreen extends ConsumerWidget {
  const HolidaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holidays = ref.watch(holidaysProvider);
    final tariffs = ref.watch(tariffsProvider).value ?? const <Tariff>[];
    String tariffName(int id) =>
        tariffs.where((t) => t.id == id).firstOrNull?.name ??
        '(obrisana tarifa)';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Praznici'),
      ),
      floatingActionButton: tariffs.isEmpty
          ? null
          : FloatingActionButton(
              backgroundColor: Colors.amberAccent,
              onPressed: () => _edit(context, tariffs),
              child: const Icon(Icons.add, color: Colors.black),
            ),
      body: holidays.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Greška: $e',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
        data: (list) {
          if (tariffs.isEmpty) {
            return const Center(
              child: Text(
                'Prvo unesi bar jednu tarifu.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nema praznika. Dodaj datume kada primenjuješ posebnu tarifu (npr. praznična).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            );
          }
          return ListView(
            children: [
              for (final h in list)
                ListTile(
                  title: Text(
                    h.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${h.describe()} · ${tariffName(h.tariffId)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () => _edit(context, tariffs, existing: h),
                ),
            ],
          );
        },
      ),
    );
  }

  void _edit(BuildContext context, List<Tariff> tariffs, {Holiday? existing}) {
    showDialog<void>(
      context: context,
      builder: (_) => _HolidayDialog(tariffs: tariffs, existing: existing),
    );
  }
}

class _HolidayDialog extends ConsumerStatefulWidget {
  final List<Tariff> tariffs;
  final Holiday? existing;

  const _HolidayDialog({required this.tariffs, this.existing});

  @override
  ConsumerState<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends ConsumerState<_HolidayDialog> {
  late final TextEditingController _name;
  late DateTime _date;
  late bool _recurring;
  late int _tariffId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    final now = DateTime.now();
    _name = TextEditingController(text: h?.name ?? '');
    _date = h == null ? now : DateTime(h.year ?? now.year, h.month, h.day);
    _recurring = h?.recurring ?? true;
    _tariffId = h?.tariffId ?? widget.tariffs.first.id;
    if (!widget.tariffs.any((t) => t.id == _tariffId)) {
      _tariffId = widget.tariffs.first.id;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final holiday = Holiday(
      id: widget.existing?.id ?? 0,
      name: _name.text.trim(),
      month: _date.month,
      day: _date.day,
      year: _recurring ? null : _date.year,
      tariffId: _tariffId,
    );
    final error = holiday.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    await ref.read(holidaysProvider.notifier).save(holiday);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await ref.read(holidaysProvider.notifier).remove(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    String two(int v) => v.toString().padLeft(2, '0');
    final dateText = _recurring
        ? '${two(_date.day)}.${two(_date.month)}. svake godine'
        : '${two(_date.day)}.${two(_date.month)}.${_date.year}.';
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        widget.existing == null ? 'Novi praznik' : 'Izmena praznika',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Naziv',
                labelStyle: TextStyle(color: Colors.white54),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(dateText),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _recurring,
              onChanged: (v) => setState(() => _recurring = v ?? true),
              title: const Text(
                'Svake godine',
                style: TextStyle(color: Colors.white),
              ),
            ),
            DropdownButton<int>(
              value: _tariffId,
              isExpanded: true,
              dropdownColor: const Color(0xFF2A2A2A),
              items: [
                for (final t in widget.tariffs)
                  DropdownMenuItem(
                    value: t.id,
                    child: Text(
                      t.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _tariffId = v ?? _tariffId),
            ),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: _delete,
            child: const Text(
              'OBRIŠI',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'ODUSTANI',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: const Text(
            'SAČUVAJ',
            style: TextStyle(color: Colors.amberAccent),
          ),
        ),
      ],
    );
  }
}
