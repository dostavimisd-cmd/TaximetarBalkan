import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/taximeter_screen.dart';
import 'presentation/services/ride_service_controller.dart';

void main() async {
  // Obavezno pre bilo kakvog poziva asinhronog koda
  WidgetsFlutterBinding.ensureInitialized();

  // Inicijalizacija porta po Klodovom pravilu (pre runApp)
  RideServiceController.initCommunicationPort();

  runApp(
    const ProviderScope(
      child: TaksimetarApp(),
    ),
  );
}

class TaksimetarApp extends StatelessWidget {
  const TaksimetarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taksimetar Balkan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2E7D32),
          secondary: Colors.amberAccent,
          surface: Color(0xFF161616),
        ),
      ),
      home: const TaximeterScreen(),
    );
  }
}