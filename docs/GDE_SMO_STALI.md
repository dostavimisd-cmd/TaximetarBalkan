# Gde smo stali — Taksimetar Balkan

Stanje na dan 25.10.2026. Poslednji komit `04bf058`, tag `v1.0.0`.
`flutter analyze`: bez problema. `flutter test`: 241 test prolazi.

## Ukratko
- **Verzija 1.0.0 (versionCode 1) je objavljena na Google Play** pod nazivom „Taksimetar Balkan“, paket `rs.taksimetar.balkan`.
  Link: https://play.google.com/store/apps/details?id=rs.taksimetar.balkan
- **Sajt:** https://taximetarbalkan.web.app (politika privatnosti: `/privacy`). Izvor je folder `site/`, objava: `firebase deploy --only hosting` (Firebase projekat `taximetarbalkan`, nalog `branislavsimulj@gmail.com`).
- **GitHub:** https://github.com/dostavimisd-cmd/TaximetarBalkan (privatan). Tag `v1.0.0` postoji, GitHub „Release“ stranica nije pravljena (nije obavezna).
- **Play nalog:** organizacija „DostaviMi+ Team“ (bez obaveze 12 testera). Kontakt: dostavimisd@gmail.com, 066 355 445 (WhatsApp i Viber).

## Šta aplikacija radi (v1.0.0)
Taksimetar preko GPS-a (start, km, čekanje, minimalna cena, pauza), tarife i praznici koje unosi vozač, fiksne relacije (pretraga i uvoz cenovnika), mapa sa pretragom adrese i procenom cene, rezime vožnje sa mapom rute, izveštaji (dan, nedelja, mesec, smena), štampa računa na Bluetooth štampač od 58 mm, srpski i engleski. Nema ugrađenih cena ni tarifa; sveža instalacija je prazna.

## Provereno na uređajima
- **Samsung S23 Ultra (SM-S918B):** obračun, pretraga adrese, štampa.
- **Honor NTH-NX9 (Android 13):** štampa računa (popravljen presečen kraj računa pauzom pre `disconnect`), meni, „O aplikaciji“, uputstvo za bateriju, engleski ekrani, 10+ minuta vožnje sa zaključanim ekranom radi.
- **iPad (jailbreak, iOS 15.5):** nepotpisan IPA radi preko GitHub Actions, ali je prvi build javljao „servis ne odgovara“. Dodat `InProcessRideBridge` (iOS, bez servisa). **Rezultat tog drugog builda nije potvrđen.**

## Važne odluke
- Tarifa se bira samo pri startu vožnje i važi do kraja (pravilo u Srbiji, `SPEC.md`).
- Prvo izdanje je besplatno. Premium (Play Billing) tek posle.
- Android se ne dira zbog iPad-a: iOS ima svoj bridge, Android koristi pravi foreground servis.
- iPad verzija je samo za ličnu upotrebu: bez štampe i bez rada na zaključanom ekranu.
- Mapa, pretraga i ruta koriste javne OSM servere (Nominatim, OSRM demo). Za više korisnika treba sopstveni server (`KNOWN_ISSUES.md`).

## Gde je šta
| Šta | Gde |
|---|---|
| Pravila projekta | `CLAUDE.md`, `SPEC.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, `KNOWN_ISSUES.md` |
| Poređenje plana i stanja | `docs/PLAN_VS_STANJE.md` |
| Plan testiranja vožnje | `docs/TEST_VOZNJA.md` |
| Uputstvo za Play, korak po korak | `docs/PLAY_KORAK_PO_KORAK.md` |
| Tekstovi prodavnice, Data safety, napomena verzije | `docs/PLAY_OBJAVA.md` |
| Politika privatnosti (nacrt) | `docs/politika_privatnosti.md` (živa verzija: `site/privacy.html`) |
| Grafika za Play | `docs/play/` (ikona, feature graphic, 4 snimka na srpskom) |
| Obfuskacioni simboli v1.0.0 | `docs/play/symbols-1.0.0/` (nisu u gitu; ne briši) |
| iOS build | `.github/workflows/ios-ipa.yml` |

## Ključ i izdanja
- **Upload ključ:** `D:\kljucevi\taksimetar-upload.jks`. Podaci za potpis su u `android/key.properties` (van gita). Bez ključa nema ažuriranja aplikacije, **napravi rezervnu kopiju na drugom mestu**. Lozinku ne beleži u projekat.
- **Novo izdanje:** u `pubspec.yaml` povećaj broj posle `+` (npr. `1.0.1+2`), pa:
  `flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info`
  Sačuvaj nove simbole iz `build/debug-info/` pod `docs/play/symbols-<verzija>/`.
- **APK za kolege** (van Play-a): `flutter build apk --release --obfuscate --split-debug-info=build/debug-info`, potpisan istim ključem.
- Debug-potpisan APK za test preko postojeće instalacije bez brisanja podataka: privremeno premesti `android/key.properties`, izgradi, vrati ga.

## Test na telefonu
- adb nije u PATH-u: `~/AppData/Local/Android/Sdk/platform-tools/adb`. U Git Bash obavezno `MSYS_NO_PATHCONV=1`.
- Honor se preko USB-a često odspaja; stabilnije je bežično (`adb tcpip 5555`, pa `adb connect <IP>:5555`, telefon i računar na istoj mreži).
- Pre svakog `input tap/text` proveri da je u prvom planu naša aplikacija (`topResumedActivity`).
- `pm clear` ne radi bez pitanja, briše podatke korisnika.

## Šta je otvoreno
1. **iPad:** potvrditi da novi build radi (START, cena, mapa, pretraga, relacije). Za novi IPA repo se mora privremeno prebaciti na Public (macOS runner na privatnom repou nije radio), pa vratiti na Private.
2. **Engleski snimci ekrana** za engleski deo Play prodavnice.
3. **GitHub Release** stranica za `v1.0.0` (opciono, napomena je u `docs/PLAY_OBJAVA.md`, odeljak 7).
4. **Prvi pravi povratni podaci od kolega** koji instaliraju sa Play-a.
5. U git radnom stablu su fajlovi koji nisu komitovani i nisu naši: `TaksimetarBalkan-ipa RADNI IPAD.zip`, `taksimetar.jfif`, izmena u `macos/Flutter/GeneratedPluginRegistrant.swift`.

## Sledeći razvoj (po dogovorenom redosledu)
1. **„Prvi km“ i doplate** u tarifi, jedna migracija baze (v12), diraju `FareCalculator`. Preporuka: Opus.
2. **Rezervna kopija podataka** (izvoz i uvoz): tarife, relacije, istorija, za prelazak na novi telefon.
3. **Dnevni troškovi** u mesečnom izveštaju.
4. **Premium** (Play Billing, jednokratno oko 1 €, radi i offline, vraćanje kupovine). Preporuka: Opus.
5. **Firmin paket** (kod firme, Firebase, tarife i relacije sa servera). Preporuka: Opus za plan, Sonnet za ekrane.
6. **Sopstveni OSM server** kad broj korisnika naraste.
7. Poslednje: automatski svetli/tamni režim, dokaz dostave za kurire, oznaka lažne lokacije.

Plan sa veličinom i rizikom svakog koraka je u `docs/PLAN_VS_STANJE.md`, odeljak F.

## Predlog modela
Sonnet za snimke ekrana, tekstove i sitnice. Opus za „prvi km“ i doplate, Premium i firmin paket (obračun, migracije, plaćanje).
