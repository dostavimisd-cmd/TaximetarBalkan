# Plan vs. stanje — Taksimetar Balkan

Revizija na dan 19.10.2026, commit `9b2a258`. Kod nije menjan; ovo je samo izveštaj.

**Provera koda**
- `flutter analyze` → **No issues found!**
- `flutter test` → **+239: All tests passed!** (29 test fajlova: domen, baza/migracije, engine, prevod)

**Oznake:** URAĐENO · BOLJE OD PLANA · DELIMIČNO · NEDOSTAJE · NIJE VIĐENO · PROVERITI NA UREĐAJU

Dozvole su proverene i u izvornom manifestu i u spojenom release manifestu
(`build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`).

---

## A) Tabela: plan → stanje

### Proizvod

| Stavka plana | Status | Gde u kodu | Komentar |
|---|---|---|---|
| Android, Flutter | URAĐENO | `pubspec.yaml`, `android/` | iOS je isključen (`ios: false` u ikoni i splash-u). |
| Srpski (latinica) + engleski | URAĐENO | `lib/presentation/l10n/tr.dart`, `en.dart`; test `test/presentation/translations_test.dart` | Test obara build ako neki tekst nema prevod ili je napisan mimo `t()`. Engleski ekrani posle `9b2a258`: PROVERITI NA UREĐAJU. |
| Disclaimer pri prvom pokretanju | NEDOSTAJE | — | Nema ekrana pri prvom pokretanju niti obaveznog prihvatanja. |
| Disclaimer u About / meniju | DELIMIČNO | `taximeter_drawer.dart:153`, `settings_screen.dart:706` | Postoji u meniju i podešavanjima, ali nema posebnog „O aplikaciji” ekrana (verzija, licence, politika privatnosti). |
| Disclaimer na računu | URAĐENO | `domain/printing/receipt.dart:84` („Pomoćni taksimetar”), uz „Ovo nije fiskalni račun” | Postoji i u rezimeu vožnje (`ride_summary_screen.dart:265`). |
| Disclaimer u opisu prodavnice | NEDOSTAJE | — | Opis prodavnice još ne postoji. |
| Premium ~1 € (Play Billing) | NEDOSTAJE | grep `billing\|premium\|purchase` = 0 | Nema paketa `in_app_purchase`. |
| Firmin paket (KOD FIRME, Firebase) | NEDOSTAJE | grep `firebase\|company` = 0 | Lokalno postoje logo i zaglavlje na računu (`receiptLogoPath`), ali bez preuzimanja sa servera. |

### Funkcije

