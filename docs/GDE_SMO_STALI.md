# Gde smo stali — Taksimetar Balkan

Stanje na dan 04.11.2026. Verzija **1.1.0** (versionCode 2), tag `v1.1.0`, sve je na GitHub-u.
`flutter analyze`: bez problema. `flutter test`: 282 testa prolaze.

## Ukratko
- **Na Google Play je 1.0.0.** Ažuriranje 1.1.0 je spremno, otprema ga vlasnik (vidi „Šta je otvoreno”).
  Link: https://play.google.com/store/apps/details?id=rs.taksimetar.balkan
- **iPad 1.1.0** je napravljen preko GitHub Actions (artifact `TaksimetarBalkan-ipa-1.1.0`, čuva se 14 dana).
- **Sajt:** https://taximetarbalkan.web.app (politika privatnosti: `/privacy`). Izvor je folder `site/`, objava: `firebase deploy --only hosting`.
- **GitHub:** https://github.com/dostavimisd-cmd/TaximetarBalkan (privatan).
- **Play nalog:** organizacija „DostaviMi+ Team”. Kontakt: dostavimisd@gmail.com, 066 355 445 (WhatsApp i Viber).
- **Aplikacija ostaje besplatna** dok ne naraste broj korisnika (premium odložen).

## Novo u 1.1.0 (u odnosu na 1.0.0 sa Play-a)
| Šta | Provereno na telefonu |
|---|---|
| Vibracija na START, PAUZA, NASTAVI, ZAVRŠI (prava vibracija telefona, isključuje se u Podešavanjima) | da, Samsung |
| Dugmad PAUZA/NASTAVI i ZAVRŠI u obaveštenju (Android) | **ne** (zaključan ekran) |
| Automatska štampa računa na kraju vožnje (opcija) | **ne** |
| Rezervna kopija: izvoz u JSON, vraćanje, poništavanje vraćanja | **ne** |
| Izveštaj u PDF (naša slova) i CSV za Excel | **ne** |
| Prvi km u tarifi (prazno = kao ostali, 0 = u startu, > 0 = svoja cena) | unos da, obračun testovima |
| Doplate: spisak u Podešavanjima, dugme „+” u vožnji, idu posle minimalne cene | da, Samsung |
| Pretraga adrese dok se kuca, latinicom, najbliže prvo (Photon, rezerva Nominatim) | da, Samsung |
| Mapa: tamna pozadina pri učitavanju, ponovno učitavanje praznih pločica, popravke zuma i lokacije | delimično (prava vožnja nije rađena) |
| Pomoćnik za kalibraciju u rezimeu vožnje („Uskladi km sa zvaničnim taksimetrom”, vožnje od 1 km) | **ne** (posle 1.1.0 build-a, ide u sledeće izdanje) |
| Meni 10% veća slova; krupniji natpis PAUZA | da |
| Popravke: „Servis ne odgovara” posle kraja vožnje (greška iz razvoja, nije bila na Play-u); čuvanje podešavanja više ne briše prihvaćenu napomenu | da |

## Važne odluke
- Tarifa se bira samo pri startu vožnje i važi do kraja (pravilo u Srbiji, `SPEC.md`).
- Prvi km i doplate: `SPEC.md`, odeljak „Prvi kilometar i doplate”.
- Android se ne dira zbog iPad-a: iOS ima svoj bridge (bez servisa, bez štampe, bez obaveštenja, slabija vibracija dodira).
- Mapa, pretraga i ruta koriste javne besplatne servere (OSM pločice, Photon, Nominatim, OSRM demo). Za više korisnika treba sopstveni server (`KNOWN_ISSUES.md`). Nazivi na pločicama mape su ćirilicom (takve su besplatne OSM pločice).
- Premium (F) se ne radi dok ne naraste broj korisnika (`docs/PLAN_PREMIUM.md`).

