# Arhitektura Projekta

## Principi
- **Clean Architecture (pragmatična):** Slojevi `data`, `domain`, `presentation`.
- **State Management:** Riverpod (za reaktivno osvežavanje UI-a bez seckanja).
- **Core Logika:** `FareCalculator` je čista Dart klasa u `domain` sloju. Ne zna za UI ni za bazu. Pokrivena testovima za sve scenarije iz plana.

## Glavni Moduli
1. **GPS Engine (Foreground Service):** Sluša lokaciju i drži Android WakeLock. Odbacuje tačke sa lošom tačnošću (prag iz Podešavanja, 5–50 m, podrazumevano 15 m; upisuje se uz vožnju).
2. **Obračun Cene (FareCalculator):** Pametno čekanje kada je brzina ispod praga (Podešavanja, podrazumevano 8 km/h); kalibracija distance u promilima. Prvi km tarife (opciono: prazno = kao ostali, 0 = u startu, > 0 = svoja cena za prvih 1000 m). Doplate (`withExtras`) se dodaju posle minimalne cene. Sve celobrojno (vidi `SPEC.md`).
3. **Lokalna Baza (sqflite, šema v12):** Offline-first. Vožnja se periodično upisuje u `ride_snapshots`. Detalji u `DATA_MODEL.md`.
4. **Tarife (Faza 2):** tarife, raspored i praznike unosi korisnik; `TariffSelector` bira tarifu samo pri startu (praznik → raspored → ručni izbor).
5. **Izveštaji i istorija (Faza 3):** `RideHistoryRepository` (čitanje, brisanje završenih vožnji), `ReportRange`/`RideStats` (dan, nedelja, mesec).
6. **Štampa (Faza 4):** `EscPos`, `Receipt`, `Dither` (domain, čisti) + `ReceiptPrinter` (Bluetooth, `print_bluetooth_thermal`). Podrazumevano se račun šalje kao slika, pa su naša slova uvek tačna.
7. **Mapa i navigacija:** `RideMap` (flutter_map, OpenStreetMap podloge; tamna pozadina ispod pločica, neuspele pločice se ponovo traže, lokacija se ponovo traži pri povratku u aplikaciju i kad servis postane spreman, vožnja vraća praćenje kamere), `NavigationService` (pretraga dok se kuca preko Photon-a uz rezervu Nominatim, OSRM ruta). `PlaceSearch` (domain): upit („đ” → „dj”), ćirilica → latinica za prikaz, redosled po vazdušnoj udaljenosti od vozača i izbacivanje duplikata. Samo za orijentaciju; obračun ne zavisi od mape ni interneta.
8. **Podešavanja:** `AppSettings` (domain, tipizirano i provereno) u `app_settings`; jedan `appSettingsProvider`.