| # | Stavka plana | Status | Gde u kodu | Komentar |
|---|---|---|---|---|
| 1 | Tarifa: start, km, čekanje/min, min. cena | URAĐENO | `domain/models/tariff.dart:10-14`, `fare_calculator.dart` | Novac je int. Čekanje je u parama, pa se unosi i 13,33 din/min. |
| 1 | Tarifa: prag brzine čekanja | URAĐENO | `app_settings` `waiting_speed_threshold`, `rides.waiting_speed_kmh` | Prag je globalan (podešavanje), ne po tarifi. Brzina se snima uz svaku vožnju. |
| 1 | Tarifa: „prvi km” | NEDOSTAJE | `tariff.dart` nema to polje | Treba novo polje, migracija v12 i promena `FareCalculator`. |
| 1 | Automatska promena dan/vreme + ručni izbor | URAĐENO | `domain/tariff_selector.dart:5,20` (praznik → raspored → ručno), `tariff_selection_sheet.dart` | Raspored radi i preko ponoći. Isto vreme od–do znači ceo dan, pa grad sa jednom tarifom radi. |
| 2 | Praznične tarife | URAĐENO | `holidays` + `tariff_id` (`database_helper.dart:106,244`), `holidays_screen.dart` | Praznik može da bude ponavljajući (bez godine) ili za tačnu godinu. |
| 3 | Fiksne relacije + brza pretraga | BOLJE OD PLANA | `fixed_route_import.dart:89`, `fixed_routes_screen.dart`, `fixed_route_picker.dart` | Ima masovni uvoz iz teksta (91 relacija), pretragu bez kvačica i dugme RELACIJE na glavnom ekranu. |
| 4 | Izveštaji dan/nedelja/mesec/smena | URAĐENO | `domain/reports.dart:3` (`ReportPeriod`), tabela `shifts`, `reports_screen.dart` | Obuhvata ukupno, po vožnji, po satu (`reports.dart:103`) i po km (`:109`). |
| 5 | Dnevni troškovi u mesečnom izveštaju | NEDOSTAJE | grep `expense\|trošak` = 0 | Nema tabele ni ekrana za troškove; prikazuje se samo prihod. |
| 6 | BT štampa 58 mm | URAĐENO | `domain/printing/escpos.dart`, `receipt.dart`, `dither.dart`, `presentation/printing/receipt_printer.dart` | Na PT-210 vlasnik je potvrdio ispravna slova. |
| 6 | Opcija bez čćžšđ | URAĐENO | `escpos.dart:9` (`PrintMode.plain`), `receipt_printer.dart:30` | Podrazumevani režim je slika, pa naša slova rade na svakom štampaču. |
| 7 | Dokaz dostave (foto, primalac, vreme, lokacija) | NEDOSTAJE | `image_picker` se koristi samo za logo (`settings_screen.dart:5`) | Ovo je funkcija za kurirski segment. |
| 8 | Kalibracija prema overenom taksimetru | URAĐENO | `domain/calibration.dart`, `ride_engine.dart:43-47,318`, `rides.applied_calibration` | Kalibracija je u promilima i snima se uz vožnju. Poređenje u pravoj vožnji: PROVERITI NA UREĐAJU (`docs/TEST_VOZNJA.md`). |
| 9 | Dodaci koje vozač definiše, na računu | NEDOSTAJE | grep `extra\|doplat` = 0 | Nema doplata. U cenovniku grada postoje +50/+100 i pravilo „van teritorije”. |
| 10 | Uvoz/izvoz (rezervna kopija) | NEDOSTAJE | grep `export\|backup` = 0 | Postoji samo uvoz fiksnih relacija. Nema izvoza baze, pa podaci propadaju pri promeni telefona. |
| 11 | Velike cifre | URAĐENO | `taximeter_screen.dart:469` (`82 * priceScale`) | Boja i veličina cene su podesive, ekran ostaje uključen (`keepScreenOn`, wakelock). Čitljivost na suncu: PROVERITI NA UREĐAJU. |
| 11 | Automatski noćni režim | DELIMIČNO | `main.dart:28` (`ThemeData.dark()`, crna pozadina) | Aplikacija je uvek tamna. Nema prelaska svetlo/tamno po dobu dana ili senzoru. |
| 11 | Srpski glas (opciono) | DELIMIČNO | `presentation/services/voice_service.dart` (flutter_tts), `taximeter_screen.dart:172` | Najavljuje samo cenu na kraju vožnje. Srpski glas zavisi od TTS motora telefona: PROVERITI NA UREĐAJU. |
| 11 | Start/Pauza/Stop jednim dodirom | BOLJE OD PLANA | `ride_engine.dart:78` (`_paused`), `rides.paused_sec` | U pauzi ne teku ni km ni čekanje. Pauza se vidi u rezimeu. |
| 11 | Pogodno za držač u autu | DELIMIČNO | dijalozi skrolabilni u landscape | Poseban landscape raspored glavnog ekrana: NIJE VIĐENO / PROVERITI NA UREĐAJU. |
| 12 | Radi offline, obračun ne zavisi od mape | URAĐENO | `fare_calculator.dart:1-2` (uvozi samo domen) | INTERNET je samo za mapu (komentar u manifestu). Pravilo 4 iz CLAUDE.md je poštovano. |
| 13 | Mapa bez Google Maps kvote | BOLJE OD PLANA | `ride_map.dart` (flutter_map + OSM), `navigation_service.dart:33,46` | Ima i pretragu adrese, rutu, km, vreme i **približnu cenu** (`fare_estimate.dart`). Javni serveri imaju ograničenja (vidi D). |

### Objava i komercijalizacija

