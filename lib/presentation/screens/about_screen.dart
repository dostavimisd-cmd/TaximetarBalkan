import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/tr.dart';

/// Adresa politike privatnosti (Firebase Hosting, folder `site/`).
const String privacyPolicyUrl = 'https://taximetarbalkan.web.app/privacy';

/// Zvanični veb-sajt aplikacije (Firebase Hosting).
const String appWebsiteUrl = 'https://taximetarbalkan.web.app';

/// Kontakt (korisnički podaci — ne prevode se).
const String contactEmail = 'dostavimisd@gmail.com';
const String contactPhone = '066 355 445';

/// Telefon u međunarodnom formatu (bez vodeće nule) za WhatsApp/Viber linkove.
const String _phoneIntl = '38166355445';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, Tr t, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('Ne mogu da otvorim vezu.'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    const muted = TextStyle(color: Colors.white70, fontSize: 14, height: 1.4);
    const heading = TextStyle(color: Colors.white, fontWeight: FontWeight.bold);

    Widget link(IconData icon, String text, Uri uri) => InkWell(
      onTap: () => _open(context, t, uri),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.amberAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(t('O aplikaciji')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
            child: Icon(Icons.local_taxi, color: Colors.amberAccent, size: 56),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Taksimetar Balkan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) => Center(
              child: Text(
                snap.hasData
                    ? t('Verzija {0} ({1})', [
                        snap.data!.version,
                        snap.data!.buildNumber,
                      ])
                    : '',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(t('Pravna napomena:'), style: heading),
          const SizedBox(height: 6),
          Text(
            t(
              'Pomoćni program za evidenciju vožnji. Nije overeni taksimetar niti fiskalni uređaj.',
            ),
            style: muted,
          ),
          const SizedBox(height: 16),
          Text(t('Politika privatnosti'), style: heading),
          if (privacyPolicyUrl.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                t('Adresa će biti objavljena pre izlaska u prodavnicu.'),
                style: muted,
              ),
            )
          else
            link(Icons.privacy_tip, privacyPolicyUrl, Uri.parse(privacyPolicyUrl)),
          const SizedBox(height: 16),
          Text(t('Veb-sajt'), style: heading),
          link(Icons.language, appWebsiteUrl, Uri.parse(appWebsiteUrl)),
          const SizedBox(height: 16),
          Text(t('Kontakt'), style: heading),
          link(
            Icons.email,
            contactEmail,
            Uri(scheme: 'mailto', path: contactEmail),
          ),
          link(
            Icons.chat,
            'WhatsApp: $contactPhone',
            Uri.parse('https://wa.me/$_phoneIntl'),
          ),
          link(
            Icons.phone,
            'Viber: $contactPhone',
            Uri.parse('viber://chat?number=%2B$_phoneIntl'),
          ),
          const SizedBox(height: 24),
          Text(t('Podaci mape'), style: heading),
          const SizedBox(height: 6),
          Text(t('© OpenStreetMap contributors'), style: muted),
        ],
      ),
    );
  }
}
