import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/navigation_service.dart';
import '../../domain/models/navigation.dart';
import '../../domain/place_search.dart';
import '../l10n/tr.dart';

/// Pretraga adrese sa predlozima dok se kuca (upit ide kad se zastane sa
/// kucanjem), najbliži vozaču prvi.
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
  Timer? _debounce;
  // redni broj upita: zakasneli odgovor starijeg upita se odbacuje
  int _seq = 0;

  /// Pauza u kucanju posle koje ide upit (ne šalje se svako slovo).
  static const _typingPause = Duration(milliseconds: 450);

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 3) {
      _seq++;
      setState(() {
        _results = const [];
        _loading = false;
        _message = null;
      });
      return;
    }
    _debounce = Timer(_typingPause, _search);
  }

  Future<void> _search() async {
    _debounce?.cancel();
    if (_query.text.trim().length < 3) {
      setState(() => _message = t('Unesi bar 3 slova adrese.'));
      return;
    }
    final seq = ++_seq;
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
      if (!mounted || seq != _seq) return;
      setState(() {
        _results = r;
        _message = r.isEmpty
            ? t('Ništa nije pronađeno. Probaj sa nazivom grada.')
            : null;
      });
    } catch (e) {
      if (mounted && seq == _seq) {
        setState(() => _message = t('Pretraga nije uspela (internet?): {0}', [e]));
      }
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(t('Kuda se vozi?'), style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
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
                      trailing: p.distanceMeters == null
                          ? null
                          : Text(
                              PlaceSearch.formatDistance(p.distanceMeters!),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
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
          child: Text(t('ZATVORI'), style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}
