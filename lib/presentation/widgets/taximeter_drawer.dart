import 'package:flutter/material.dart';

class TaximeterDrawer extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                    child: const Icon(Icons.local_taxi, color: Colors.amberAccent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TAKSIMETAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Balkan Pro Edition',
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
              title: const Text('Istorija vožnji', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                onHistoryTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.white70),
              title: const Text('Izveštaji', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                onReportsTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.white70),
              title: const Text('Tarife', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                onTariffsTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune, color: Colors.white70),
              title: const Text('Podešavanja', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                onSettingsTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.battery_charging_full, color: Colors.white70),
              title: const Text('Optimizacija baterije', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Uputstvo za rad u pozadini', style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _showBatteryDialog(context);
              },
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pravna napomena:',
                    style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ova aplikacija je pomoćni alat za internu evidenciju i procenu troškova, a ne overeni službeni taksimetar.',
                    style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBatteryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Rad u pozadini bez prekida', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Za neprekidan rad kada je ekran zaključan:\n\n'
          '1. Isključite "Battery Optimization" za ovu aplikaciju.\n'
          '2. Dozvolite "Autostart" / rad u pozadini (posebno za Xiaomi, Huawei i Samsung uređaje).\n'
          '3. Zaključajte aplikaciju u listi nedavnih aplikacija.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('RAZUMEM', style: TextStyle(color: Colors.amberAccent)),
          ),
        ],
      ),
    );
  }
}