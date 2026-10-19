import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/fixed_route_import.dart';
import '../../domain/models/fixed_route.dart';
import '../providers/tariffs_provider.dart';
import '../l10n/tr.dart';

/// Fiksne relacije (npr. grad → aerodrom) sa cenama koje unosi korisnik:
/// dodavanje, izmena, brisanje, pretraga i uvoz više relacija odjednom.
class FixedRoutesScreen extends ConsumerStatefulWidget {
  const FixedRoutesScreen({super.key});

  @override
  ConsumerState<FixedRoutesScreen> createState() => _FixedRoutesScreenState();
}

class _FixedRoutesScreenState extends ConsumerState<FixedRoutesScreen> {
  Tr get t => ref.read(trProvider);
  String _query = '';

  Future<void> _confirmDeleteAll(int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          t('Obrisati sve relacije?'),
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          t('Biće obrisano {0} relacija. Istorija vožnji ostaje.', [count]),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t('ODUSTANI'),
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t('OBRIŠI SVE'),
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(fixedRoutesProvider.notifier).removeAll();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(trProvider); // prevod se menja sa jezikom
    final routes = ref.watch(fixedRoutesProvider);
    final all = routes.value ?? const <FixedRoute>[];
    final shown = FixedRouteImport.search(all, _query);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Fiksne relacije'),
        actions: [
          IconButton(
            tooltip: t('Uvezi spisak'),
            icon: const Icon(Icons.upload_file),
            onPressed: () => showFixedRouteImport(context),
          ),
          if (all.isNotEmpty)
            IconButton(
              tooltip: t('Obriši sve'),
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              onPressed: () => _confirmDeleteAll(all.length),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amberAccent,
        onPressed: () => showFixedRouteEditor(context),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: routes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            t('Greška: {0}', [e]),
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    t('Nema relacija. Dodaj ih ručno (+) ili uvezi ceo spisak odjednom (gore).'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                        ),
                        hintText: t('Pretraga ({0} relacija)', [list.length]),
                        hintStyle: const TextStyle(color: Colors.white38),
                        isDense: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final r in shown)
                          ListTile(
                            title: Text(
                              r.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              r.describe(english: t.english),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () =>
                                showFixedRouteEditor(context, existing: r),
                          ),
                        if (shown.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              t('Nema rezultata.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Uvoz: nalepi spisak (jedan red = jedna relacija), pregledaj, potvrdi.
Future<void> showFixedRouteImport(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ImportDialog(),
  );
}

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog();

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  Tr get t => ref.read(trProvider);
  final _text = TextEditingController();
  ImportResult _result = const ImportResult([], []);
  String? _message;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _text.text = data!.text!;
    setState(() => _result = FixedRouteImport.parse(_text.text));
  }

  /// Spisak iz tekstualnog fajla (UTF-8), npr. iz Preuzimanja ili sa Drive-a.
  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.pickFiles();
      if (picked.isEmpty) return;
      final bytes = await picked.first.xFile.readAsBytes();
      _text.text = utf8.decode(bytes, allowMalformed: true);
      setState(() {
        _message = null;
        _result = FixedRouteImport.parse(_text.text);
      });
    } catch (e) {
      setState(() => _message = t('Fajl nije mogao da se pročita: {0}', [e]));
    }
  }

  Future<void> _import() async {
    try {
      final r = await ref
          .read(fixedRoutesProvider.notifier)
          .importAll(_result.routes);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('Uvezeno: {0} novih, {1} izmenjenih (cena).', [r.added, r.updated]),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _message = t('Uvoz nije uspeo: {0}', [e]));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(trProvider); // prevod se menja sa jezikom
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        t('Uvoz fiksnih relacija'),
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('Jedan red = jedna relacija:\nNaziv ; Od ; Do ; Cena\nNaziv ; Cena\nNaziv - Cena'),
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _text,
                maxLines: 8,
                minLines: 5,
                onChanged: (v) =>
                    setState(() => _result = FixedRouteImport.parse(v)),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: t('Nalepi spisak ovde'),
                  hintStyle: TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(),
                ),
              ),
              TextButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open, color: Colors.amberAccent),
                label: Text(
                  t('Izaberi fajl (.txt)'),
                  style: TextStyle(color: Colors.amberAccent),
                ),
              ),
              TextButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.paste, color: Colors.amberAccent),
                label: Text(
                  t('Nalepi iz klipborda'),
                  style: TextStyle(color: Colors.amberAccent),
                ),
              ),
              if (_text.text.trim().isNotEmpty) ...[
                Text(
                  t('Prepoznato relacija: {0}', [_result.routes.length]),
                  style: const TextStyle(color: Colors.greenAccent),
                ),
                for (final r in _result.routes.take(5))
                  Text(
                    '• ${r.name} — ${r.price}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                if (_result.routes.length > 5)
                  Text(
                    t('… i još {0}', [_result.routes.length - 5]),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                if (_result.issues.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    t('Preskočeno redova: {0}', [_result.issues.length]),
                    style: const TextStyle(color: Colors.amberAccent),
                  ),
                  for (final i in _result.issues.take(5))
                    Text(
                      t('red {0}: {1}', [i.line, i.reason]),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                ],
              ],
              if (_message != null)
                Text(
                  t.message(_message!),
                  style: const TextStyle(color: Colors.redAccent),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            t('ODUSTANI'),
            style: TextStyle(color: Colors.white54),
          ),
        ),
        TextButton(
          onPressed: _result.routes.isEmpty ? null : _import,
          child: Text(
            t('UVEZI ({0})', [_result.routes.length]),
            style: const TextStyle(color: Colors.amberAccent),
          ),
        ),
      ],
    );
  }
}

Future<void> showFixedRouteEditor(
  BuildContext context, {
  FixedRoute? existing,
}) {
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
  Tr get t => ref.read(trProvider);
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _from = TextEditingController(
    text: widget.existing?.fromLabel ?? '',
  );
  late final _to = TextEditingController(text: widget.existing?.toLabel ?? '');
  late final _price = TextEditingController(
    text: widget.existing == null ? '' : '${widget.existing!.price}',
  );
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
      setState(() => _error = t('Unesi cenu celim brojem.'));
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

  Widget _field(String label, TextEditingController c, {bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          inputFormatters: number
              ? [FilteringTextInputFormatter.digitsOnly]
              : const [],
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
    ref.watch(trProvider); // prevod se menja sa jezikom
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        widget.existing == null ? 'Nova relacija' : t('Izmena relacije'),
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(t('Naziv (npr. Aerodrom)'), _name),
            _field(t('Od (opciono)'), _from),
            _field(t('Do (opciono)'), _to),
            _field(t('Fiksna cena (din)'), _price, number: true),
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
            onPressed: () async {
              await ref
                  .read(fixedRoutesProvider.notifier)
                  .remove(widget.existing!.id);
              if (context.mounted) Navigator.pop(context);
            },
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