## Gde je šta
| Šta | Gde |
|---|---|
| Pravila projekta | `CLAUDE.md`, `SPEC.md`, `ARCHITECTURE.md`, `DATA_MODEL.md` (šema v12), `KNOWN_ISSUES.md` |
| Plan razvoja (faze A–F) i odluke vlasnika | `docs/PLAN_PREMIUM.md` |
| Uputstvo za Play i tekstovi, napomena verzije (1.1.0 i 1.0.0) | `docs/PLAY_KORAK_PO_KORAK.md`, `docs/PLAY_OBJAVA.md` (odeljak 7) |
| AAB 1.1.0 za Play | `docs/play/raw/TaksimetarBalkan-1.1.0.aab` (nije u gitu) |
| Obfuskacioni simboli | `docs/play/symbols-1.0.0/`, `docs/play/symbols-1.1.0/` (nisu u gitu; ne briši) |
| iOS build | `.github/workflows/ios-ipa.yml` (ime fajla nosi verziju iz `pubspec.yaml`) |

## Ključ i izdanja
- **Upload ključ:** `D:\kljucevi\taksimetar-upload.jks`. Podaci za potpis su u `android/key.properties` (van gita). **Napravi rezervnu kopiju ključa na drugom mestu.** Lozinku ne beleži u projekat.
- **Novo izdanje:** u `pubspec.yaml` povećaj verziju i broj posle `+` (sledeće: `1.1.1+3` ili `1.2.0+3`), pa:
  `flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info`
  Sačuvaj simbole iz `build/debug-info/` pod `docs/play/symbols-<verzija>/`.
- **Probna kopija na telefonu koji ima Play verziju:** `TAKSI_PROBA=1 flutter build apk --release` daje paket `rs.taksimetar.balkan.proba` („Taksimetar PROBA”), koji stoji pored prave aplikacije i ne dira njene podatke.
- **GPS dnevnik za dijagnostiku (samo probna kopija):** `TAKSI_PROBA=1 flutter build apk --release --dart-define=GPS_TRACE=true`. Svaka GPS tačka i odluka obračuna idu u `/sdcard/Android/data/rs.taksimetar.balkan.proba/files/gps_trace_*.csv` (preuzimanje: `adb pull`). Play build ga nema.
- **iPad:** repo privremeno na Public → Actions → „iOS IPA” → Run workflow → artifact → repo nazad na Private.

## Test na telefonu
- adb: `~/AppData/Local/Android/Sdk/platform-tools/adb`, u Git Bash uz `MSYS_NO_PATHCONV=1`. Samsung se preko USB-a ponekad odspoji.
- Pre svakog `input tap/text` proveri da je u prvom planu naša aplikacija (`topResumedActivity`).
- `pm clear` ne radi bez pitanja.

## Šta je otvoreno (vlasnik)
1. **Pre otpreme 1.1.0** probaj na probnoj kopiji: dugmad u obaveštenju sa zaključanim ekranom, rezervnu kopiju (sačuvaj → vrati), PDF i CSV izveštaj, pravu vožnju sa mapom.
2. **Otpremi 1.1.0 na Play:** Produkcija → Novo izdanje → AAB iz `docs/play/raw/` → napomena iz `docs/PLAY_OBJAVA.md` → pregled.
3. **iPad 1.1.0:** instaliraj i javi kako rade doplate, pretraga i mapa. Proveri da je repo vraćen na Private.
4. Povratne informacije kolega sa Play-a.
5. Ako se loše iscrtavanje mape vrati: snimak ekrana i opis (kvadrati, zamrznuto, pogrešno mesto).
6. Fajlovi u git stablu koji nisu naši (ne komituju se): `TaksimetarBalkan-ipa RADNI IPAD.zip`, `taksimetar.jfif`, `devtools_options.yaml`, izmena u `macos/Flutter/GeneratedPluginRegistrant.swift`.

## Sledeći razvoj (predlog redosleda)
1. **Sledeće izdanje (1.1.1 ili 1.2.0):** pomoćnik za kalibraciju (C2, gotov u kodu) + popravke po utiscima kolega.
2. **D1. Vodič pri prvom pokretanju** (tarifa, relacije, štampač, baterija). Sonnet.
3. **D2. Raspored za držač u kolima** (horizontalni ekran). Sonnet.
4. **Sitno:** GitHub Actions na novije verzije (upozorenje o Node.js 20); engleski snimci ekrana za Play.
5. **Kasnije, kad naraste broj korisnika:** premium, sopstveni server mape, više jezika (HR, BS, MK…), firmin paket.

## Predlog modela
Sonnet za D1, D2, tekstove, snimke i sitnice. Opus za sve što dira obračun, bazu, servis vožnje ili plaćanje.
