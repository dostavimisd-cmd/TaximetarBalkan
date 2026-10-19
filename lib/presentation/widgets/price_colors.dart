import 'package:flutter/material.dart';

/// Jasne, kontrastne boje cene na crnoj pozadini (kao LED taksimetri).
const Map<String, Color> priceColorValues = {
  'bela': Colors.white,
  'crvena': Color(0xFFFF1744),
  'zelena': Color(0xFF00E676),
  'plava': Color(0xFF2979FF),
  'zuta': Color(0xFFFFD600),
  'narandzasta': Color(0xFFFF9100),
};

const Map<String, String> priceColorLabels = {
  'bela': 'Bela',
  'crvena': 'Crvena',
  'zelena': 'Zelena',
  'plava': 'Plava',
  'zuta': 'Žuta',
  'narandzasta': 'Narandžasta',
};

Color priceColorOf(String key) => priceColorValues[key] ?? Colors.white;
