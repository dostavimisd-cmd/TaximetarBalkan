import 'package:flutter/material.dart';

class TariffOption {
  final int id;
  final String name;
  final int startPrice;
  final int pricePerKm;
  final int waitingPricePerMin;
  final int minPrice;

  const TariffOption({
    required this.id,
    required this.name,
    required this.startPrice,
    required this.pricePerKm,
    required this.waitingPricePerMin,
    required this.minPrice,
  });
}

class TariffSelectionSheet extends StatelessWidget {
  final int currentTariffId;
  final Function(TariffOption selected) onTariffSelected;

  const TariffSelectionSheet({
    super.key,
    required this.currentTariffId,
    required this.onTariffSelected,
  });

  static const List<TariffOption> predefinedTariffs = [
    TariffOption(
      id: 1,
      name: 'Tarifa 1 (Gradska / Dnevna)',
      startPrice: 250,
      pricePerKm: 80,
      waitingPricePerMin: 15,
      minPrice: 300,
    ),
    TariffOption(
      id: 2,
      name: 'Tarifa 2 (Noćna / Nedelja / Praznici)',
      startPrice: 300,
      pricePerKm: 100,
      waitingPricePerMin: 20,
      minPrice: 350,
    ),
    TariffOption(
      id: 3,
      name: 'Tarifa 3 (Van grada)',
      startPrice: 350,
      pricePerKm: 120,
      waitingPricePerMin: 20,
      minPrice: 400,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'IZBOR TARIFE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...predefinedTariffs.map((t) {
            final isSelected = t.id == currentTariffId;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2A2A2A) : const Color(0xFF141414),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? Colors.amberAccent : Colors.white10,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: ListTile(
                title: Text(
                  t.name,
                  style: TextStyle(
                    color: isSelected ? Colors.amberAccent : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Start: ${t.startPrice} | Km: ${t.pricePerKm} | Čekanje/min: ${t.waitingPricePerMin}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.amberAccent)
                    : null,
                onTap: () {
                  onTariffSelected(t);
                  Navigator.pop(context);
                },
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}