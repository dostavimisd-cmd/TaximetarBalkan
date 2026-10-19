import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/battery_guide.dart';
import '../l10n/tr.dart';
import '../services/device_service.dart';

/// Uputstvo za rad u pozadini: dugme otvara sistemski ekran baterije, a ispod
/// su koraci za proizvođača telefona (po Build.MANUFACTURER).
Future<void> showBatteryGuide(BuildContext context, WidgetRef ref) async {
  final manufacturer = await DeviceService.manufacturer();
  if (!context.mounted) return;
  final group = batteryGroupFor(manufacturer);
  final t = ref.read(trProvider);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        t('Rad u pozadini bez prekida'),
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t('Telefon može da ugasi taksimetar kad je ekran zaključan. Da se to ne desi, isključi ograničenja baterije za ovu aplikaciju.'),
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                if (!await DeviceService.openBatterySettings()) {
                  await openAppSettings();
                }
              },
              icon: const Icon(Icons.battery_charging_full, color: Colors.amberAccent),
              label: Text(
                t('OTVORI PODEŠAVANJA BATERIJE'),
                style: const TextStyle(color: Colors.amberAccent),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _title(group, t),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            for (final step in _steps(group, t))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $step',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t('RAZUMEM'), style: const TextStyle(color: Colors.amberAccent)),
        ),
      ],
    ),
  );
}

String _title(BatteryGroup g, Tr t) => switch (g) {
      BatteryGroup.samsung => t('Samsung'),
      BatteryGroup.xiaomi => t('Xiaomi / Redmi / POCO'),
      BatteryGroup.honor => t('Honor / Huawei'),
      BatteryGroup.motorola => t('Motorola'),
      BatteryGroup.lenovo => t('Lenovo'),
      BatteryGroup.other => t('Ostali telefoni'),
    };

List<String> _steps(BatteryGroup g, Tr t) => switch (g) {
      BatteryGroup.samsung => [
          t('Podešavanja → Aplikacije → Taksimetar Balkan → Baterija → izaberi "Neograničeno".'),
          t('Podešavanja → Baterija → Ograničenja pozadinske upotrebe → "Aplikacije koje nikad ne spavaju" → dodaj Taksimetar Balkan.'),
          t('Zaključaj aplikaciju u listi nedavnih aplikacija.'),
        ],
      BatteryGroup.xiaomi => [
          t('Podešavanja → Aplikacije → Upravljanje aplikacijama → Taksimetar Balkan → uključi "Autostart".'),
          t('Isto mesto → Ušteda baterije → izaberi "Bez ograničenja".'),
          t('Zaključaj aplikaciju u listi nedavnih aplikacija.'),
        ],
      BatteryGroup.honor => [
          t('Podešavanja → Baterija → Pokretanje aplikacija → Taksimetar Balkan → isključi "Upravljaj automatski".'),
          t('Uključi sva tri prekidača: automatsko pokretanje, pokretanje iz druge aplikacije i rad u pozadini.'),
          t('Zaključaj aplikaciju u listi nedavnih aplikacija.'),
        ],
      BatteryGroup.motorola => [
          t('Podešavanja → Baterija → Optimizacija baterije → Sve aplikacije → Taksimetar Balkan → "Ne optimizuj".'),
          t('Zaključaj aplikaciju u listi nedavnih aplikacija.'),
        ],
      BatteryGroup.lenovo => [
          t('Podešavanja → Baterija → Optimizacija baterije → Sve aplikacije → Taksimetar Balkan → "Ne optimizuj".'),
          t('Ako postoji "Upravljanje energijom" ili "Rad u pozadini", dozvoli radu aplikacije u pozadini.'),
          t('Zaključaj aplikaciju u listi nedavnih aplikacija.'),
        ],
      BatteryGroup.other => [
          t('Podešavanja → Aplikacije → Taksimetar Balkan → Baterija → izaberi "Bez ograničenja" (ili "Ne optimizuj").'),
          t('Ako telefon ima "Autostart" ili "Rad u pozadini", uključi ga za ovu aplikaciju.'),
          t('Zaključaj aplikaciju u listi nedavnih aplikacija.'),
        ],
    };
