import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/fixed_route.dart';
import '../providers/tariffs_provider.dart';

/// Fiksne relacije (npr. grad → aerodrom) sa cenama koje unosi korisnik.
class FixedRoutesScreen extends ConsumerWidget {
  const FixedRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(fixedRoutesProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('Fiksne relacije')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amberAccent,
        onPressed: () => showFixedRouteEditor(context),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: routes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Greška: $e', style: const TextStyle(color: Colors.redAccent))),
        data: (list) => list.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nema relacija. Dodaj relacije koje voziš po fiksnoj ceni (npr. aerodrom).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            : ListView(
                children: [
                  for (final r in list)
                    ListTile(
                      title: Text(r.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(r.describe(),
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      onTap: () => showFixedRouteEditor(context, existing: r),
                    ),
                ],
              ),
      ),
    );
  }
}

Future<void> showFixedRouteEditor(BuildContext context, {FixedRoute? existing}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _FixedRouteDialog(existing: existing),
  );
}

class _FixedRouteDialog extends ConsumerStatefulWidget {
  final FixedRoute? existing;
  const _FixedRouteDialog({this.existing});

  @override
  ConsumerState<_FixedRouteDialog> createState() => _FixedRouteDialogState();
}

class _FixedRouteDialogState extends ConsumerState<_FixedRouteDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _from = TextEditingController(text: widget.existing?.fromLabel ?? '');
  late final _to = TextEditingController(text: widget.existing?.toLabel ?? '');
  late final _price =
      TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.price}');
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _from, _to, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final price = int.tryParse(_price.text.trim());
    if (price == null) {
      setState(() => _error = 'Unesi cenu celim brojem.');
      return;
    }
    final route = FixedRoute(
      id: widget.existing?.id ?? 0,
      name: _name.text.trim(),
      fromLabel: _from.text.trim(),
      toLabel: _to.text.trim(),
      price: price,
    );
    final error = route.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    await ref.read(fixedRoutesProvider.notifier).save(route);
    if (mounted) Navigator.pop(context);
  }

  Widget _field(String label, TextEditingController c, {bool number = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : const [],
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white54),
            isDense: true,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(widget.existing == null ? 'Nova relacija' : 'Izmena relacije',
          style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field('Naziv (npr. Aerodrom)', _name),
            _field('Od (opciono)', _from),
            _field('Do (opciono)', _to),
            _field('Fiksna cena (din)', _price, number: true),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              await ref.read(fixedRoutesProvider.notifier).remove(widget.existing!.id);
              if (context.mounted) Navigator.pop(context);
            },
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
