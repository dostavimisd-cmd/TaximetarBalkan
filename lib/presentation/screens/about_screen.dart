import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../l10n/tr.dart';

/// Adresa politike privatnosti (Firebase Hosting, folder `site/`).
const String privacyPolicyUrl = 'https://taximetarbalkan.web.app/privacy';

/// Zvanični veb-sajt aplikacije (Firebase Hosting).
const String appWebsiteUrl = 'https://taximetarbalkan.web.app';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    const muted = TextStyle(color: Colors.white70, fontSize: 14, height: 1.4);
    const heading = TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(t('O aplikaciji')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: Icon(Icons.local_taxi, color: Colors.amberAccent, size: 56)),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Taksimetar Balkan',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) => Center(
              child: Text(
                snap.hasData
                    ? t('Verzija {0} ({1})', [snap.data!.version, snap.data!.buildNumber])
                    : '',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(t('Pravna napomena:'), style: heading),
          const SizedBox(height: 6),
          Text(
            t('Pomoćni program za evidenciju vožnji. Nije overeni taksimetar niti fiskalni uređaj.'),
            style: muted,
          ),
          const SizedBox(height: 24),
          Text(t('Politika privatnosti'), style: heading),
          const SizedBox(height: 6),
          SelectableText(
            privacyPolicyUrl.isEmpty
                ? t('Adresa će biti objavljena pre izlaska u prodavnicu.')
                : privacyPolicyUrl,
            style: muted,
          ),
          const SizedBox(height: 24),
          Text(t('Veb-sajt'), style: heading),
          const SizedBox(height: 6),
          const SelectableText(appWebsiteUrl, style: muted),
          const SizedBox(height: 24),
          Text(t('Kontakt'), style: heading),
          const SizedBox(height: 6),
          // Kontakt podaci korisnika se ne prevode.
          const SelectableText('dostavimisd@gmail.com', style: muted),
          const SizedBox(height: 2),
          Text(t('Telefon (WhatsApp i Viber):'), style: muted),
          const SelectableText('066 355 445', style: muted),
          const SizedBox(height: 24),
          Text(t('Podaci mape'), style: heading),
          const SizedBox(height: 6),
          Text(t('© OpenStreetMap contributors'), style: muted),
        ],
      ),
    );
  }
}