| Stavka plana | Status | Gde u kodu | Komentar |
|---|---|---|---|
| Paket i naziv | URAĐENO | `build.gradle.kts` `rs.taksimetar.balkan`; manifest `android:label="Taksimetar Balkan"` | U `pubspec.yaml` `description` je još „A new Flutter project.” (ne vidi se u prodavnici, kozmetika). |
| Ikonica i splash | URAĐENO | `pubspec.yaml:112` (launcher icons), `:121` (native splash, Android 12) | Logo firme vlasnik dodaje kasnije. |
| Upload ključ van projekta + Play App Signing | NEDOSTAJE | `build.gradle.kts`: release je potpisan **debug** ključem | **Blokator.** |
| Bez ACCESS_BACKGROUND_LOCATION | URAĐENO | izvorni i spojeni manifest | Lokacija ide kroz foreground servis. |
| FOREGROUND_SERVICE_LOCATION + deklaracija u Play Console | DELIMIČNO | manifest: dozvola + `foregroundServiceType="location"` | Deklaracija u konzoli (opis i video) nije urađena. |
| BLUETOOTH_SCAN sa neverForLocation | NEDOSTAJE | spojeni manifest: `BLUETOOTH_SCAN` bez flaga | Plugin dodaje i `BLUETOOTH`/`BLUETOOTH_ADMIN` bez `maxSdkVersion=30`. |
| POST_NOTIFICATIONS | URAĐENO | manifest | Obaveštenje servisa je samo na srpskom: `ride_service_controller.dart:20-21`. |
| Ostale dozvole iz plugina | NIJE U PLANU | spojeni manifest: `RECEIVE_BOOT_COMPLETED` (flutter_foreground_task) | Mora da se navede u Data safety ili da se ukloni ako restart posle paljenja telefona nije potreban. |
| Politika privatnosti SR/EN, javni URL | NEDOSTAJE | — | **Blokator** (aplikacija koristi lokaciju). |
| Data safety formular | NEDOSTAJE | — | Lokacija ostaje lokalno, a šalju se samo upiti za adresu i rutu ka OSM serverima. To treba tačno navesti. |
| Opis prodavnice, slike ekrana, feature graphic | NEDOSTAJE | — | |
| Zatvoreno testiranje 12 testera / 14 dana | NEDOSTAJE | — | Zavisi od tipa naloga (vidi G). |
| Nominatim: bez upita po slovu, ≤1/s, User-Agent | URAĐENO | `address_search_dialog.dart:8,98` (`onSubmitted`), `navigation_service.dart:34` | Upit se šalje tek na potvrdu, a User-Agent se šalje. |
| OSRM demo nije za produkciju | DELIMIČNO | `navigation_service.dart:46` `router.project-osrm.org` | Demo server je još u kodu. To je poznato (KNOWN_ISSUES #5). |
| Atribucija „© OpenStreetMap contributors” | URAĐENO | `ride_map.dart:368`, `ride_summary_screen.dart:397`, `address_search_dialog.dart:146` | |
| Uputstvo za bateriju po proizvođaču | DELIMIČNO | `taximeter_drawer.dart:120` (opšti tekst), `settings_screen.dart:686` (`openAppSettings`) | Nema posebnih koraka za Samsung, Xiaomi, Honor, Motorola i Lenovo, niti direktnog zahteva `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. |
| Anti-prevara: odbij isMocked | DELIMIČNO | `data/services/task_handler.dart:62` (`kReleaseMode && isMocked`) | Lažna lokacija se samo tiho odbacuje. Nema oznake na vožnji niti izveštaja za firmu. |
| Anti-prevara: filter tačnosti | URAĐENO | `domain/location_filter.dart:22`, prag u podešavanjima, `rides.gps_accuracy_m` | Filtrira i skokove brzine (`location_filter.dart:34`, max 200 km/h). |
| Promena tarife usred vožnje (21:55 → 22:00) | URAĐENO (odluka) | `SPEC.md:71` „Tarifa se bira samo pri startu”; tarifa se snima u `rides.tariff_*` | Odluka je dokumentovana i predvidiva. Ako lokalni propis traži promenu u toku vožnje, tu odluku mora da donese vlasnik (G). |

---

## B) Bolje od plana (vrednost za prodavnicu i za firme)

| Šta | Zašto je bolje | Za prodavnicu | Za firme |
|---|---|---|---|
| **Oporavak vožnje** (`RideEngine`: snimak na 10 s, nastavak do 5 min, posle toga zatvaranje sa iznosom) | Kad Android ugasi aplikaciju, vožnja i iznos se ne gube. | „Vožnja se ne gubi ni kad telefon ugasi aplikaciju.” | Manje sporova sa vozačima. |
| **Rupe u signalu** (`ride_gaps`) i filter skokova | Vidi se gde GPS nije radio, umesto da se tiho izmisle km. | „Pošten obračun, bez lažnih kilometara.” | Osnova za anti-prevaru. |
| **Besplatna OSM mapa + ruta + približna cena** | Konkurent zavisi od Google kvote. Ovde je procena cene pre vožnje odmah tu. | „Procena cene pre vožnje.” | Dispečer/vozač brzo daje ponudu. |
| **Rezime vožnje sa mapom rute** (premium izgled), štampa i deljenje | Profesionalan dokaz vožnje. | Prirodna Premium funkcija. | Dokaz klijentu. |
| **Štampa kao slika** (dither) + 6 režima | Naša slova rade i na jeftinim kineskim štampačima. | „Radi sa PT-210 i sličnim.” | Logo firme na računu. |
| **Masovni uvoz fiksnih relacija** + pretraga bez kvačica | Ceo cenovnik grada se unese za minut. | | Isti fajl za sve vozače (preteča firminog paketa). |
| **Pauza**, boja/veličina cene, osvežavanje 1/4/6/10 s, ekran uvek uključen | Podešava se kao pravi taksimetar. | Snimci ekrana sa crvenom/plavom cenom. | |
| **Čuvar prevoda u testovima** | Novi ekran ne može ostati neprevedeno. | Pouzdan engleski za region. | |
| **239 testova + migracije v1→v11** | Nadogradnja ne briše podatke vozača. | Manje loših ocena posle ažuriranja. | |

---

## C) Test na telefonima (Samsung S23 Ultra / Honor)

> Vlasnik **nije popunio** polja „TEST NA TELEFONIMA DANAS” u promptu.
> Ispod su samo nalazi viđeni ranije u ovoj sesiji i stavke koje treba proveriti.

### Samsung S23 Ultra (R5CWA30YB3F)

| Nalaz | Uzrok u kodu | Ispravka | Ozbiljnost |
|---|---|---|---|
| Štampač se vidi, ali ne štampa | Android 12+ traži `BLUETOOTH_SCAN` u toku rada | Traži se connect + scan i štampač se odmah pamti (ranije) | Rešeno, vlasnik potvrdio |
| Mapa kreće od pogrešne tačke | Korišćena poslednja poznata pozicija | Živa pozicija i u mirovanju (ranije) | Rešeno |
| Čioda nije u centru, ruta nije cela u kadru | Centriranje se preskakalo pre `onMapReady`; fit bez prostora za trake | Praćenje + `_onMapReady` + `CameraFit` sa paddingom (`9b2a258`) | PROVERITI NA UREĐAJU |
| Naslovi i dugmad na srpskom u EN verziji | `Text('...')` mimo `t()` | Omotano + test-čuvar (`9b2a258`) | PROVERITI NA UREĐAJU (meni je viđen na engleskom pre prekida USB veze) |
| Obračun i pretraga adrese | — | — | Vlasnik potvrdio: dobro |

### Honor [model nije upisan]

NIJE TESTIRANO u ovoj reviziji. Mogući problemi i gde ih tražiti:
- Gašenje servisa na zaključanom ekranu. Na Honor/Huawei to je najčešći problem (KNOWN_ISSUES #1). Treba dozvoliti „Ručno upravljanje” za pokretanje aplikacije, a u kodu dodati zahtev za izuzeće iz optimizacije baterije (D, F).
- Rupe u signalu u rezimeu vožnje znače da je sistem uspavao GPS. Proveriti `ride_gaps` u rezimeu.
- Glas: Honor bez Google TTS možda nema srpski glas. `voice_service.dart` tada ćuti.

---

## D) Blokatori za Google Play (tačni koraci)

1. **Ključ za potpisivanje**
   - `keytool -genkey -v -keystore D:\kljucevi\taksimetar-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
   - Ključ čuvaj van projekta, sa rezervnom kopijom.
   - Napravi `android/key.properties` i dodaj ga u `.gitignore`.
   - U `build.gradle.kts` dodaj `signingConfigs.release`.
   - U Play Console uključi Play App Signing.
   - Gradi sa `flutter build appbundle`.
2. **Bluetooth dozvole** u `AndroidManifest.xml`:
   - `BLUETOOTH_SCAN` sa `android:usesPermissionFlags="neverForLocation"` i `tools:replace`;
   - `BLUETOOTH` i `BLUETOOTH_ADMIN` sa `maxSdkVersion="30"`;
   - posle toga proveri spojeni manifest.
3. **Politika privatnosti SR/EN**
   - Objavi je na javnom URL-u (npr. GitHub Pages).
   - Navedi šta se snima: lokacija samo u vožnji, lokalno na telefonu.
   - Navedi šta se šalje: tekst adrese ka Nominatim i koordinate ka OSRM.
   - Link postavi u Play Console i u aplikaciju.
4. **Data safety**: lokacija (precizna) se prikuplja, ne deli se sa trećim licima, obrada je za funkciju aplikacije. Za Nominatim i OSRM upite odluku donosi vlasnik.
5. **Deklaracija foreground servisa (location)**: opis „merenje pređenog puta tokom vožnje koju vozač pokrene” i video od 30–60 s (start → zaključan ekran → obaveštenje → stop).
6. **Obaveštenje servisa** prevesti ili napisati neutralno (`ride_service_controller.dart:20-21`).
7. **Opis prodavnice SR/EN** sa disclaimerom „nije overeni taksimetar ni fiskalni uređaj”, 4–8 slika ekrana i feature graphic 1024×500.
8. **Zatvoreno testiranje**: lični nalog traži 12 testera tokom 14 dana pre produkcije, firmin nalog je izuzet.
9. **Preporuka pre objave** (Play to ne zahteva):
   - ekran prvog pokretanja sa disclaimerom i prihvatanjem;
   - zamena OSRM demo servera ili jasno ograničenje u opisu;
   - `pubspec.yaml` `description`.

---

## E) Komercijalizacija (prema onome što zaista postoji)

### Predlog podele
- **Besplatno**
  - Taksimetar (tarife, raspored, praznici, pauza, kalibracija).
  - Istorija i dnevni izveštaj.
  - Mapa sa živom pozicijom.
  - 1 štampač u režimu slike.
- **Premium (~1 €, jednokratno)**
  - Rezime vožnje sa mapom rute, deljenje.
  - Nedeljni, mesečni i izveštaj po smeni.
  - Fiksne relacije sa uvozom.
  - Pretraga adrese + približna cena.
  - Logo na računu, boje i veličina cene.
  - Kasnije: troškovi, rezervna kopija, doplate.
- **Firma**
  - Kod firme → naziv, logo, boje, tarife i relacije sa servera.
  - Izveštaj o lažnim lokacijama.

**Šta treba za Premium** (ništa od ovoga ne postoji):
- paket `in_app_purchase`, proizvod u Play Console (non-consumable);
- provera kupovine pri startu i lokalni keš, da radi offline;
- dugme „Vrati kupovinu” (restore);
- jedan `premiumProvider` i zaključavanje na ekranima.

Ako ne postoji server, provera potpisa kupovine na serveru se preskače, uz svestan rizik.

**Šta treba za firme** (ništa ne postoji):
- Firebase projekat (Firestore + Storage);
- `CompanyConfig` model;
- preuzimanje po kodu i keš u SQLite;
- uvoz tarifa i relacija preko postojećih repozitorijuma (`fixed_route_repository` `importAll` već postoji);
- pravila pristupa po kodu;
- veb ili Excel način da firma unese podatke.

**Prednosti u odnosu na Taximeter (Taxis Hub) i TAXImet**

Ovo je procena iz snimaka ekrana konkurencije koje je vlasnik poslao. Njihove aplikacije nisu otvarane, pa je poređenje NIJE VIĐENO u kodu.
- Mapa bez Google kvote, sa procenom cene pre vožnje.
- Oporavak vožnje i evidencija prekida signala.
- Štampa naših slova na jeftinim štampačima.
- Masovni uvoz cenovnika.
- Jednokratna cena umesto pretplate.
- Lokalni podaci bez naloga.

---

## F) Plan koraka

### Faza 1 — prvo izdanje (besplatno)

| # | Korak | Veličina | Rizik | Model |
|---|---|---|---|---|
| 1 | Provera `9b2a258` na S23 (mapa, engleski) + prava vožnja po `docs/TEST_VOZNJA.md` | S | srednji | Sonnet |
| 2 | Bluetooth dozvole (`neverForLocation`, `maxSdkVersion`) + provera spojenog manifesta | S | nizak | Haiku |
| 3 | Prevod obaveštenja servisa, `pubspec` description | S | nizak | Haiku |
| 4 | Ekran prvog pokretanja (disclaimer + prihvatanje) i ekran „O aplikaciji” (verzija, politika, licence OSM) | M | nizak | Sonnet |
| 5 | Zahtev za izuzeće od optimizacije baterije + uputstvo po proizvođaču | M | srednji (Play politika za tu dozvolu) | Sonnet |
| 6 | Release ključ + `signingConfigs` + AAB | S | **visok** (gubitak ključa) | Opus |
| 7 | Politika privatnosti, Data safety, FGS deklaracija + video | M | srednji (odbijanje) | Sonnet (tekst) + vlasnik |
| 8 | Opis prodavnice, slike, feature graphic SR/EN | M | nizak | Haiku/Sonnet |
| 9 | Zatvoreno testiranje (12/14 ako je lični nalog) | L (vreme) | srednji | — |

### Faza 2 — Premium

| # | Korak | Veličina | Rizik | Model |
|---|---|---|---|---|
| 10 | „Prvi km” u tarifi (migracija v12, `FareCalculator`, testovi) | M | visok (obračun) | Opus |
| 11 | Rezervna kopija: izvoz/uvoz baze (fajl + deljenje) | M | srednji (migracije pri uvozu) | Opus |
| 12 | Play Billing: kupovina, offline otključavanje, restore, zaključavanje funkcija | L | visok | Opus |
| 13 | Doplate (dodaci) na vožnji i računu | M | srednji (obračun) | Opus |
| 14 | Dnevni troškovi u mesečnom izveštaju (prihod − troškovi = neto) | M | nizak | Sonnet |
| 15 | Automatski svetli/tamni režim | S | nizak | Sonnet |

### Faza 3 — firme

| # | Korak | Veličina | Rizik | Model |
|---|---|---|---|---|
| 16 | Arhitektura firminog paketa (Firebase, kod firme, keš, bezbednosna pravila) | L | visok | Opus |
| 17 | Ekran „Kod firme” + primena logoa, boja, tarifa i relacija | M | srednji | Sonnet |
| 18 | Anti-prevara: oznaka lažne lokacije na vožnji + izveštaj | M | srednji | Opus |
| 19 | Sopstveni ili plaćeni OSRM/Nominatim/tile server | M | srednji (trošak) | Opus |
| 20 | Dokaz dostave (foto, primalac, vreme, lokacija, deljenje) za kurire | M | nizak | Sonnet |

---

## G) Pitanja za vlasnika (samo ona koja blokiraju)

1. **Play nalog: lični ili firmin?** Od toga zavisi obaveza 12 testera / 14 dana.
2. **Lozinka i lokacija čuvanja upload ključa** (korak 6). Bez toga nema AAB-a za Play.
3. **Gde se objavljuje politika privatnosti** (vaš sajt, GitHub Pages…) i koji kontakt e-mail ide u prodavnicu?
4. **Promena tarife usred vožnje:** da li lokalni propis traži prelazak na noćnu tarifu u 22:00 tokom vožnje? Sada važi tarifa sa starta (`SPEC.md:71`).
5. **Prvo izdanje: samo besplatno, pa Premium?** Ili Premium odmah? Ovo menja redosled koraka 4–12.
6. **Model Honor telefona i rezultati današnjeg testa** (sekcija C je prazna).
