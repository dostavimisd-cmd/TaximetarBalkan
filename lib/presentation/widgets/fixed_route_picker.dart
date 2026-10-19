import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/fixed_route_import.dart';
import '../../domain/models/fixed_route.dart';
import '../providers/tariffs_provider.dart';

/// Brza pretraga fiksnih relacija sa glavnog ekrana: kucaš deo naziva
/// (bez obzira na kvačice), tapneš relaciju i važi za sledeću vožnju.
Future<FixedRoute?> showFixedRoutePicker(
  BuildContext context, {
  int? selectedId,
}) {
  return showModalBottomSheet<FixedRoute>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _Picker(selectedId: selectedId),
  );
}

class _Picker extends ConsumerStatefulWidget {
  final int? selectedId;
  const _Picker({this.selectedId});

  @override
  ConsumerState<_Picker> createState() => _PickerState();
}

class _PickerState extends ConsumerState<_Picker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(fixedRoutesProvider).value ?? const <FixedRoute>[];
    final shown = FixedRouteImport.search(all, _query);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            const Text(
              'FIKSNE RELACIJE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.amberAccent),
                hintText: all.isEmpty
                    ? 'Nema relacija (Podešavanja → Fiksne relacije)'
                    : 'Pretraga (${all.length})',
                hintStyle: const TextStyle(color: Colors.white38),
                isDense: true,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (widget.selectedId != null)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.close, color: Colors.white54),
                      title: const Text(
                        'Bez fiksne relacije (taksimetar)',
                        style: TextStyle(color: Colors.white70),
                      ),
                      onTap: () => Navigator.pop(
                        context,
                        const FixedRoute(id: -1, name: '', price: 1),
                      ),
                    ),
                  for (final r in shown)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.route,
                        color: r.id == widget.selectedId
                            ? Colors.amberAccent
                            : Colors.white38,
                      ),
                      title: Text(
                        r.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        r.describe(),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, r),
                    ),
                  if (shown.isEmpty && all.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nema rezultata.',
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
