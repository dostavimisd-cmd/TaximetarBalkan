import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/navigation_service.dart';
import '../../domain/models/navigation.dart';
import '../l10n/tr.dart';

/// Pretraga adrese: upit ide tek na "Traži" (ne pri svakom slovu), jer javni
/// Nominatim dozvoljava najviše jedan upit u sekundi.
Future<Place?> showAddressSearch(
  BuildContext context,
  NavigationService service, {
  double? nearLat,
  double? nearLon,
}) {
  return showDialog<Place>(
    context: context,
    builder: (_) => _AddressSearchDialog(
      service: service,
      nearLat: nearLat,
      nearLon: nearLon,
    ),
  );
}

class _AddressSearchDialog extends ConsumerStatefulWidget {
  final NavigationService service;
  final double? nearLat;
  final double? nearLon;

  const _AddressSearchDialog({
    required this.service,
    this.nearLat,
    this.nearLon,
  });

  @override
  ConsumerState<_AddressSearchDialog> createState() => _AddressSearchDialogState();
}

class _AddressSearchDialogState extends ConsumerState<_AddressSearchDialog> {
  Tr get t => ref.read(trProvider);
  final _query = TextEditingController();
  List<Place> _results = const [];
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_query.text.trim().length < 3) {
      setState(() => _message = t('Unesi bar 3 slova adrese.'));
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final r = await widget.service.search(
        _query.text,
        nearLat: widget.nearLat,
        nearLon: widget.nearLon,
      );
      if (!mounted) return;
      setState(() {
        _results = r;
        _message = r.isEmpty
            ? t('Ništa nije pronađeno. Probaj sa nazivom grada.')
            : null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _message = t('Pretraga nije uspela (internet?): {0}', [e]));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Kuda se vozi?', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: t('Ulica i broj, grad'),
                hintStyle: const TextStyle(color: Colors.white38),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.amberAccent),
                  onPressed: _loading ? null : _search,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  t.message(_message!),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in _results)
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.place,
                        color: Colors.amberAccent,
                      ),
                      title: Text(
                        p.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, p),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t('Podaci © OpenStreetMap contributors'),
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ZATVORI', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}
