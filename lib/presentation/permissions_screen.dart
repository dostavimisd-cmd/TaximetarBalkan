import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  Future<void> _requestPermissions(BuildContext context) async {
    // 1. Lokacija
    var status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      status = await Geolocator.requestPermission();
    }
    
    // 2. Pozadinska lokacija i Notifikacije
    await [
      Permission.locationAlways,
      Permission.notification,
    ].request();

    // 3. Ignorisanje optimizacije baterije (ključno za Foreground service)
    await Permission.ignoreBatteryOptimizations.request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Priprema za rad')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Icon(Icons.location_on, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Da bi aplikacija radila dok je ekran ugašen, neophodno je odobriti sledeće:',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const Divider(height: 40),
          const ListTile(
            leading: Icon(Icons.my_location),
            title: Text('Uvek dozvoli lokaciju'),
            subtitle: Text('Izaberi "Allow all the time" u postavkama.'),
          ),
          const ListTile(
            leading: Icon(Icons.battery_alert),
            title: Text('Štednja baterije'),
            subtitle: Text('Isključi restrikcije za ovu aplikaciju (posebno važno za Xiaomi, Huawei, Samsung uređaje).'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _requestPermissions(context),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Odobri Dozvole', style: TextStyle(fontSize: 18)),
            ),
          )
        ],
      ),
    );
  }
}