9. **Prvo pokretanje i rad u pozadini:** `showFirstLaunch` (widgets/first_launch.dart) pri prvom startu traži prihvatanje napomene (nije overeni taksimetar), pa jednom prikazuje uputstvo za bateriju. `showBatteryGuide` (widgets/battery_guide.dart) otvara sistemski ekran optimizacije baterije (`ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`, bez dozvole `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) i prikazuje korake po proizvođaču (`batteryGroupFor`, domain/battery_guide.dart). Proizvođač i sistemski ekran dolaze preko `MethodChannel` `rs.taksimetar.balkan/device` (`MainActivity.kt`, `DeviceService`). Ekran `AboutScreen` (verzija preko `package_info_plus`, napomena, adresa politike privatnosti `privacyPolicyUrl` — još prazna).

10. **Rezervna kopija:** `BackupService` (`data/services/backup_service.dart`) izvozi tabele i slike logoa u JSON i vraća ih; `backup_actions.dart` (presentation) šalje fajl preko `share_plus`, bira ga preko `file_picker` i osvežava providere. Kopija iz novije šeme se odbija, kolone kojih nema u bazi se preskaču.

## Ko piše u bazu
- `rides`, `ride_snapshots`, `ride_gaps`, `ride_extras` za vožnju u toku: samo servis (`RideEngine`). Doplate stižu kao komande `add_extra{name, amount}` / `remove_extra{id}` (dugme „+” na glavnom ekranu, `widgets/extras_sheet.dart`); spisak stalnih doplata je u Podešavanjima (`app_settings.extras`).
- UI isolate: `tariffs`, `holidays`, `app_settings`, i brisanje **završenih** vožnji iz istorije (kratka transakcija; WAL + `busy_timeout` sprečavaju sudar sa servisom).
- **Vraćanje rezervne kopije** (`BackupService.restore`, UI isolate): briše i ponovo upisuje sve tabele u jednoj transakciji. Dozvoljeno samo kad nema aktivne vožnje (provera u bazi i u UI-ju), pa servis tada ne radi. Pre vraćanja se trenutni podaci čuvaju u `pre_vracanja_kopije.json` (dugme „Poništi poslednje vraćanje”).

## Tok Podataka
GPS Senzor -> Foreground Service (`RideEngine`) -> Odbacivanje šuma -> FareCalculator -> događaji (`update`…) -> Riverpod -> UI Prikaz & sqflite backup.

## Životni ciklus servisa
- **Vlasnik servisa je `RideServiceController` (UI isolate).** On pali i gasi foreground servis. Jedini izuzetak: kad se vožnja završi dugmetom ZAVRŠI u obaveštenju, handler posle 3 s sam zove `stopService()` (aplikacija je možda zatvorena pa nema ko drugi); ako je UI otvoren, on ga gasi pre toga i tajmer nestaje sa izolatom.
- **Dugmad u obaveštenju (Android):** `rideNotificationButtons` bira PAUZA/NASTAVI i ZAVRŠI posle događaja `started`/`recovered`/`paused`/`resumed`/`stopped`; pritisak ide u `RideEngine` kao ista komanda kao iz UI-ja (`pause`, `resume`, `stop`). Jezik dugmadi se čita iz `app_settings`.
- **Servis radi samo dok postoji vožnja.** `connect()` pri otvaranju aplikacije kratko podiže servis radi oporavka; ako `ready{active:false}` / `status{active:false}`, odmah ga gasi. `startRide()` podiže servis ako ne radi. Događaj `stopped` → kontroler gasi servis.
- **GPS stream i snapshot timer** postoje samo dok traje vožnja (`_startTracking()` posle starta/oporavka, `_stopTracking()` posle uspešnog stopa).
- **Redosled komandi:** handler izvršava `start`/`stop`/`status` strogo redom (`_queue`); kontroler serijalizuje `connect`/`startRide`/`stopRide` (`_serialized`).
- **Plugin iza `ForegroundBridge`** da bi se kontroler testirao bez uređaja.
- **iOS (lična upotreba, van Play/App Store):** nema pravog Android-stil foreground servisa. `rideServiceControllerProvider` na Androidu daje pravi `ForegroundBridge` (bez izmena), a na ostalim platformama `InProcessRideBridge` (`presentation/services/in_process_ride_bridge.dart`) — isti `RideEngine`, bez posrednog izolata/servisa, vozi se u glavnoj niti dok je ekran upaljen i app u prvom planu. Bez zaključanog ekrana i bez štampe (nije potrebno za ličnu upotrebu).
- **`RideEngine` (`lib/data/services/ride_engine.dart`)** drži svu logiku servisa: red komandi, upis vožnje, snapshot, oporavak. Prima `Database`, `send`, sat (`nowMs`) i kuke `onTrackingStart`/`onTrackingStop`; nema zavisnost od plugin-a, testira se preko sqflite_ffi (`test/data/ride_engine_test.dart`). `RideTaskHandler` je samo lepak: prosleđuje komande i GPS tačke i drži GPS stream/snapshot timer.
- **Baza u testovima:** `DatabaseHelper.openAt(path)` otvara produkcijsku šemu i migracije na proizvoljnoj putanji.

## Protokol događaja (servis → UI)
- `ready{active}`, `status{active, distance, waitingMs, price, mode, tariff_id, start_price, waiting_speed_kmh, gap_count, gap_ms, lat, lon}`, `started{ride_id}`, `recovered{...}`, `update{...}` (ista polja kao status), `gap{duration_ms, kind, ...}`, `already_active`, `snapshot_failing`, `warning{message}`.
- `update`/`status`/`recovered` nose i `extras` (lista `{id, name, amount}`) i `extras_total`; `price` već uključuje doplate.
- `stopped{ride_id, distance_m, waiting_sec, start_price, km_price, waiting_price, min_price_adjustment, extras, extras_total, total_price}`; `ride_id: null` znači da vožnje nije bilo.
- `error{message, cmd?}`: `cmd:'start'` → UI se vraća u `idle`, kontroler gasi servis; `cmd:'stop'` → upis nije uspeo, vožnja ostaje aktivna, Stop se može ponoviti.
- UI faze (`RidePhase`): `idle → starting → running → stopping → finished` (`newRide()` → `idle`).

## Oporavak vožnje (RideEngine)
- Pri podizanju servisa: aktivna vožnja sa snapshot-om mlađim od 5 min (po `saved_at`) nastavlja se (`recovered`); stariji snapshot → `interrupted` sa iznosima iz snapshot-a (K1). Bez snapshot-a: sveža (< 5 min) nastavlja od nule, stara je `interrupted`.
- Novi start zatvara sve zaostale `active` vožnje kao `interrupted`.
- GPS tačka se odbacuje ako: tačnost je loša/0/NaN, vreme je dalje od ±30 s od sata telefona (N1), ili je lažna lokacija u release build-u (U6).
- Tehnički dug: `RideTracker.processLocation` meri čekanje GPS vremenom (N1/U3 ublaženo proverom sata).

## Prekidi GPS signala (V12)
- `RideTracker.lastGap` (`GapInfo`) opisuje rupu veću od praga (10 s) koju je pokazala poslednja tačka i kako je obračunata. `RideEngine` je upisuje u `ride_gaps` (kroz red komandi), šalje događaj `gap` i nosi `gap_count`/`gap_ms` u `update`/`status`/`recovered`.
- Pri oporavku engine upisuje rupu `service_restart` za vreme dok servis nije radio (to vreme se ne naplaćuje).
- UI: tokom vožnje amber red "GPS signal prekidan N×"; u istoriji detalji vožnje navode svaku rupu i šta je naplaćeno.

## Rizici i Tehnički Dug
- **Rizik 1 (Baterija):** Android agresivno gasi servise (Xiaomi, Huawei, Samsung). Podešavanja imaju dugme ka podešavanjima aplikacije; ponašanje na uređaju još nije testirano (plan E u `docs/AUDIT_2026-10-19.md`).
- **Rizik 2 (GPS Šum):** Stajanje u mestu može generisati mikropomake (ublaženo prozorom brzine i pragom tačnosti).
- **Javni OSM serveri** (mapa, pretraga, ruta) su za malu upotrebu — vidi `KNOWN_ISSUES.md`.
- **Testovi:** logika (domain, data, provider, kontroler) je pokrivena; ekrani nemaju widget testove i proveravaju se ručno.