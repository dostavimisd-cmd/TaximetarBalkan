import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/tr.dart';

class TaximeterDrawer extends ConsumerWidget {
  final VoidCallback onTariffsTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onReportsTap;
  final VoidCallback onSettingsTap;

  const TaximeterDrawer({
    super.key,
    required this.onTariffsTap,
    required this.onHistoryTap,
    required this.onReportsTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return Drawer(
      backgroundColor: const Color(0xFF121212),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_taxi,
                      color: Colors.amberAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('TAKSIMETAR'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        t('Balkan Pro Edition'),
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white70),
              title: Text(
                t('Istorija vožnji'),
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                onHistoryTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.white70),
              title: Text(
                t('Izveštaji'),
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                onReportsTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.white70),
              title: Text(
                t('Tarife'),
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                onTariffsTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune, color: Colors.white70),
              title: Text(
                t('Podešavanja'),
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                onSettingsTap();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.battery_charging_full,
                color: Colors.white70,
              ),
              title: Text(
                t('Optimizacija baterije'),
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                t('Uputstvo za rad u pozadini'),
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(context);
                _showBatteryDialog(context, t);
              },
            ),
            const Spacer(),
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Pravna napomena:'),
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    t('Ova aplikacija je pomoćni alat za internu evidenciju i procenu troškova, a ne overeni službeni taksimetar.'),
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      height: 1.3,
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

  void _showBatteryDialog(BuildContext context, Tr t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          t('Rad u pozadini bez prekida'),
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          t('Za neprekidan rad kada je ekran zaključan:\n\n1. Isključite "Battery Optimization" za ovu aplikaciju.\n2. Dozvolite "Autostart" / rad u pozadini (posebno za Xiaomi, Huawei i Samsung uređaje).\n3. Zaključajte aplikaciju u listi nedavnih aplikacija.'),
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              t('RAZUMEM'),
              style: TextStyle(color: Colors.amberAccent),
            ),
          ),
        ],
      ),
    );
  }
}
