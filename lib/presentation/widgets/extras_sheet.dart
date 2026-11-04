import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/extra_charge.dart';
import '../l10n/tr.dart';
import '../providers/settings_provider.dart';
import '../providers/taximeter_provider.dart';

/// Doplata tokom vožnje: stavke iz Podešavanja jednim dodirom, drugi iznos,
/// i spisak već dodatih (dodir na × uklanja).
Future<void> showExtrasSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1E1E1E),
    isScrollControlled: true,
    builder: (_) => const _ExtrasSheet(),
  );
}

class _ExtrasSheet extends ConsumerWidget {
  const _ExtrasSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final state = ref.watch(taximeterProvider);
    final catalog = ref.watch(appSettingsProvider).value?.extras ?? const [];
    final notifier = ref.read(taximeterProvider.notifier);
    final canAdd = state.extras.length < ExtraCharge.maxCount;

    Future<void> add(ExtraCharge e) async {
      Navigator.pop(context);
      await notifier.addExtra(e);
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          children: [
            Text(
              t('DOPLATA'),
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            if (catalog.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  t('Stalne doplate (npr. prtljag) unosiš u Podešavanjima.'),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in catalog)
                  ElevatedButton(
                    onPressed: canAdd ? () => add(e) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A2A2A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.amberAccent),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(e.name, style: const TextStyle(fontSize: 15)),
                        Text(
                          t('+{0} din', [e.amount]),
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: canAdd
                      ? () async {
                          final e = await showExtraChargeDialog(context, ref);
                          if (e != null && context.mounted) await add(e);
                        }
                      : null,
                  icon: const Icon(Icons.edit, color: Colors.white70),
                  label: Text(
                    t('Drugi iznos'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(120, 56),
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ],
            ),
            if (state.extras.isNotEmpty) ...[
              const Divider(color: Colors.white12, height: 28),
              Text(
                t('Dodato u ovoj vožnji'),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              for (final e in state.extras)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    e.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    t('{0} din', [e.amount]),
                    style: const TextStyle(color: Colors.amberAccent),
                  ),
                  trailing: IconButton(
                    tooltip: t('Ukloni'),
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    onPressed: e.id == null
                        ? null
                        : () => notifier.removeExtra(e.id!),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Unos ili izmena jedne doplate (naziv + ceo iznos u dinarima).
/// Vraća null ako je korisnik odustao.
Future<ExtraCharge?> showExtraChargeDialog(
  BuildContext context,
  WidgetRef ref, {
  ExtraCharge? existing,
}) {
  return showDialog<ExtraCharge>(
    context: context,
    builder: (_) => _ExtraChargeDialog(existing: existing),
  );
}

class _ExtraChargeDialog extends ConsumerStatefulWidget {
  final ExtraCharge? existing;
  const _ExtraChargeDialog({this.existing});

  @override
  ConsumerState<_ExtraChargeDialog> createState() => _ExtraChargeDialogState();
}

class _ExtraChargeDialogState extends ConsumerState<_ExtraChargeDialog> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(
      text: e?.name ?? ref.read(trProvider)('Doplata'),
    );
    _amount = TextEditingController(text: e == null ? '' : '${e.amount}');
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final e = ExtraCharge(
      name: _name.text.trim(),
      amount: int.tryParse(_amount.text.trim()) ?? 0,
    );
    final error = e.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, e);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    InputDecoration deco(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      isDense: true,
    );
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        t('Doplata'),
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            maxLength: ExtraCharge.maxNameLength,
            style: const TextStyle(color: Colors.white),
            decoration: deco(t('Naziv')),
          ),
          TextField(
            controller: _amount,
            autofocus: widget.existing == null,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white),
            decoration: deco(t('Iznos (din)')),
            onSubmitted: (_) => _save(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                t.message(_error!),
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            t('ODUSTANI'),
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: Text(
            t('SAČUVAJ'),
            style: const TextStyle(color: Colors.amberAccent),
          ),
        ),
      ],
    );
  }
}
