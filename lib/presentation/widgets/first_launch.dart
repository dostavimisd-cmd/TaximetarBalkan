import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/tr.dart';
import '../providers/settings_provider.dart';
import 'battery_guide.dart';

/// Pri prvom pokretanju: napomena da aplikacija nije overeni taksimetar
/// (obavezno prihvatanje), a zatim jednom uputstvo za rad u pozadini.
Future<void> showFirstLaunch(BuildContext context, WidgetRef ref) async {
  final t = ref.read(trProvider);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          t('Pre nego što počneš'),
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Text(
            t('Pomoćni program za evidenciju vožnji. Nije overeni taksimetar niti fiskalni uređaj.'),
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              t('PRIHVATAM'),
              style: const TextStyle(color: Colors.amberAccent),
            ),
          ),
        ],
      ),
    ),
  );
  await ref.read(appSettingsProvider.notifier).change(
        (s) => s.copyWith(disclaimerAccepted: true),
      );
  if (!context.mounted) return;
  final settings = ref.read(appSettingsProvider).value;
  if (settings != null && !settings.batteryGuideShown) {
    await ref.read(appSettingsProvider.notifier).change(
          (s) => s.copyWith(batteryGuideShown: true),
        );
    if (context.mounted) await showBatteryGuide(context, ref);
  }
}
