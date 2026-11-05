import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/navigation_service.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/navigation.dart';
import '../../domain/place_search.dart';
import '../l10n/tr.dart';
import '../providers/settings_provider.dart';
import '../services/device_service.dart';

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

  /// Jezik prepoznavanja govora prema jeziku aplikacije (oznake, ne tekst).
  static const _voiceLanguages = {true: 'en-US', false: 'sr-RS'};

  /// Pauza u kucanju posle koje ide upit (ne šalje se svako slovo).
  static const _typingPause = Duration(milliseconds: 450);

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  /// Glasovni unos koji je podešen na telefonu; tekst ide u polje i traži se.
  Future<void> _voice() async {
    try {
      final text = await DeviceService.voiceInput(language: _voiceLanguages[t.english]!);
      if (!mounted || text == null || text.trim().isEmpty) return;
      _query.text = text.trim();
      _query.selection = TextSelection.collapsed(offset: _query.text.length);
      await _search();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = t('Glasovni unos nije dostupan; koristi mikrofon na tastaturi.'),
        );
      }
    }
  }

  /// Zvezdica: dodaje ili uklanja adresu iz omiljenih (čuva se odmah).
  Future<void> _toggleFavorite(Place p) => ref
      .read(appSettingsProvider.notifier)
      .change((s) {
        final list = List.of(s.favorites);
        final i = list.indexWhere((f) => f.sameAs(p));
        if (i >= 0) {
          list.removeAt(i);
        } else if (list.length < AppSettings.maxFavorites) {
          list.add(Place(label: p.label, lat: p.lat, lon: p.lon));
        }
        return s.copyWith(favorites: list);
      });

  Widget _placeTile(Place p, {required bool favorite}) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      favorite ? Icons.star : Icons.place,
      color: Colors.amberAccent,
    ),
    title: Text(
      p.label, // adresa iz OSM-a ili od vozača: ne prevodi se
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white, fontSize: 13),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (p.distanceMeters != null)
          Text(
            PlaceSearch.formatDistance(p.distanceMeters!),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        IconButton(
          tooltip: favorite ? t('Ukloni iz omiljenih') : t('Dodaj u omiljene'),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            favorite ? Icons.star : Icons.star_border,
            color: favorite ? Colors.amberAccent : Colors.white38,
            size: 20,
          ),
          onPressed: () => _toggleFavorite(p),
        ),
      ],
    ),
    onTap: () => Navigator.pop(context, p),
  );

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
    final favorites = ref.watch(appSettingsProvider).value?.favorites ?? const [];
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
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: t('Glasovni unos'),
                      icon: const Icon(Icons.mic, color: Colors.white70),
                      onPressed: _loading ? null : _voice,
                    ),
                    IconButton(
                      tooltip: t('Traži'),
                      icon: const Icon(Icons.search, color: Colors.amberAccent),
                      onPressed: _loading ? null : _search,
                    ),
                  ],
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
                  // Prazno polje: omiljene adrese (padajući spisak)
                  if (_query.text.trim().length < 3 && favorites.isNotEmpty) ...[
                    Text(
                      t('Omiljene adrese'),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    for (final p in favorites) _placeTile(p, favorite: true),
                  ],
                  for (final p in _results)
                    _placeTile(
                      p,
                      favorite: favorites.any((f) => f.sameAs(p)),
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
